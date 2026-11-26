# Run every window kitty opens at the user's request in a cm session of its own, so it survives kitty
# quitting. kitty calls prefix_for_launch() for each one (kitty 0.51, see "Wrapping the programs run in new
# windows" in kitty's launch docs): new tabs, windows and OS windows by any action, mapping, menu or the tab
# bar, `kitten @ launch`, kspaces, session files and the first window.
#
# kitty keeps the window's own command as its argv and in saved sessions, not this prefix, so the session's
# name goes in the window's SESSION_VAR, which kitty saves too: a restored window comes back with it and
# reattaches to its session.

import os
import re
import socket
import sys

# Loaded with runpy, so this file's directory is not on the import path.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from kitty.fast_data_types import add_timer, get_boss  # noqa: E402

from cm_common import (  # noqa: E402
    CM_ATTACH,
    SESSION_VAR,
    _log,
    next_session_name,
    session_in_argv,
    session_info,
    session_of,
    session_remote_path,
    session_ssh_host,
)

# Not in cm: an overlay closes back to the window it covers, and docks are kspaces' sidebar and the like.
UNWRAPPED_TYPES = frozenset({'overlay', 'overlay-main', 'window-dock', 'tab-dock', 'os-window-dock', 'os-panel'})
# A window launched with this user variable, as in `launch --var=no_cm=1`, is left out of cm.
NO_CM_VAR = 'no_cm'
# The space and worktree a window's session belongs to, which kspaces passes with `launch --var` since kitty
# gives the wrapper no way to see which kitty session a new window is going into (see "Spaces and sessions"
# in kspaces' docs/kitty.md). cm_space and cm_worktree are what a kspaces before session providers passed.
SPACE_VARS = ('kspaces_space', 'cm_space')
WORKTREE_VARS = ('kspaces_worktree', 'cm_worktree')
PLACE_VARS = frozenset(SPACE_VARS[:1] + WORKTREE_VARS[:1])
# What cm accepts as a space name and as a tag value. A name it refused would end the window: cm attach
# exits on a bad --space before attaching to anything.
# A space may start with '.', as kspaces' .dotfiles does, but is not '.' or '..'.
SPACE_NAME = re.compile(r'(?!\.\.?$)[A-Za-z0-9._-]{1,64}')
TAG_VALUE = re.compile(r'[A-Za-z0-9._/-]{1,63}')


def prefix_for_launch(ctx):
    if (
        ctx.launch_type in UNWRAPPED_TYPES
        or NO_CM_VAR in ctx.user_vars
        # kspaces' own windows: its forms, panels and picker. Every kspaces variable but the two that say
        # where a window of the user's programs belongs marks one.
        or any(k.startswith('kspaces') and k not in PLACE_VARS for k in ctx.user_vars)
        # Already attaching, as windows restored from session files saved before this wrapper, or saved
        # with their foreground process, `cm attach NAME`.
        or session_in_argv(list(ctx.argv))
    ):
        return None
    restored = ctx.user_vars.get(SESSION_VAR)
    name = restored or next_session_name()
    remember(ctx.window_id, name)
    source = get_boss().window_id_map.get(ctx.source_window_id) if ctx.source_window_id else None
    info = session_info(session_of(source))
    space = space_args(ctx, source, guess=not restored)
    if not restored and (on_host := host_prefix(ctx, source, info, space)):
        return on_host
    if remote := remote_prefix(ctx, name, info, source, space):
        return remote
    # In the window's directory, so that the cm attach client starts there too: kitty takes the directory of
    # a cm window from that client while a program runs in it, see window_dir.
    dir_prefix = space + ['--dir', window_dir(ctx, source, info)]
    if not ctx.is_default_shell:
        # Typed into the session's shell at its first prompt (cm attach --in-shell) rather than run in place
        # of it: run before any zsh existed, .zshrc never ran, so omp and claude had no AWS or Bedrock
        # environment, no preexec hook reported the command, and cm list showed nothing running. The
        # session's shell also outlives the command, as kitty's --hold, which this cannot see, would keep
        # it (kovidgoyal/kitty#10901).
        prefix = [CM_ATTACH] + dir_prefix + ['--in-shell', name]
        _log('wrap %s window=%d cwd=%r argv=%r -> %r' % (ctx.launch_type, ctx.window_id, ctx.cwd, list(ctx.argv)[:3], prefix))
        return prefix
    # A shell: cm-attach --shell leaves out the command kitty puts after the prefix, on macOS its run-shell
    # kitten and the shell, and has cm start the shell itself in the window's directory. Run in the session,
    # that command would be its program rather than a shell, and cm would bring that command line back on a
    # restore instead of what was running in the shell.
    prefix = [CM_ATTACH] + dir_prefix + ['--shell', name]
    _log('wrap %s window=%d cwd=%r shell -> %r' % (ctx.launch_type, ctx.window_id, ctx.cwd, prefix))
    return prefix


# window_dir is where the new window starts: the directory kitty chose, but for one opened with the
# directory of a cm window that runs a program. kitty takes a window's directory from its shell's report
# (OSC 7) while it is at a prompt, else from its foreground process, which in a cm window is the cm attach
# client, still where it started, as for nvim run in a shell that has since changed directory. Then it is
# the session's directory, which cm has from the same reports.
def window_dir(ctx, source, info):
    cwd = info.get('cwd') if info and info.get('cwd_is_local') else ''
    if cwd and took_client_dir(ctx, source):
        return cwd
    return ctx.cwd


