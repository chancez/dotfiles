from kitty.fast_data_types import get_options


# kitty has no exit event, only this quit hook, so a session is saved when the
# app is asked to terminate: the macOS menu/Dock Quit item, cmd+q, or logout.
# Closing OS windows one at a time still bypasses it, there is nothing to hook.
def on_quit(boss, window, data):
    # Called once before the confirmation dialog and again after it is accepted.
    if not data.get('confirmed'):
        return
    # Save back to wherever the session is loaded from, so the two cannot drift.
    path = get_options().startup_session
    if not path:
        return
    boss.save_as_session('--save-only', '--use-foreground-process', path)
