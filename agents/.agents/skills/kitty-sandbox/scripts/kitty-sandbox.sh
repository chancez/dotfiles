#!/bin/sh
# Launch, drive, and tear down throwaway kitty instances.
#
# Every subcommand is scoped to a sandbox NAME, which becomes kitty's
# --instance-group. That name is what makes teardown safe: `pkill -f
# "instance-group $NAME"` cannot match the user's real kitty, which has no
# --instance-group argument at all.
#
# Usage:
#   kitty-sandbox.sh new NAME [--cmd "COMMAND"] [--conf EXTRA_CONF_FILE] [--zmx] [--visible]
#   kitty-sandbox.sh ls NAME
#   kitty-sandbox.sh text NAME 'literal text to type'
#   kitty-sandbox.sh run NAME 'shell line'      # escape-safe, see below
#   kitty-sandbox.sh screen NAME [--all]
#   kitty-sandbox.sh shot NAME [OUT.png]        # png of kitty's rendering, stays hidden
#   kitty-sandbox.sh show NAME                  # reveal + focus, to hand to the user
#   kitty-sandbox.sh hide NAME                  # send back to the background
#   kitty-sandbox.sh sock NAME
#   kitty-sandbox.sh rm NAME
#   kitty-sandbox.sh rm-all
#
# Sandboxes start hidden so they never steal focus or cover the user's work,
# and a guard loaded into each one keeps it from activating later. They stay
# fully drivable while hidden (text/run/ls/screen/shot all work). Use `show`
# when handing a sandbox to the user to look at; it is the only thing that
# takes focus on purpose.

set -eu

# Overridable so a source build can be tested instead of the installed app.
KITTY=${KITTY_SANDBOX_KITTY:-/Applications/kitty.app/Contents/MacOS/kitty}
KITTEN=${KITTY_SANDBOX_KITTEN:-/Applications/kitty.app/Contents/MacOS/kitten}
# cm's Unix sockets have a 104-byte cap on macOS. TMPDIR commonly expands to a much longer
# per-user path, so using it here makes a --cm sandbox fail only once cm starts its server.
ROOT=${KITTY_SANDBOX_ROOT:-/tmp/kitty-sandbox}

# Print the leading comment block, stopping at the first non-comment line, so
# adding usage lines above does not require adjusting a hardcoded range.
usage() { sed -n '2,${/^#/!q;s/^# \{0,1\}//;p;}' "$0"; exit 1; }

