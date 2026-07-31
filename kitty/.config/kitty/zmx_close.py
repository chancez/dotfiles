import subprocess

from kittens.tui.handler import result_handler
from zmx_launch import ZMX, session_of


def main(args):
    return ''


# Closing the window only detaches, leaving the session running, so closing on
# purpose has to kill the session explicitly. This deliberately isn't a
# `watcher`/on_close hook: on_close also fires for every window when kitty itself
# is quitting (with no preceding on_quit on SIGTERM), so a watcher can't tell
# "user closed this window" from "kitty is shutting down" and would kill every
# session exactly when they need to survive.
@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    window = boss.window_id_map.get(target_window_id)
    name = session_of(window)
    if name is not None:
        try:
            subprocess.run(
                [ZMX, 'kill', name, '--force'],
                capture_output=True, text=True, timeout=5,
            )
        except (OSError, subprocess.SubprocessError):
            pass
    boss.call_remote_control(window, ('close-window', '--match=id:{}'.format(target_window_id)))
