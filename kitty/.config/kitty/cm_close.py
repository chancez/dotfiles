import subprocess

from kittens.tui.handler import result_handler

from cm_launch import CM, cm_env, session_of, sessions


def main(args):
    return ''


def tab_of(boss, window):
    for tab in boss.all_tabs:
        for w in tab:
            if w is window:
                return tab
    return None


def kill_sessions(names):
    for name in names:
        try:
            subprocess.run(
                [CM, 'kill', name, '--force'],
                capture_output=True, text=True, timeout=5, env=cm_env(),
            )
        except (OSError, subprocess.SubprocessError):
            pass


# What each session is running, so the confirmation can say so.
#
# cm reports this from OSC 133 in the shell's own output, so there is nothing to install: zmx needed
# preexec/precmd hooks maintaining a PROG label, and because zmx restricts label values to
# [a-zA-Z0-9-_.] the command had to be mangled to fit and arrived lossy. cm reports the command line as
# the shell sent it.
#
# `command` can be empty while `busy` is true, for a shell that reports a bare 133;C without the cmdline
# extension, so both are returned: busy is what decides whether to ask, and command is only for the
# wording.
def describe(names):
    live = sessions()
    out = []
    for name in names:
        s = live.get(name, {})
        out.append((name, bool(s.get('busy')), s.get('command') or ''))
    return out


def describe_one(name, busy, command):
    if command:
        return '{} (running {})'.format(name, command)
    if busy:
        # Busy, but the shell did not say what. Worth distinguishing from idle, since that is the part
        # that decides whether closing loses anything.
        return '{} (busy)'.format(name)
    return name


def confirm_message(described):
    busy = [d for d in described if d[1]]
    if len(described) == 1:
        return 'Kill session {}?'.format(describe_one(*described[0]))
    if len(busy) == 1:
        header = 'Kill {} sessions, 1 of them running {}?'.format(
            len(described), busy[0][2] or 'a command'
        )
    else:
        header = 'Kill {} sessions, {} of them running commands?'.format(
            len(described), len(busy)
        )
    return '\n'.join([header] + ['  ' + describe_one(*d) for d in described])


# Stopping the sessions is the cm_reap.py watcher's job, since it sees every way a window can close
# rather than only the keys mapped to this kitten. What this adds is the chance to say no beforehand: by
# the time a watcher runs the window is already going away, so there is nothing left to cancel.
@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    window = boss.window_id_map.get(target_window_id)
    scope_tab = '--scope=tab' in args[1:]

    tab = tab_of(boss, window) if scope_tab else None
    windows = list(tab) if tab is not None else [window]
    names = [n for n in (session_of(w) for w in windows) if n is not None]

    def close(confirmed=True):
        if not confirmed:
            return
        kill_sessions(names)
        if tab is not None:
            boss.close_tab_no_confirm(tab)
        else:
            boss.call_remote_control(
                window, ('close-window', '--match=id:{}'.format(target_window_id))
            )

    described = describe(names)
    # Nothing is running, so there is no state to lose and no reason to ask.
    if not any(busy for _, busy, _ in described):
        close()
        return
    boss.confirm(confirm_message(described), close, window=window)