[ $# -ge 1 ] || usage
sub=$1; shift

name=
if [ "$sub" != "rm-all" ]; then
  [ $# -ge 1 ] || usage
  name=$1
  shift
fi

dir="$ROOT/$name"
sock="$dir/sock"

need_running() {
  [ -S "$sock" ] || { echo "sandbox '$name' has no socket at $sock" >&2; exit 1; }
}

case "$sub" in
new)
  cmd=/bin/sh
  extra_conf=
  use_zmx=0
  use_cm=0
  visible=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --cmd) cmd=$2; shift 2 ;;
      --conf) extra_conf=$2; shift 2 ;;
      --zmx) use_zmx=1; shift ;;
      --cm) use_cm=1; shift ;;
      --visible) visible=1; shift ;;
      *) echo "unknown flag: $1" >&2; exit 1 ;;
    esac
  done

  mkdir -p "$dir"
  {
    echo "allow_remote_control yes"
    # The sandbox must never inherit the real config: a stray `map` or startup
    # session there would change what is being tested.
    echo "confirm_os_window_close 0"
    # Not inheriting the real config also means not inheriting its
    # `enable_audio_bell no`, so a sandbox falls back to kitty's default and
    # beeps out loud. A hidden window the user cannot see making a noise they
    # cannot attribute is worse than the noise: any BEL a test produces (a shell
    # error, readline completion, a truncated OSC sequence) reads as coming from
    # their own terminal. Silence every channel a bell can reach, not just the
    # sound: window_alert_on_bell raises a macOS notification and bell_on_tab
    # marks the tab bar, which also corrupts a tab-title assertion.
    echo "enable_audio_bell no"
    echo "window_alert_on_bell no"
    echo "bell_on_tab no"
    echo "command_on_bell none"
    # Register as a UIElement rather than a Foreground app so a background
    # sandbox stays out of the Dock and the cmd-tab switcher. Without this a
    # hidden sandbox still adds an icon and a switcher entry, so cmd-tabbing
    # while one is running lands on an invisible window.
    [ "$visible" -eq 0 ] && echo "macos_hide_from_tasks yes"
    # Hidden is not enough on its own: kitty activates the app whenever it
    # shows or focuses an OS window, so see nofocus.py below.
    [ "$visible" -eq 0 ] && echo "watcher $dir/nofocus.py"
    # extra_conf stays last on purpose: kitty takes the final value for a scalar
    # option, so a test whose subject is one of the defaults above can turn it
    # back on via --conf.
    [ -n "$extra_conf" ] && cat "$extra_conf"
  } > "$dir/kitty.conf"

  # glfw focuses a window whenever it shows one, and focusing activates the
  # whole app, which then takes the user's keystrokes. A hidden sandbox still
  # does this for every OS window created inside it (launch --type=os-window,
  # session new_os_window, detach-tab/-window, the window LaunchServices asks
  # for when it picks this instance for a Dock click or `open -a kitty`), for
  # focus-window across OS windows, and when closing an OS window focuses the
  # next one, which `rm` does. This runs in the sandbox's own process as a
  # global watcher and stops all of that there; `show` turns it off.
  if [ "$visible" -eq 0 ]; then
    cat > "$dir/nofocus.py" <<'PY'
# Loaded into a hidden sandbox as a global watcher, so it runs in the
# sandbox's boss process. Keeps the sandbox from ever becoming the active app
# unless `show` asked for it. Run as a kitten with `allow` or `deny` to flip it.
import ctypes

from kittens.tui.handler import result_handler

C, P, B = ctypes.CFUNCTYPE, ctypes.c_void_p, ctypes.c_bool
objc = ctypes.cdll.LoadLibrary('/usr/lib/libobjc.A.dylib')
for fn, res, args in (
    ('objc_getClass', P, [ctypes.c_char_p]),
    ('sel_registerName', P, [ctypes.c_char_p]),
    ('object_getClass', P, [P]),
    ('class_getMethodImplementation', P, [P, P]),
    ('class_replaceMethod', P, [P, P, P, ctypes.c_char_p]),
    ('objc_allocateClassPair', P, [P, ctypes.c_char_p, ctypes.c_size_t]),
    ('class_addMethod', B, [P, P, P, ctypes.c_char_p]),
    ('objc_registerClassPair', None, [P]),
):
    f = getattr(objc, fn)
    f.restype, f.argtypes = res, args
send = ctypes.cast(objc.objc_msgSend, P).value
cls, sel = objc.objc_getClass, objc.sel_registerName


def msg(restype, *argtypes):
    return C(restype, P, P, *argtypes)(send)


def main(args):
    pass


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    boss.sandbox_focus_guard(len(args) > 1 and args[1] == 'allow')


