import os
import subprocess
import sys

# Watchers are executed with runpy rather than imported as modules the way kittens
# are, so this file's directory is not on the import path and a plain
# `from zmx_launch import ...` fails at load time.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from zmx_launch import ZMX, session_of  # noqa: E402

# Set once kitty has been asked to terminate. on_quit arrives before the on_close
# calls that teardown generates, so this distinguishes "the user closed this
# window" from "every window is closing because kitty is going away" -- the whole
# point of running windows inside zmx is that the second case must not kill
# anything.
_quitting = False


def on_quit(boss, window, data):
    global _quitting
    _quitting = True


# A window closing on its own means the user is done with it, so the session it
# was showing should stop rather than linger with no terminal attached. Closing
# paths are many (cmd+w, the titlebar button, the macOS menu, `exit`), and a
# watcher covers all of them, whereas a keybinding only covers the keys it maps.
#
# on_quit does not fire when kitty is killed rather than asked to exit, so the
# window map is checked as well: during teardown kitty has already emptied it,
# while a deliberate close still reports the windows that remain, including the
# case where the one being closed is the last.
def on_close(boss, window, data):
    if _quitting or not boss.os_window_map:
        return

    name = session_of(window)
    if name is None:
        return

    try:
        subprocess.run(
            [ZMX, 'kill', name, '--force'],
            capture_output=True, text=True, timeout=5,
        )
    except (OSError, subprocess.SubprocessError):
        pass