# took_client_dir is whether kitty gave the new window the directory of source's cm attach client, which it
# does while source runs a program, rather than one its shell reported.
def took_client_dir(ctx, source):
    if source is None or source.at_prompt:
        return False
    client = source.get_cwd_of_child() or ''
    return bool(client) and os.path.realpath(client) == os.path.realpath(ctx.cwd)


# remote_prefix reconnects a window opened from one whose session, info, has ssh'd elsewhere, as kitty does
# on its own for a window running `kitten ssh`: kitty sees only `cm attach` in a cm window. As there, a
# shell is the far side's login shell, and a command runs on the far side. Only when the new window takes
# that window's directory, which is then the remote one, not a local directory chosen for it, as kspaces
# chooses a worktree's. While that window runs a program, as nvim on the far side, kitty gives the new
# window the local directory of its cm attach client instead, which exists here, so that counts as taking
# its directory too: without it, a split from a remote nvim opened a local shell.
#
# `kitten ssh` rather than `ssh`: the kitten installs kitty's shell integration on the remote, so the new
# session reports its own remote OSC 7 and splitting again from *it* works the same way. Plain ssh would
# reconnect once and then the chain would stop.
def remote_prefix(ctx, name, info, source, space):
    host = session_ssh_host(info)
    if not host:
        return None
    path = session_remote_path(info)
    if os.path.isdir(ctx.cwd) and ctx.cwd != path and not took_client_dir(ctx, source):
        return None
    prefix = [CM_ATTACH] + space + ['--ssh', host] + (['--ssh-cwd', path] if path else [])
    prefix += ([] if ctx.is_default_shell else ['--ssh-command']) + [name]
    _log('wrap %s window=%d cwd=%r argv=%r remote -> %r' % (ctx.launch_type, ctx.window_id, ctx.cwd, list(ctx.argv)[:3], prefix))
    return prefix


# host_prefix opens a shell from a window showing a session on another cm host, one attached as HOST:REF, in a
# new session on that host, as remote_prefix does for one that has ssh'd elsewhere: the new pane is the host's,
# so kspaces shares it in the host's layout, beside the pane it was split from. It starts where the source
# session is on that host, which cm info reports as the host sees it, else in the host's home directory.
#
# Only a shell, and only one the user opened: a command kitty runs is a program on this machine, and a window
# kspaces opens carries its place variables and starts where kspaces chose, a worktree here.
#
# The name has this machine's in it, as `kitty.laptop.5`: the counter is this machine's, and two machines
# making `kitty.5` on one host would attach to each other's session.
def host_prefix(ctx, source, info, space):
    host, qualified, _ = (session_of(source) or '').partition(':')
    if not qualified or not ctx.is_default_shell or any(v in ctx.user_vars for v in PLACE_VARS):
        return None
    local = socket.gethostname().split('.')[0].lower()
    name = '%s:%s' % (host, next_session_name().replace('kitty.', 'kitty.%s.' % local, 1))
    remember(ctx.window_id, name)
    cwd = info.get('cwd') if info and info.get('cwd_is_local') else ''
    prefix = [CM_ATTACH] + space + (['--dir', cwd] if cwd else []) + ['--shell', name]
    _log('wrap %s window=%d cwd=%r on %s -> %r' % (ctx.launch_type, ctx.window_id, ctx.cwd, host, prefix))
    return prefix


# space_args says which cm space, and which worktree, a session this window creates belongs to.
#
# From kspaces' launch vars when it opened the window, else from the kitty session of the window it was opened
# from, else the session in focus, named `SPACE` or `SPACE@WORKTREE` as kspaces names them. Not from the new
# window itself: kitty calls the wrapper before the window is in a tab, so it has no session yet. Nothing
# when none says, which leaves cm to put the session in the space of the one it runs in, else default.
#
# Not guessed for a window that already names its session, as one kitty restores: it has no source window, and
# the session in focus is whichever kitty session finished loading first. Restored hubble-timescape windows were
# filed under gr@filtering that way, and cm took the guess when it revived their sessions after a reboot, so
# `kspaces remove` of that worktree killed them while their windows stayed open. The session keeps its own.
def space_args(ctx, source, guess=True):
    space = next((ctx.user_vars[v] for v in SPACE_VARS if ctx.user_vars.get(v)), '')
    worktree = next((ctx.user_vars[v] for v in WORKTREE_VARS if ctx.user_vars.get(v)), '')
    if not space and guess:
        session = source.effective_session_name if source is not None else get_boss().active_session
        space, _, worktree = (session or '').partition('@')
    args = []
    for flag, value, valid in (('--space', space, SPACE_NAME), ('--worktree', worktree, TAG_VALUE)):
        if valid.fullmatch(value):
            args += [flag, value]
        elif value:
            _log('%s %r not passed to cm, which would refuse it' % (flag, value))
    return args


# remember sets the window's SESSION_VAR once it exists: kitty calls the wrapper before the window is
# created.
def remember(window_id, name):
    def set_var(timer_id):
        w = get_boss().window_id_map.get(window_id)
        if w is not None and w.user_vars.get(SESSION_VAR) != name:
            w.set_user_var(SESSION_VAR, name)

    add_timer(set_var, 0, False)