def on_load(boss, data):
    app = msg(P)(cls(b'NSApplication'), sel(b'sharedApplication'))
    is_active = is_visible = msg(B)
    send_obj = msg(None, P)
    act_name, mkf_name = b'activateIgnoringOtherApps:', b'makeKeyAndOrderFront:'
    act_orig = C(None, P, P, B)(objc.class_getMethodImplementation(cls(b'NSApplication'), sel(act_name)))
    mkf_orig = C(None, P, P, P)(objc.class_getMethodImplementation(cls(b'NSWindow'), sel(mkf_name)))
    state = {'allowed': False}

    # glfw activates the whole app whenever it shows or focuses a window. Drop
    # that so creating, closing, or focusing an OS window cannot take focus.
    @C(None, P, P, B)
    def activate(self, cmd, flag):
        if state['allowed']:
            act_orig(self, cmd, flag)

    # Focusing a hidden window would also order it onto the screen.
    @C(None, P, P, P)
    def make_key_and_order_front(self, cmd, sender):
        if state['allowed'] or is_visible(self, sel(b'isVisible')):
            mkf_orig(self, cmd, sender)

    # Activation from outside, such as LaunchServices picking this instance
    # for a Dock click or `open -a kitty`, cannot be refused, only undone.
    # hide: hands activation to the next app at once.
    @C(None, P, P, P)
    def became_active(self, cmd, note):
        if not state['allowed']:
            send_obj(app, sel(b'hide:'), None)

    objc.class_replaceMethod(objc.object_getClass(app), sel(act_name), ctypes.cast(activate, P), b'v@:B')
    objc.class_replaceMethod(cls(b'GLFWWindow'), sel(mkf_name), ctypes.cast(make_key_and_order_front, P), b'v@:@')
    obs_cls = objc.objc_allocateClassPair(cls(b'NSObject'), b'KittySandboxFocusGuard', 0)
    objc.class_addMethod(obs_cls, sel(b'becameActive:'), ctypes.cast(became_active, P), b'v@:@')
    objc.objc_registerClassPair(obs_cls)
    observer = msg(P)(msg(P)(obs_cls, sel(b'alloc')), sel(b'init'))
    note = msg(P, ctypes.c_char_p)(cls(b'NSString'), sel(b'stringWithUTF8String:'), b'NSApplicationDidBecomeActiveNotification')
    center = msg(P)(cls(b'NSNotificationCenter'), sel(b'defaultCenter'))
    msg(None, P, P, P, P)(center, sel(b'addObserver:selector:name:object:'), observer, sel(b'becameActive:'), note, None)

    # A new OS window is shown, and so focused, at creation; create it hidden.
    add_os_window = boss.add_os_window

    def add_hidden_os_window(*a, **kw):
        if not state['allowed']:
            kw['window_state'] = 'hidden'
        return add_os_window(*a, **kw)

    def set_allowed(allowed):
        state['allowed'] = allowed
        if allowed:
            send_obj(app, sel(b'unhide:'), None)
        elif is_active(app, sel(b'isActive')):
            send_obj(app, sel(b'hide:'), None)

    boss.add_os_window = add_hidden_os_window
    boss.sandbox_focus_guard = set_allowed
    # ctypes callbacks must outlive this call or the swizzled methods crash.
    boss.sandbox_focus_guard_refs = (activate, make_key_and_order_front, became_active, observer)
