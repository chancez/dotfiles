from typing import Any

from kitty.boss import Boss
from kitty.window import Window

def on_quit(boss: Boss, window: Window, data: dict[str, Any]) -> None:
    # called when kitty is about to quit. This is called in *global watchers*
    # only. It is called twice: once before the quit confirmation dialog is
    # shown (data['confirmed'] will be False) and once after the user has
    # confirmed quitting (data['confirmed'] will be True). Setting
    # data['aborted'] to True will abort the quit in both cases.
    boss.call_remote_control(window, ('action', f'--match=id:{window.id}', 'save_as_session'))
