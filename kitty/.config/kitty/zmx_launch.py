import fcntl
import os
import re
import subprocess

from kittens.tui.handler import result_handler

# kitty inherits a minimal PATH when started from the Dock, so binaries invoked
# from a kitten have to be resolved by absolute path.
ZMX_ATTACH = os.path.expanduser('~/.local/bin/zmx-attach')
ZMX = os.path.expanduser('~/.local/share/mise/shims/zmx')
LSOF = '/usr/sbin/lsof'

COUNTER = os.path.expanduser('~/.local/state/kitty-zmx/counter')

# kitty window ids get reused across restarts, so sessions are numbered from a
# counter of our own instead.
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


def session_of(window):
    argv = list(window.child.argv) if window is not None else []
    if len(argv) >= 2 and os.path.basename(argv[0]) == 'zmx-attach':
        return argv[1]
    return None


# zmx owns the window's pty, so the shell's cwd never reaches kitty and
# --cwd=current would always resolve to wherever the session was first started.
# The session's shell pid is the only handle on the real cwd.
# TODO: read this from a zmx label once labels accept slashes.
# https://github.com/neurosnap/zmx/issues/219
def session_cwd(name):
    try:
        listing = subprocess.run(
            [ZMX, 'ls'], capture_output=True, text=True, timeout=2
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return None

    pid = None
    for line in listing.splitlines():
        if re.search(r'\bname={}\b'.format(re.escape(name)), line):
            m = re.search(r'\bpid=(\d+)', line)
            if m:
                pid = m.group(1)
            break
    if pid is None:
        return None

    try:
        out = subprocess.run(
            [LSOF, '-a', '-p', pid, '-d', 'cwd', '-Fn'],
            capture_output=True, text=True, timeout=2,
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return None

    for line in out.splitlines():
        if line.startswith('n'):
            return line[1:]
    return None


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
    cmd.extend([ZMX_ATTACH, next_session_name()])
    boss.call_remote_control(window, tuple(cmd))
