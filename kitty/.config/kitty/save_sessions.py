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

from kitty.fast_data_types import add_timer, get_options
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


def save_all(boss):
    if not startup_path():
        return
    default = default_name()
    others = sorted(n for n in boss.all_loaded_session_names if n != default)
    matches = {default: f'(session:^{re.escape(default)}$ or session:^$) and not var:kspaces'}
    for name in others:
        matches[name] = f'session:^{re.escape(name)}$ and not var:kspaces'
    for name, match in matches.items():
        boss.save_as_session('--save-only', '--use-foreground-process', f'--match={match}', session_path(name))
    with open(os.path.join(os.path.dirname(startup_path()), OPEN_LIST), 'w') as f:
        f.write(''.join(n + '\n' for n in others))


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


# kitty has no exit event, only this quit hook, so sessions are saved when the app is asked to terminate:
# the macOS menu/Dock Quit item, cmd+q, or logout. Closing OS windows one at a time still bypasses it, there
# is nothing to hook.
def on_quit(boss, window, data):
    # Called once before the confirmation dialog and again after it is accepted.
    if data.get('confirmed'):
        save_all(boss)


def main(args):
    return ''


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    save_all(boss)
