# Save every kitty session to its own file, and bring them back at startup.
#
# Loaded twice: as a watcher, to save on quit and restore at startup, and as a kitten (f1), to save on demand.
#
# One file per session because kitty names a session after the file it was loaded from and labels every tab
# the file creates with that name. Saving all tabs into one file would bring every session back as that one
# file's session. The default session, named after startup_session, also takes the tabs that belong to no
# session, so nothing open is left unsaved.
#
# kspaces sidebar docks are never saved. kspaces_watcher.py adds them back to restored tabs.

import os
import re

from kitty.config import atomic_save
from kitty.fast_data_types import add_timer, current_focused_os_window_id, get_options, last_focused_os_window_id
from kitty.session import parse_save_as_options_spec_args
from kittens.tui.handler import result_handler

# Names of the sessions written by the last save, other than the default one, which startup_session already
# loads. Read and removed at startup.
OPEN_LIST = '.open-sessions'


def startup_path():
    path = get_options().startup_session
    return os.path.expanduser(path) if path and path != 'none' else ''


def session_path(name):
    return os.path.join(os.path.dirname(startup_path()), name + '.kitty-session')


def default_name():
    return os.path.basename(startup_path()).rpartition('.')[0]


# What save_as_session --match writes, with two bugs fixed. It leaves out the `new_os_window` line only for
# the first OS window it iterates (Boss.serialize_state_as_session, `is_first=i == 0`), not for the first
# one it writes. When that window has no matching windows, the file starts with `new_os_window`, and
# restore() opens the session in an OS window of its own instead of the current one; with a second OS window
# open at quit, every space came back in its own. Which window comes first depends on focus. This is that
# loop, passing is_first to the first OS window that has output.
#
# And its `focus_tab` is the OS window's active tab's index among all of its tabs, while loading counts only
# the tabs the file creates: every session but the one on screen came back on the wrong tab. See
# focus_tab_line.
# TODO: fix both in kitty, then go back to boss.save_as_session. --match dates from e43d894dd, a week after
# is_first (067afe35e).
def save_matching(boss, match, path, main):
    opts, _ = parse_save_as_options_spec_args(['--use-foreground-process', f'--match={match}'])
    matched = frozenset(boss.match_windows(match))
    lines, first = [], True
    for os_window_id in os_window_order(boss, main):
        tm = boss.os_window_map[os_window_id]
        out = tm.serialize_state_as_session(path, matched, opts, is_first=first)
        if out:
            out = [line for line in out if not line.startswith('focus_tab ')] + [focus_tab_line(tm, matched)]
        first = first and not out
        lines.extend(out)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    atomic_save('\n'.join(lines).encode(), path)


# focus_tab_line focuses, among the tabs of tm the file creates, the one with the session's most recently
# focused window, which is the tab kitty switches to when going to the session while it is open.
def focus_tab_line(tm, matched):
    saved = [[w for w in tab if w in matched] for tab in tm]
    saved = [ws for ws in saved if ws]
    latest = max(range(len(saved)), key=lambda i: max(w.last_focused_at for w in saved[i]))
    return f'focus_tab {latest}'


# The OS windows in the order they are saved: kitty's, by focus, but with main last. kitty creates the OS
# windows of startup_session in order and focuses the last, and restore() loads the spaces' files into the
# focused one, so this puts the spaces back in the OS window they were in rather than in whichever had
# focus at quit.
def os_window_order(boss, main):
    order = {current_focused_os_window_id(): 2, last_focused_os_window_id(): 1, main: 3}
    return sorted(boss.os_window_map, key=lambda wid: order.get(wid, 0))


# main_os_window is the OS window holding the most windows of the spaces' sessions, or the last focused.
def main_os_window(boss, sessions):
    counts = {}
    for w in boss.all_windows:
        if w.created_in_session_name in sessions:
            counts[w.os_window_id] = counts.get(w.os_window_id, 0) + 1
    return max(counts, key=counts.get) if counts else last_focused_os_window_id()


