# Hide or show the kspaces sidebar in every tab. See kspaces_watcher.py, which adds the docks.

from kittens.tui.handler import result_handler

DOCK_VAR = 'kspaces'


def main(args):
    return ''


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    hidden = not getattr(boss, 'kspaces_hidden', False)
    boss.kspaces_hidden = hidden
    if hidden:
        for w in tuple(boss.all_windows):
            if DOCK_VAR in w.user_vars:
                boss.mark_window_for_close(w)
    else:
        # The watcher adds the docks the next time the tab bar changes, so make it change now.
        for tm in boss.all_tab_managers:
            tm.mark_tab_bar_dirty()
