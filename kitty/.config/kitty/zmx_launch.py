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

# Trailing path component of a zmx session socket, e.g. .../zmx-501/kitty.5
SOCKET_RE = re.compile(r'/zmx-\d+/(\S+)$')

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


def launched_session_of(window):
    argv = list(window.child.argv) if window is not None else []
    if len(argv) >= 2 and os.path.basename(argv[0]) == 'zmx-attach':
        return argv[1]
    return None


# `zmx attach` from a shell that already has ZMX_SESSION set retargets the
# session that shell's client is showing rather than attaching a new one, so a
# window can end up displaying a session its launch argv never mentioned. Only
# the socket the client actually holds says which one, and killing by the stale
# argv name would destroy an unrelated session.
def session_of(window):
    pid = getattr(window.child, 'pid', None) if window is not None else None
    return (live_session(pid) if pid else None) or launched_session_of(window)


def live_session(pid):
    peers = re.findall(r'->(0x[0-9a-f]+)', _lsof(['-p', str(pid), '-a', '-U']))
    if not peers:
        return None

    for line in _lsof(['-U']).splitlines():
        if any(peer in line for peer in peers):
            match = SOCKET_RE.search(line)
            if match:
                return match.group(1)
    return None


def _lsof(args):
    try:
        return subprocess.run(
            [LSOF] + args, capture_output=True, text=True, timeout=5
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return ''


# `zmx ls` prints one space-separated key=value line per session, with the
# current session's line prefixed by a marker, so fields are matched anywhere in
# the line rather than by position.
def session_fields():
    try:
        listing = subprocess.run(
            [ZMX, 'ls'], capture_output=True, text=True, timeout=2
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return {}

    sessions = {}
    for line in listing.splitlines():
        fields = dict(re.findall(r'(\w+)=(\S*)', line))
        name = fields.get('name')
        if name:
            sessions[name] = fields
    return sessions


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
