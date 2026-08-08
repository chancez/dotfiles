import fcntl
import json
import os
import subprocess

from kittens.tui.handler import result_handler

# kitty inherits a minimal PATH when started from the Dock, so binaries invoked from a kitten have to
# be resolved by absolute path.
CM_ATTACH = os.path.expanduser('~/.local/bin/cm-attach')
CM = os.path.expanduser('~/.local/bin/cm')

COUNTER = os.path.expanduser('~/.local/state/kitty-cm/counter')


# Names are allocated here rather than by cm, even though cm can allocate them.
#
# kitty's save_as_session records a window's launch argv, so the session name has to be *in* the argv
# for a restored window to reattach rather than create a new session. That means the name must exist
# before the window is launched, and `cm attach` with no name only reports the one it allocated after
# the fact.
#
# kitty window ids are reused across restarts, which is why this counts rather than using the window
# id: a reused name would let a window reattach to a different session than it expected. The lock
# covers two windows opened at once.
def next_session_name():
    os.makedirs(os.path.dirname(COUNTER), exist_ok=True)
    fd = os.open(COUNTER, os.O_RDWR | os.O_CREAT, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)
        current = os.read(fd, 64).decode().strip()
        n = int(current) + 1 if current else 1
        os.lseek(fd, 0, os.SEEK_SET)
        os.truncate(fd, 0)
        os.write(fd, str(n).encode())
    finally:
        os.close(fd)
    return 'kitty.{}'.format(n)


def cm_json(args):
    """Run a cm command that emits JSON and return the parsed value, or None."""
    try:
        out = subprocess.run(
            [CM] + args, capture_output=True, text=True, timeout=5
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return None
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        return None


def sessions():
    """Every session cm knows, keyed by name."""
    listing = cm_json(['list', '--json']) or []
    return {s['name']: s for s in listing}


# The window's launch argv is authoritative, unlike under zmx.
#
# zmx needed lsof here, and it was not paranoia: `zmx attach` from a shell that already has ZMX_SESSION
# set retargets that shell's existing client rather than attaching a new one, so a window could end up
# showing a session its argv never mentioned, and killing by the argv name would destroy an unrelated
# session. cm never retargets -- it only ever exports CM_SESSION and never reads it -- so the name the
# window was launched with is the name it is showing.
def session_of(window):
    argv = list(window.child.argv) if window is not None else []
    if len(argv) >= 2 and os.path.basename(argv[0]) == 'cm-attach':
        return argv[1]
    return None


# The session's own idea of its directory, which cm tracks from OSC 7.
#
# Needed because cm owns the window's pty, so the shell's cwd never reaches kitty and --cwd=current
# would always resolve to wherever the session was first started. zmx got this by asking lsof for the
# shell's cwd; cm reports it directly, and reports whether it is even local: a session that has ssh'd
# elsewhere has a path that does not exist here, and opening a new window there would fail or land
# somewhere wrong.
def session_cwd(name):
    info = cm_json(['info', name, '--json'])
    if not info:
        return None
    if not info.get('cwd_is_local'):
        return None
    return info.get('cwd') or None


def main(args):
    return ''


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    window = boss.window_id_map.get(target_window_id)

    cwd = None
    name = session_of(window)
    if name is not None:
        cwd = session_cwd(name)
    if cwd is None and window is not None:
        cwd = window.cwd_of_child

    cmd = ['launch']
    cmd.extend(args[1:])
    if cwd:
        cmd.append('--cwd={}'.format(cwd))
    cmd.extend([CM_ATTACH, next_session_name()])
    boss.call_remote_control(window, tuple(cmd))
