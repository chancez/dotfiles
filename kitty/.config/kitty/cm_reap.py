import json
import os
import subprocess
import sys
import threading
import time

# Watchers are executed with runpy rather than imported as modules the way kittens are, so this file's
# directory is not on the import path and a plain `from cm_common import ...` fails at load time.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from cm_common import CM, cm_env, session_of  # noqa: E402

# Where this watcher records what it did, since a watcher has nowhere else to report.
#
# It exists because the failure this file had was invisible: session_of returned None for every window, so
# closing one killed nothing and sessions accumulated until cm's own five-minute sweep collected them.
# Nothing logged, nothing errored, and the only symptom was a session list that grew. kitty sends a
# watcher's stderr to its own log, which is not somewhere anyone looks, so this writes a file instead.
LOG = os.path.expanduser('~/.local/state/kitty-cm/reap.log')


def _log(message):
    """Append a line, best effort. A watcher must not fail because logging did."""
    try:
        os.makedirs(os.path.dirname(LOG), exist_ok=True)
        with open(LOG, 'a') as f:
            f.write('%s %s\n' % (time.strftime('%Y-%m-%dT%H:%M:%S'), message))
    except OSError:
        pass


# A window closing on its own is reported to cm with `cm close`, which decides what that means for the
# session it showed: left alone while another window shows it, left running when a command runs in it, and
# shelved or ended when its shell is idle at a prompt. Closing paths are many (cmd+w, the titlebar button,
# the macOS menu, `exit`, closing its tab or OS window), and a watcher covers all of them, whereas a
# keybinding only covers the keys it maps.
#
# This killed the session, `cm kill --force`, which ended a long job whose window was closed to be found
# again in its space, and a session another window still showed. The window's client pid goes with the
# close, so cm detaches that client alone and can tell a last window from one of two.
#
# Not when kitty quits, which closes every window: the whole point of running windows inside cm is that
# they survive it. kitty says which it is in data['reason'] (kitty 0.51).
#
# A window kspaces closes to open again later carries kspaces_keep: kspaces has already ended its session
# with `cm kill --keep`, and ending it here would forget what was kept, its scrollback and resume command.
#
# A window whose program exited on its own, cause program_exit, rather than being closed, is not a close.
# The program is the cm attach client, which exits for two reasons. The detach key says keep the session:
# closing it then shelved or killed an idle shell the moment it was detached. And the session ending, a
# shell's `exit`: its record would then stay for expire_after, a week, since these sessions persist, where
# the kill this replaced forgot it. So the session is forgotten if it exited, and left as it is otherwise:
# running after a detach, or shelved, from the shelved notice's Detach.
def on_close(boss, window, data):
    if data.get('reason') == 'quit':
        return
    if window is not None and window.user_vars.get('kspaces_keep'):
        return

    name = session_of(window)
    if name is None:
        # Logged rather than passed over. This is the branch that silently did nothing for every window,
        # so a future mismatch between how a window is launched and what this recognizes leaves a trace
        # instead of a growing session list.
        argv = list(window.child.argv) if window is not None else []
        _log('no session for closing window, argv=%r' % (argv,))
        return

    if data.get('cause') == 'program_exit':
        threading.Thread(target=forget_if_exited, args=(name,), daemon=True).start()
        return

    pid = window.child.pid if window is not None else None
    # On a thread, since a watcher runs on kitty's main thread and shelving an idle session waits up to 3s
    # for its shell to exit: every window close would freeze kitty for that long.
    threading.Thread(target=close, args=(name, pid), daemon=True).start()


def close(name, pid):
    r = run([CM, 'close', name] + (['--client-pid', str(pid)] if pid else []), 10)
    if r is not None and r.returncode != 0 and 'unknown command' in (r.stderr or ''):
        # A cm that predates close, until the new build is installed: what this did before.
        r = run([CM, 'kill', name, '--force'], 5)
    if r is not None and r.returncode != 0:
        _log('%s failed: %s' % (' '.join(r.args[1:3]), (r.stderr or '').strip()))
    elif r is not None and r.stdout.strip():
        # What cm decided, `kitty.7: shelved`, since that is the question when a session is missing later.
        _log(r.stdout.strip())


def forget_if_exited(name):
    # Asked twice, a second apart, while it reads running: the client can exit on the session ending a moment
    # before the server has recorded it, and a detached session reads running both times.
    for attempt in range(2):
        # JSON rather than --field, which prints the state as the table shows it, `exited(0)`.
        r = run([CM, 'info', name, '--json'], 5)
        try:
            state = json.loads(r.stdout).get('state', '') if r is not None and r.returncode == 0 else ''
        except ValueError:
            state = ''
        if state != 'running' or attempt:
            break
        time.sleep(1)
    if state != 'exited':
        return
    r = run([CM, 'forget', name], 5)
    if r is not None and r.returncode != 0:
        _log('forget %s failed: %s' % (name, (r.stderr or '').strip()))
    else:
        _log('%s: exited, forgotten' % name)


def run(argv, timeout):
    try:
        return subprocess.run(argv, capture_output=True, text=True, timeout=timeout, env=cm_env())
    except (OSError, subprocess.SubprocessError) as e:
        _log('%s errored: %s' % (' '.join(argv[1:3]), e))
        return None
