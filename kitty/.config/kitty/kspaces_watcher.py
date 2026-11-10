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
#
# It also notes when each program status record (OSC 7501) of a window last changed state, which kitty
# does not report, so the sidebar can show how long a program has been blocked or working.
#
# The sidebars' width is [sidebar] width in kspaces' config, applied to every sidebar when it changes.

import json
import os
import time
import tomllib

from kitty.fast_data_types import add_timer

DOCK_VAR = 'kspaces'
# By absolute path: a watcher runs inside kitty, whose PATH under launchd does not have ~/.local/bin.
KSPACES = os.path.expanduser('~/.local/bin/kspaces')
# kspaces' default for [sidebar] width, and how often its config is checked for a new one.
DEFAULT_WIDTH = 28
CONFIG_CHECK_SECONDS = 2

_scheduled = False
# A pass of add_docks that schedule could not get a timer for, left to the config check.
_missed = False
# The config's sidebar width, and the modification time of the config it was read from.
_width = (DEFAULT_WIDTH, None)


def config_path():
    base = os.environ.get('XDG_CONFIG_HOME') or os.path.expanduser('~/.config')
    return os.path.join(base, 'kspaces', 'config.toml')


# sidebar_width is [sidebar] width from kspaces' config, read again only when the file changes. kspaces
# checks the config itself and shows what is wrong with it in the sidebar, so here a value it would reject
# just keeps the width there was.
def sidebar_width():
    global _width
    try:
        mtime = os.stat(config_path()).st_mtime
    except OSError:
        return _width[0]
    if mtime == _width[1]:
        return _width[0]
    width = _width[0]
    try:
        with open(config_path(), 'rb') as f:
            value = tomllib.load(f).get('sidebar', {}).get('width', DEFAULT_WIDTH)
        if isinstance(value, int) and 12 <= value <= 120:
            width = value
    except (OSError, ValueError):
        pass
    _width = (width, mtime)
    return width


# resize_docks gives every sidebar the configured width. kitty has no command to resize a dock, so this
# changes the size its group was docked with and lays the tab out again.
def resize_docks(boss, width):
    for tab in tuple(boss.all_tabs):
        changed = False
        for g in tab.windows.tab_docks:
            if g.dock is not None and any(DOCK_VAR in w.user_vars for w in g) and g.dock.size_as_string != str(width):
                g.dock = g.dock._replace(size=width, size_is_percent=False)
                changed = True
        if changed:
            tab.relayout()


def check_config(boss):
    def run(timer_id):
        global _missed
        resize_docks(boss, sidebar_width())
        if _missed:
            _missed = False
            add_docks(boss)

    add_timer(run, CONFIG_CHECK_SECONDS, True)


# Called when kitty loads this watcher, at startup and whenever kitty.conf's list of watchers changes. The
# flag on boss keeps a config reload from starting a second check.
def on_load(boss, data):
    if not getattr(boss, 'kspaces_checking_config', False):
        boss.kspaces_checking_config = True
        check_config(boss)


def has_dock(tab):
    return any(DOCK_VAR in w.user_vars for g in tab.windows.tab_docks for w in g)


def wants_dock(tab):
    return bool(tab.created_in_session_name) and bool(tab.windows.groups) and not has_dock(tab)


# TODO: fix in kitty. Moving a tab to another OS window, as detach_tab does, makes a new tab that takes
# over the old one's windows (Boss._move_tab_to, Tab.take_over_from) but not its session name. The windows
# keep theirs, so the tab is put back in their session here; until then tab_bar_filter's session:^$ shows
# the moved tab in every session.
def repair_session(tab):
    names = {w.created_in_session_name for w in tab} - {''}
    if not tab.created_in_session_name and len(names) == 1:
        tab.created_in_session_name = names.pop()
        tm = tab.tab_manager_ref()
        if tm is not None:
            tm.mark_tab_bar_dirty()


def add_docks(boss):
    for tab in tuple(boss.all_tabs):
        repair_session(tab)
    if getattr(boss, 'kspaces_hidden', False):
        return
    for tab in tuple(boss.all_tabs):
        if not wants_dock(tab):
            continue
        # Focusable, so a click or kspaces_focus.py can give the sidebar the keyboard, but --keep-focus so
        # adding one does not take focus from the window being worked in. In the tab's session, as a
        # window in no session makes tab_bar_filter's session:^$ match its tab: with another OS window
        # focused, kitty finds the tabs to show by their windows, so every tab with a sidebar was shown.
        # save_sessions.py leaves the docks out of saved sessions by their var.
        prev = tab.active_window
        boss.call_remote_control(tab.active_window, (
            'launch', '--type=tab-dock', '--match', f'id:{tab.id}',
            '--dock-edge=left', f'--dock-size={sidebar_width()}', '--keep-focus',
            f'--var={DOCK_VAR}=1', f'--add-to-session={tab.created_in_session_name}', KSPACES, 'sidebar',
        ))
        # --keep-focus only keeps the window that has focus. In any other tab the new dock becomes the tab's
        # active window, and the tab takes its title.
        if prev is not None and tab.active_window is not prev:
            tab.set_active_window(prev)


# Called from the tab bar and window hooks below. They fire in the middle of creating tabs and loading
# sessions, so launching from inside them could act on a half-built tab, and the launch itself fires them
# again. Doing it from a timer runs it once the current change is finished, and coalesces a burst of changes
# into one pass.
#
# kitty's timers are a fixed table on macOS, and add_timer returns 0, never to call back, when it is full, as
# it can be while sessions load. Then the pass is left to the config check, which is already running, rather
# than waiting forever for a timer that will not come.
def schedule(boss):
    global _scheduled, _missed
    if _scheduled:
        return
    _scheduled = True

    def run(timer_id):
        global _scheduled
        _scheduled = False
        add_docks(boss)

    if not add_timer(run, 0, False):
        _scheduled, _missed = False, True


def on_tab_bar_dirty(boss, window, data):
    schedule(boss)


# The tab bar does not change when the first window of a startup session appears, so new windows are a
# trigger too. kitty reports a window's creation as a resize from an all-zero geometry.
def on_resize(boss, window, data):
    if data['old_geometry'].xnum == 0:
        schedule(boss)


# The user variable that holds when each of a window's program status records last changed state, as JSON:
# {"pid": KITTY_PID, "records": {"RECORD_ID": ["STATE", UNIX_TIME]}}. Kept on the window because there is
# one sidebar per tab, each refreshing on its own every two seconds: noted here, at the change, every copy
# reads the same time and one started later still has it. Not named kspaces*, as save_sessions.py leaves
# windows with a var:kspaces out of saved sessions.
STATUS_AT_VAR = 'program_status_at'


def on_program_status_change(boss, window, data):
    try:
        prev = json.loads(window.user_vars.get(STATUS_AT_VAR, ''))
    except ValueError:
        prev = {}
    # User vars are saved into session files, so a restored window can bring times from a kitty that is
    # gone, for records that kitty no longer has. Only trust times noted by this kitty.
    known = prev.get('records', {}) if isinstance(prev, dict) and prev.get('pid') == os.getpid() else {}
    now = time.time()
    records = {}
    for r in data['program_status']:
        was = known.get(r['id'])
        records[r['id']] = was if was and was[0] == r['state'] else [r['state'], now]
    window.set_user_var(STATUS_AT_VAR, json.dumps({'pid': os.getpid(), 'records': records}) if records else None)
