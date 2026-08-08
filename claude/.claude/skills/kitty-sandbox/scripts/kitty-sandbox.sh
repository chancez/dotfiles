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
#   kitty-sandbox.sh shot NAME [OUT.png]        # capture just this window
#   kitty-sandbox.sh show NAME                  # reveal + focus, to hand to the user
#   kitty-sandbox.sh hide NAME                  # send back to the background
#   kitty-sandbox.sh sock NAME
#   kitty-sandbox.sh rm NAME
#   kitty-sandbox.sh rm-all
#
# Sandboxes start hidden so they never steal focus or cover the user's work.
# They stay fully drivable while hidden (text/run/ls/screen all work). Only
# pixels need a real window, so `shot` shows the window for the capture and
# hides it again. Use `show` when handing a sandbox to the user to look at.

set -eu

# Overridable so a source build can be tested instead of the installed app.
KITTY=${KITTY_SANDBOX_KITTY:-/Applications/kitty.app/Contents/MacOS/kitty}
KITTEN=${KITTY_SANDBOX_KITTEN:-/Applications/kitty.app/Contents/MacOS/kitten}
ROOT=${KITTY_SANDBOX_ROOT:-${TMPDIR:-/tmp}/kitty-sandbox}

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
    # Register as a UIElement rather than a Foreground app so a background
    # sandbox stays out of the Dock and the cmd-tab switcher. Without this a
    # hidden sandbox still adds an icon and a switcher entry, so cmd-tabbing
    # while one is running lands on an invisible window.
    [ "$visible" -eq 0 ] && echo "macos_hide_from_tasks yes"
    [ -n "$extra_conf" ] && cat "$extra_conf"
  } > "$dir/kitty.conf"

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
    set -- "$@" "CM_RUNTIME_DIR=$dir/cm/r" "CM_STATE_DIR=$dir/cm/s" "CM_CONFIG="
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
  # them is the point.
  need_running
  "$KITTEN" @ --to "unix:$sock" resize-os-window --action=show
  ;;

hide)
  need_running
  "$KITTEN" @ --to "unix:$sock" resize-os-window --action=hide
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
  # Captures just this sandbox's OS window, not the whole display, by asking
  # kitty for its platform_window_id. Needs macOS screen-recording permission
  # for the process running this script; without it the png is solid black.
  need_running
  out=${1:-$dir/shot.png}
  # A hidden window is not composited, so capturing it yields a black grid with
  # only the titlebar drawn -- indistinguishable from a missing-permission
  # capture or a real rendering bug. So show it, capture, hide it again, and give
  # focus back to whatever had it. This is the one operation that must briefly
  # take focus; everything else stays in the background.
  front_before=$(lsappinfo info -only pid "$(lsappinfo front)" 2>/dev/null | sed 's/.*=//' | tr -d '"')
  "$KITTEN" @ --to "unix:$sock" resize-os-window --action=show >/dev/null 2>&1 || true
  # Give the compositor a frame to actually paint before screencapture reads it,
  # otherwise the capture races the show and comes back black anyway.
  sleep 0.8
  wid=$("$KITTEN" @ --to "unix:$sock" ls 2>/dev/null | python3 -c '
import json, sys
data = json.load(sys.stdin)
for osw in data:
    wid = osw.get("platform_window_id")
    if wid:
        print(wid); break
')
  # Re-hide and restore focus even on the error paths below, or a failed shot
  # leaves a visible sandbox sitting on top of the user's work.
  restore_focus() {
    [ "${visible_mode:-0}" -eq 1 ] && return 0
    "$KITTEN" @ --to "unix:$sock" resize-os-window --action=hide >/dev/null 2>&1 || true
    case "$front_before" in
      ''|*[!0-9]*) return 0 ;;
    esac
    osascript -e "tell application \"System Events\" to set frontmost of \
      (first process whose unix id is $front_before) to true" >/dev/null 2>&1 || true
  }
  # A sandbox created with --visible has no hidden state to return to, so leave
  # it alone rather than hiding a window the user asked to see.
  visible_mode=0
  grep -q '^macos_hide_from_tasks yes$' "$dir/kitty.conf" || visible_mode=1

  [ -n "$wid" ] || { restore_focus; echo "no platform_window_id for '$name'" >&2; exit 1; }
  screencapture -x -o -l "$wid" "$out"
  restore_focus
  # Without permission the capture comes back uniformly black, which reads as a
  # rendering bug rather than a permission problem. Check decoded pixels: png
  # bytes are useless here because even an all-black image compresses to varied
  # bytes, and sips reports metadata for every format, so scan a tiny BMP's
  # pixel array instead.
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
        print(f'warning: {src} is entirely black -- grant screen-recording '
              'permission to the process running this script', file=sys.stderr)
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
    CM_RUNTIME_DIR="$dir/cm/r" CM_STATE_DIR="$dir/cm/s" CM_CONFIG= cm kill --all >/dev/null 2>&1 || true
    CM_RUNTIME_DIR="$dir/cm/r" CM_STATE_DIR="$dir/cm/s" CM_CONFIG= cm server stop >/dev/null 2>&1 || true
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