def session_match(name):
    if name == default_name():
        return f'(session:^{re.escape(name)}$ or session:^$) and not var:kspaces'
    return f'session:^{re.escape(name)}$ and not var:kspaces'


def save_all(boss):
    if not startup_path():
        return
    default = default_name()
    others = sorted(n for n in boss.all_loaded_session_names if n != default)
    main = main_os_window(boss, set(others))
    for name in [default] + others:
        save_matching(boss, session_match(name), session_path(name), main)
    with open(os.path.join(os.path.dirname(startup_path()), OPEN_LIST), 'w') as f:
        f.write(''.join(n + '\n' for n in others))


# Saving at quit alone left a session's file as it was at the last quit: closing a session's tabs and panes
# and opening it again brought them all back. So a session is also saved a moment after one of its windows
# closes or takes focus, which keeps which window is focused too. A session whose last window closed has
# its file removed, so opening it again starts afresh. The default session's file is startup_session's and
# is never removed.
#
# Not while kitty quits, which closes every window after on_quit has saved them, nor for the windows of an
# OS window closed as a whole, which kitty also closes one by one: either would remove every file. The
# sessions keep what was saved before, as when the last of them took focus.
SAVE_DELAY = 0.5
_quitting = False
# Session names waiting to be saved, each with the OS windows its windows closed in.
_pending = {}
_timer = None


def note_change(boss, window, closed):
    global _timer
    if _quitting or not startup_path() or any(k.startswith('kspaces') for k in window.user_vars):
        return
    name = window.created_in_session_name or default_name()
    os_windows = _pending.setdefault(name, set())
    if closed:
        os_windows.add(window.os_window_id)
    if _timer is None:
        # kitty's timers are a fixed table on macOS, and add_timer returns 0, never to call back, when it is
        # full, as it can be at startup with every watcher call taking one. Keeping 0 would wait for that
        # timer forever; the next change tries again instead, and saves what has piled up since.
        _timer = add_timer(lambda timer_id: save_pending(boss), SAVE_DELAY, False) or None


def save_pending(boss):
    global _timer, _pending
    _timer, pending, _pending = None, _pending, {}
    if _quitting or not boss.os_window_map:
        return
    main = main_os_window(boss, set(boss.all_loaded_session_names) - {default_name()})
    for name, closed_in in pending.items():
        if any(i not in boss.os_window_map for i in closed_in):
            continue
        match = session_match(name)
        if any(True for _ in boss.match_windows(match)):
            save_matching(boss, match, session_path(name), main)
        elif name != default_name():
            try:
                os.remove(session_path(name))
            except FileNotFoundError:
                pass


def on_close(boss, window, data):
    note_change(boss, window, closed=True)


def on_focus_change(boss, window, data):
    if data.get('focused'):
        note_change(boss, window, closed=False)


def restore(boss):
    list_path = os.path.join(os.path.dirname(startup_path()), OPEN_LIST)
    try:
        with open(list_path) as f:
            names = [line.strip() for line in f if line.strip()]
        os.remove(list_path)
    except FileNotFoundError:
        return
    for name in names:
        if os.path.exists(session_path(name)):
            boss.goto_session(session_path(name))
    # Loading a session switches to it, so end up back where startup_session left off.
    if names and startup_path():
        boss.goto_session(startup_path())


# Called when kitty loads this watcher, which is during startup, while startup_session is being created, and
# again whenever kitty.conf's list of watchers changes. The timer runs the restore once the startup session
# is in place. The flag on boss keeps a config reload from restoring sessions a second time.
def on_load(boss, data):
    if getattr(boss, 'sessions_restored', False):
        return
    boss.sessions_restored = True
    add_timer(lambda timer_id: restore(boss), 0, False)


# kitty has no exit event, only this quit hook, so every session is saved when the app is asked to
# terminate: the macOS menu/Dock Quit item, cmd+q, or logout.
def on_quit(boss, window, data):
    global _quitting
    # Called once before the confirmation dialog and again after it is accepted.
    if data.get('confirmed'):
        _quitting = True
        save_all(boss)


def main(args):
    return ''


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    save_all(boss)