PY
  fi

  printf 'launch %s\n' "$cmd" > "$dir/startup.session"

  # A login shell needs a real PATH or the window dies instantly with
  # "command not found", which looks confusingly like the window "not opening".
  sandbox_path="$HOME/.local/share/mise/shims:$HOME/.local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Applications/kitty.app/Contents/MacOS"

  # env -i drops TMPDIR, which silently relocates zmx's socket dir to a shared
  # one. ZMX_DIR is priority 1 in zmx's resolution, so set it explicitly to keep
  # sandbox sessions away from the user's live ones.
  set -- env -i "HOME=$HOME" "SHELL=${SHELL:-/bin/sh}" "TERM=xterm-kitty" "PATH=$sandbox_path"
  if [ "$use_zmx" -eq 1 ]; then
    mkdir -p "$dir/zmx"
    set -- "$@" "ZMX_DIR=$dir/zmx"
  fi
  # Same hazard as zmx, different variables. env -i drops CM_RUNTIME_DIR and
  # CM_STATE_DIR, so a sandbox testing cm would otherwise put its sessions in the
  # user's real runtime dir, which is where their live sessions are. Both are
  # needed: the runtime dir holds the sockets and the state dir the database, and
  # setting only one leaves sessions half-shared.
  if [ "$use_cm" -eq 1 ]; then
    mkdir -p "$dir/cm/r" "$dir/cm/s"
    set -- "$@" "CM_RUNTIME_DIR=$dir/cm/r" "CM_STATE_DIR=$dir/cm/s" "CM_CONFIG=$dir/cm/absent.toml"
  fi

  # --start-as=hidden keeps the sandbox from stealing focus and from opening in
  # front of the user's work.
  start_as=--start-as=hidden
  [ "$visible" -eq 1 ] && start_as=--start-as=normal

  # Ordering matters: --instance-group must stay the LAST argument, because `rm`
  # matches it with a `$`-anchored pattern. Adding any flag after it silently
  # breaks teardown and leaks kitty processes.
  "$@" "$KITTY" \
    --config "$dir/kitty.conf" \
    --listen-on "unix:$sock" \
    --session "$dir/startup.session" \
    "$start_as" \
    --instance-group "$name" \
    > "$dir/kitty.log" 2>&1 &

  # Wait for the socket rather than sleeping a fixed amount: startup time
  # varies and a fixed sleep is either slow or flaky.
  i=0
  while [ $i -lt 100 ]; do
    [ -S "$sock" ] && break
    i=$((i + 1)); sleep 0.1
  done
  [ -S "$sock" ] || { echo "kitty did not come up; see $dir/kitty.log" >&2; exit 1; }

  # The socket can exist before the window does.
  i=0
  while [ $i -lt 100 ]; do
    if "$KITTEN" @ --to "unix:$sock" ls 2>/dev/null | grep -q '"id"'; then break; fi
    i=$((i + 1)); sleep 0.1
  done

  echo "sandbox=$name"
  echo "socket=unix:$sock"
  echo "dir=$dir"
  [ "$use_zmx" -eq 1 ] && echo "zmx_dir=$dir/zmx"
  [ "$use_cm" -eq 1 ] && echo "cm_runtime_dir=$dir/cm/r cm_state_dir=$dir/cm/s"
  exit 0
  ;;

sock)
  echo "unix:$sock"
  ;;

show)
  # Reveal the window and bring it forward. This deliberately takes focus: it is
  # for handing the sandbox to the user, which is the one case where interrupting
  # them is the point. The guard has to step aside first or it undoes the show.
  need_running
  if [ -f "$dir/nofocus.py" ]; then
    "$KITTEN" @ --to "unix:$sock" kitten "$dir/nofocus.py" allow
  fi
  "$KITTEN" @ --to "unix:$sock" resize-os-window --action=show
  ;;

hide)
  # Re-arming the guard also hands activation back to the previous app; a
  # bare hide leaves the sandbox active with no window, swallowing keystrokes.
  need_running
  "$KITTEN" @ --to "unix:$sock" resize-os-window --action=hide
  if [ -f "$dir/nofocus.py" ]; then
    "$KITTEN" @ --to "unix:$sock" kitten "$dir/nofocus.py" deny
  fi
  ;;

ls)
  need_running
  "$KITTEN" @ --to "unix:$sock" ls 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print("no window data"); raise SystemExit
for osw in data:
    for tab in osw["tabs"]:
        print("tab title=%r layout=%s" % (tab.get("title"), tab.get("layout")))
        for w in tab["windows"]:
            print("  id=%s pid=%s title=%r cwd=%s" % (
                w["id"], w.get("pid"), w.get("title"), w.get("cwd")))
            fg = w.get("foreground_processes") or []
            for p in fg:
                print("     running: %s" % " ".join(p.get("cmdline") or []))
'
  ;;

text)
  need_running
  [ $# -ge 1 ] || usage
  "$KITTEN" @ --to "unix:$sock" send-text "$1"
  ;;

run)
  need_running
  [ $# -ge 1 ] || usage
  # send-text mangles backslash escapes in transit, so a line containing \033
  # arrives corrupted and the test silently measures nothing. Writing the line
  # to a file and sourcing it means the shell, not kitty, interprets it.
  printf '%s\n' "$1" > "$dir/run.sh"
  "$KITTEN" @ --to "unix:$sock" send-text "source $dir/run.sh
"
  ;;

screen)
  need_running
  extent=screen
  [ "${1:-}" = "--all" ] && extent=all
  "$KITTEN" @ --to "unix:$sock" get-text --extent "$extent"
  ;;

