import os
import subprocess
import sys
import time

# Watchers are executed with runpy rather than imported as modules the way kittens are, so this file's
# directory is not on the import path and a plain `from cm_launch import ...` fails at load time.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from cm_launch import CM, session_of  # noqa: E402

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

# Set once kitty has been asked to terminate. on_quit arrives before the on_close calls that teardown
# generates, so this distinguishes "the user closed this window" from "every window is closing because
# kitty is going away" -- the whole point of running windows inside cm is that the second case must not
# kill anything.
_quitting = False


def on_quit(boss, window, data):
    global _quitting
    _quitting = True


# A window closing on its own means the user is done with it, so the session it was showing should stop
# rather than linger with no terminal attached. Closing paths are many (cmd+w, the titlebar button, the
# macOS menu, `exit`), and a watcher covers all of them, whereas a keybinding only covers the keys it
# maps.
#
# on_quit does not fire when kitty is killed rather than asked to exit, so the window map is checked as
# well: during teardown kitty has already emptied it, while a deliberate close still reports the windows
# that remain, including the case where the one being closed is the last.
def on_close(boss, window, data):
    if _quitting or not boss.os_window_map:
        return

    name = session_of(window)
    if name is None:
        # Logged rather than passed over. This is the branch that silently did nothing for every window,
        # so a future mismatch between how a window is launched and what this recognizes leaves a trace
        # instead of a growing session list.
        argv = list(window.child.argv) if window is not None else []
        _log('no session for closing window, argv=%r' % (argv,))
        return

    try:
        r = subprocess.run(
            [CM, 'kill', name, '--force'],
            capture_output=True, text=True, timeout=5,
        )
        if r.returncode != 0:
            _log('kill %s failed: %s' % (name, (r.stderr or '').strip()))
    except (OSError, subprocess.SubprocessError) as e:
        _log('kill %s errored: %s' % (name, e))
