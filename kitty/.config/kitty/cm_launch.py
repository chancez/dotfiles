import fcntl
import json
import os
import subprocess
import time
from urllib.parse import unquote, urlparse

from kitty.fast_data_types import get_options
from kittens.tui.handler import result_handler

# Names, not paths: where cm lives differs per host, since it can be installed under ~/.local/bin or as
# a mise shim.
CM_ATTACH = 'cm-attach'
CM = 'cm'

COUNTER = os.path.expanduser('~/.local/state/kitty-cm/counter')

# Where a launch records what it decided, for the same reason cm_reap.py has a log: a kitten's stderr goes
# to kitty's own log, which is not somewhere anyone looks, and the failures here are silent by nature. A
# split that opened the wrong kind of window looks exactly like a split that opened the right one.
LOG = os.path.expanduser('~/.local/state/kitty-cm/launch.log')


def _log(message):
    """Append a line, best effort. A launch must not fail because logging did."""
    try:
        os.makedirs(os.path.dirname(LOG), exist_ok=True)
        with open(LOG, 'a') as f:
            f.write('%s %s\n' % (time.strftime('%Y-%m-%dT%H:%M:%S'), message))
    except OSError:
        pass


# The environment `env` in kitty.conf builds, which is where PATH is set for this setup.
#
# Needed because kitty's own environment does not have it. A kitty started from the Dock or Spotlight
# is a child of launchd and inherits launchd's PATH, and `env` applies to the processes kitty launches
# rather than to kitty itself, so a kitten -- which runs inside the kitty process -- still sees
# /usr/bin:/bin:/usr/sbin:/sbin and cannot find cm on it.
#
# Passing this to subprocess means PATH is configured in one place and read from it here, instead of
# each caller hardcoding an install path. Windows opened by `launch` need nothing: kitty already
# applies these variables to them.
def cm_env():
    env = dict(os.environ)
    env.update(get_options().env)
    return env


# Names are allocated here rather than by cm, even though cm can allocate them.
#
# kitty's save_as_session records a window's launch argv, so the session name has to be *in* the argv
# for a restored window to reattach rather than create a new session. That means the name must exist
# before the window is launched, and `cm attach` with no name only reports the one it allocated after
# the fact.
#
# kitty window ids are reused across restarts, which is why this counts rather than using the window
# id: a reused name would let a window reattach to a different session than it expected. The lock
# covers two windows opened at once.
def next_session_name():
    os.makedirs(os.path.dirname(COUNTER), exist_ok=True)
    fd = os.open(COUNTER, os.O_RDWR | os.O_CREAT, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)
        current = os.read(fd, 64).decode().strip()
        n = int(current) + 1 if current else 1
        os.lseek(fd, 0, os.SEEK_SET)
        os.truncate(fd, 0)
        os.write(fd, str(n).encode())
    finally:
        os.close(fd)
    return 'kitty.{}'.format(n)