shot)
  # kitty renders the active OS window (tab bar included) into an offscreen
  # buffer and writes the png itself, so this works while the sandbox is
  # hidden and never shows, raises, or focuses it. screencapture could not:
  # macOS does not composite a hidden window, so it needed a show, and glfw
  # focuses on show, which put the user's typing into the sandbox. This also
  # needs no screen-recording permission. The macOS titlebar, shadow, and any
  # transparency over the desktop are not in the image; they are not kitty's.
  need_running
  out=${1:-$dir/shot.png}
  # kitty, not this script, opens the file, and its cwd is not ours.
  case "$out" in /*) ;; *) out="$PWD/$out" ;; esac
  "$KITTEN" @ --to "unix:$sock" screenshot "$out" >/dev/null
  # An all-black png reads as a rendering bug, so say so rather than leave it
  # to be eyeballed. Check decoded pixels: png bytes are useless here because
  # even an all-black image compresses to varied bytes, and sips reports
  # metadata for every format, so scan a tiny BMP's pixel array instead.
  python3 - "$out" <<'PY' >&2 || true
import struct, subprocess, sys, tempfile, os
src = sys.argv[1]
tmp = os.path.join(tempfile.gettempdir(), 'kitty-sandbox-probe.bmp')
subprocess.run(['sips', '-s', 'format', 'bmp', '--resampleHeightWidth', '8', '8',
                src, '--out', tmp], capture_output=True)
try:
    d = open(tmp, 'rb').read()
    off = struct.unpack('<I', d[10:14])[0]
    if not any(d[off:]):
        print(f'warning: {src} is entirely black -- kitty painted nothing; '
              'compare with `screen`', file=sys.stderr)
finally:
    if os.path.exists(tmp):
        os.remove(tmp)
PY
  echo "$out"
  ;;

rm)
  # Matching on --instance-group is what keeps this from touching the real
  # kitty, which never carries that flag. The trailing $ anchors the name so
  # `rm w1` cannot also kill a sandbox named w10.
  pkill -f "instance-group $name\$" 2>/dev/null || true
  sleep 1
  # Kill sessions before removing the directory: zmx resolves a session by its
  # socket path, so deleting the directory first leaves the daemons running with
  # no way left to address them.
  if [ -d "$dir/zmx" ]; then
    for s in "$dir/zmx"/*; do
      [ -S "$s" ] || continue
      ZMX_DIR="$dir/zmx" zmx kill "$(basename "$s")" --force >/dev/null 2>&1 || true
    done
    sleep 1
  fi
  # Same for cm, and for a sharper reason: cm keeps its database in the state dir, so removing the
  # directory under a running server leaves it alive with its store deleted. That looks exactly like
  # "the sessions did not survive", which is the behaviour a cm test is usually checking, so skipping
  # this produces a convincing false failure rather than a leak.
  if [ -d "$dir/cm" ]; then
    CM_RUNTIME_DIR="$dir/cm/r" CM_STATE_DIR="$dir/cm/s" CM_CONFIG="$dir/cm/absent.toml" cm kill --all >/dev/null 2>&1 || true
    CM_RUNTIME_DIR="$dir/cm/r" CM_STATE_DIR="$dir/cm/s" CM_CONFIG="$dir/cm/absent.toml" cm server stop >/dev/null 2>&1 || true
    sleep 1
  fi
  rm -rf "$dir"
  echo "removed sandbox=$name"
  ;;

rm-all)
  [ -d "$ROOT" ] || { echo "no sandboxes"; exit 0; }
  for d in "$ROOT"/*; do
    [ -d "$d" ] || continue
    n=$(basename "$d")
    "$0" rm "$n" || true
  done
  ;;

*)
  usage
  ;;
esac
