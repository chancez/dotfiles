import subprocess

from kittens.tui.handler import result_handler
from zmx_launch import ZMX, session_fields, session_of


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
                [ZMX, 'kill', name, '--force'],
                capture_output=True, text=True, timeout=5,
            )
        except (OSError, subprocess.SubprocessError):
            pass


# The zsh hooks set the PROG label while a command runs and clear it at the
# prompt, so it doubles as "is this session busy". kitty's own confirmation
# can't tell: zmx owns the pty, so kitty only ever sees `zmx attach` running.
def describe(names):
    fields = session_fields()
    return [(n, fields.get(n, {}).get('PROG')) for n in names]


def confirm_message(described):
    busy = [(n, prog) for n, prog in described if prog]
    if len(described) == 1:
        name, prog = described[0]
        return 'Kill session {} (running {})?'.format(name, prog)
    if len(busy) == 1:
        header = 'Kill {} sessions, 1 of them running {}?'.format(
            len(described), busy[0][1]
        )
    else:
        header = 'Kill {} sessions, {} of them running commands?'.format(
            len(described), len(busy)
        )
    lines = [header]
    for name, prog in described:
        lines.append('  {}{}'.format(name, ' (running {})'.format(prog) if prog else ''))
    return '\n'.join(lines)


# Stopping the sessions is the zmx_reap.py watcher's job, since it sees every way a
# window can close rather than only the keys mapped to this kitten. What this adds
# is the chance to say no beforehand: by the time a watcher runs the window is
# already going away, so there is nothing left to cancel.
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
    if not any(prog for _, prog in described):
        close()
        return
    boss.confirm(confirm_message(described), close, window=window)