def cm_json(args):
    """Run a cm command that emits JSON and return the parsed value, or None."""
    try:
        out = subprocess.run(
            [CM] + args, capture_output=True, text=True, timeout=5, env=cm_env()
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return None
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        return None


def sessions():
    """Every session cm knows, keyed by name."""
    listing = cm_json(['list', '--json']) or []
    return {s['name']: s for s in listing}


# The window's launch argv is authoritative, unlike under zmx.
#
# zmx needed lsof here, and it was not paranoia: `zmx attach` from a shell that already has ZMX_SESSION
# set retargets that shell's existing client rather than attaching a new one, so a window could end up
# showing a session its argv never mentioned, and killing by the argv name would destroy an unrelated
# session. cm never retargets -- it only ever exports CM_SESSION and never reads it -- so the name the
# window was launched with is the name it is showing.
#
# Both spellings are accepted, and the second is not hypothetical. Windows launched through cm_launch.py
# run the cm-attach wrapper, so their argv is ('cm-attach', NAME), but a window started by hand can be
# running `cm attach NAME` directly -- every live window on this machine was, which made this return None
# for all of them.
#
# The consequence was silent and is the reason to be lenient here: cm_reap.py returns early on None, so
# closing a window killed nothing and the session sat as exited until cm's own five-minute sweep collected
# it. Nothing logged, nothing failed, sessions just accumulated. The wrapper is an implementation detail of
# how a window was launched; the reaper only needs the name.
def session_of(window):
    argv = list(window.child.argv) if window is not None else []
    if not argv:
        return None

    prog = os.path.basename(argv[0])
    # The wrapper: cm-attach NAME.
    if prog == 'cm-attach' and len(argv) >= 2:
        return argv[1]
    # cm itself: cm attach NAME. Guarded on the subcommand so `cm list` in a window is not mistaken for a
    # session, and the name is taken as the first argument that is not a flag, so a boolean flag before it
    # is skipped (`cm attach --persist NAME`). A flag whose value is separated by a space rather than an
    # `=` would be read as the name, but nothing here launches one that way.
    if prog == 'cm' and len(argv) >= 3 and argv[1] in ('attach', 'a'):
        for arg in argv[2:]:
            if not arg.startswith('-'):
                return arg
    return None


# The session's own idea of its directory, which cm tracks from OSC 7.
#
# Needed because cm owns the window's pty, so the shell's cwd never reaches kitty and --cwd=current
# would always resolve to wherever the session was first started. zmx got this by asking lsof for the
# shell's cwd; cm reports it directly, and reports whether it is even local: a session that has ssh'd
# elsewhere has a path that does not exist here, and opening a new window there would fail or land
# somewhere wrong.
def session_info(name):
    """What cm knows about a session, or None. One call: each one costs about 23ms."""
    if name is None:
        return None
    return cm_json(['info', name, '--json'])


def session_cwd(info):
    if not info:
        return None
    if not info.get('cwd_is_local'):
        return None
    return info.get('cwd') or None


# The host a session has ssh'd to, or None when it is still local.
#
# Read from cwd_uri rather than from the running command, because the command is not there to read. kitty's
# shell integration does report it, as `cmdline=` on OSC 133;C, but cm clears that the moment the remote
# shell draws its first prompt (internal/osc/command.go, `case 'A', 'B'`), so by the time a key is pressed
# cm holds the remote shell's state and not the ssh. The cwd is the one remote fact that survives, because
# OSC 7 carries the host and cm keeps it for exactly this reason.
#
# So this is the host as the remote machine names itself, not the ssh alias that was typed. It loses user@,
# a port, a jump host, and whether the connection was made with `kitten ssh` or plain ssh. That is the
# known cost of this approach and the reason it was chosen anyway: the alternatives were typing into the
# terminal, walking a process tree, or teaching cm to model prompt depth. If an alias ever stops resolving
# this way, the failure is loud -- ssh says so in the new window -- rather than silent.
def session_ssh_host(info):
    if not info or info.get('cwd_is_local'):
        return None
    uri = info.get('cwd_uri') or ''
    host = urlparse(uri).hostname
    return host or None


# The directory on the far side, for ssh.conf's `cwd` to change into.
#
# Parsed from cwd_uri here rather than read from cm's `cwd` field, which is empty by design for a remote
# session: cm withholds it because acting on a remote path locally opens the wrong place or fails. This is
# the one caller that wants it anyway, because it is going to use it on the host it belongs to.
#
# Percent-decoded, since OSC 7 sends a URI and a path with a space in it arrives as %20.
def session_remote_path(info):
    if not info or info.get('cwd_is_local'):
        return None
    uri = info.get('cwd_uri') or ''
    path = unquote(urlparse(uri).path or '')
    return path or None


def main(args):
    return ''


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    window = boss.window_id_map.get(target_window_id)
    name = session_of(window)
    info = session_info(name)

    # Every field the decision below rests on, so a wrong decision can be read back rather than guessed at.
    _log('name=%r argv=%r info=%s cwd_is_local=%r cwd_uri=%r cwd=%r' % (
        name,
        list(window.child.argv) if window is not None else None,
        'yes' if info else 'MISSING',
        (info or {}).get('cwd_is_local'),
        (info or {}).get('cwd_uri'),
        (info or {}).get('cwd'),
    ))

    cmd = ['launch']
    cmd.extend(args[1:])

    # A session that has ssh'd elsewhere is reconnected rather than opened locally, which is what kitty
    # does on its own for a window running `kitten ssh`: the new window *is* the connection, and it closes
    # when ssh exits.
    #
    # No --cwd, because the directory the session reports belongs to the remote host and would either fail
    # here or, worse, resolve to an unrelated local path of the same name. Landing in the remote home is
    # the accepted limit of this; the remote cwd would need a command on the far side to cd with.
    #
    # `kitten ssh` rather than `ssh`, and not only to match how the connection was probably made: the
    # kitten installs kitty's shell integration on the remote, so the new session reports its own remote
    # OSC 7 and splitting again from *it* works the same way. Plain ssh would reconnect once and then the
    # chain would stop.
    # No `--` here: the wrapper adds the one cm needs, so kitty's launch parser never sees it.
    #
    # The remote directory travels as KITTY_LOGIN_CWD, which is what the ssh kitten's bootstrap reads on the
    # far side and which ssh.conf copies across. Set with `env` for this one process rather than in the
    # session's environment, so it cannot leak into a later `kitten ssh` typed by hand in the same window and
    # send that one to a path belonging to another host.
    host = session_ssh_host(info)
    if host:
        cmd.extend([CM_ATTACH, next_session_name()])
        path = session_remote_path(info)
        if path:
            cmd.extend(['env', 'KITTY_LOGIN_CWD={}'.format(path)])
        cmd.extend(['kitten', 'ssh', host])
        _log('  -> remote host=%r path=%r cmd=%r' % (host, path, cmd))
        boss.call_remote_control(window, tuple(cmd))
        return

    cwd = session_cwd(info)
    if cwd is None and window is not None:
        cwd = window.cwd_of_child
    if cwd:
        cmd.append('--cwd={}'.format(cwd))
    cmd.extend([CM_ATTACH, next_session_name()])
    _log('  -> local cmd=%r' % (cmd,))
    boss.call_remote_control(window, tuple(cmd))
