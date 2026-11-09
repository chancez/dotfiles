# Keep a kspaces sidebar docked at the left of every tab that belongs to a session.
#
# kitty can only dock a window to one tab, so a sidebar that is always there is one dock per tab, each
# running its own `kspaces sidebar`. This adds the missing ones whenever a window is created or the tab bar
# changes, which covers new tabs, tabs loaded from a session file and tabs moved between OS windows.
#
# Only tabs in a session get one. Spaces are sessions, and the exclusion keeps the sidebar out of windows
# that are not part of the workspace at all, such as the tab switcher's OS window.
#
# kspaces_toggle.py hides and shows the sidebars by setting boss.kspaces_hidden.

import os

from kitty.fast_data_types import add_timer

DOCK_VAR = 'kspaces'
# By absolute path: a watcher runs inside kitty, whose PATH under launchd does not have ~/.local/bin.
KSPACES = os.path.expanduser('~/.local/bin/kspaces')
DOCK_COLUMNS = '28'

_scheduled = False


def has_dock(tab):
    return any(DOCK_VAR in w.user_vars for g in tab.windows.tab_docks for w in g)


def wants_dock(tab):
    return bool(tab.created_in_session_name) and bool(tab.windows.groups) and not has_dock(tab)


def add_docks(boss):
    if getattr(boss, 'kspaces_hidden', False):
        return
    for tab in tuple(boss.all_tabs):
        if not wants_dock(tab):
            continue
        # Focusable, so a click or kspaces_focus.py can give the sidebar the keyboard, but --keep-focus so
        # adding one does not take focus from the window being worked in.
        prev = tab.active_window
        boss.call_remote_control(tab.active_window, (
            'launch', '--type=tab-dock', '--match', f'id:{tab.id}',
            '--dock-edge=left', f'--dock-size={DOCK_COLUMNS}', '--keep-focus',
            f'--var={DOCK_VAR}=1', '--add-to-session=!', KSPACES, 'sidebar',
        ))
        # --keep-focus only keeps the window that has focus. In any other tab the new dock becomes the tab's
        # active window, and the tab takes its title.
        if prev is not None and tab.active_window is not prev:
            tab.set_active_window(prev)


# Called from the tab bar and window hooks below. They fire in the middle of creating tabs and loading
# sessions, so launching from inside them could act on a half-built tab, and the launch itself fires them
# again. Doing it from a timer runs it once the current change is finished, and coalesces a burst of changes
# into one pass.
def schedule(boss):
    global _scheduled
    if _scheduled or getattr(boss, 'kspaces_hidden', False):
        return
    _scheduled = True

    def run(timer_id):
        global _scheduled
        _scheduled = False
        add_docks(boss)

    add_timer(run, 0, False)


def on_tab_bar_dirty(boss, window, data):
    schedule(boss)


# The tab bar does not change when the first window of a startup session appears, so new windows are a
# trigger too. kitty reports a window's creation as a resize from an all-zero geometry.
def on_resize(boss, window, data):
    if data['old_geometry'].xnum == 0:
        schedule(boss)
