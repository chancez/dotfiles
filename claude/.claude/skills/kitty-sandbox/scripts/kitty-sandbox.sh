#!/bin/sh
# Launch, drive, and tear down throwaway kitty instances.
#
# Every subcommand is scoped to a sandbox NAME, which becomes kitty's
# --instance-group. That name is what makes teardown safe: `pkill -f
# "instance-group $NAME"` cannot match the user's real kitty, which has no
# --instance-group argument at all.
#
# Usage:
#   kitty-sandbox.sh new NAME [--cmd "COMMAND"] [--conf EXTRA_CONF_FILE] [--zmx]
#   kitty-sandbox.sh ls NAME
#   kitty-sandbox.sh text NAME 'literal text to type'
#   kitty-sandbox.sh run NAME 'shell line'      # escape-safe, see below
#   kitty-sandbox.sh screen NAME [--all]
#   kitty-sandbox.sh sock NAME
#   kitty-sandbox.sh rm NAME
#   kitty-sandbox.sh rm-all

set -eu

KITTY=/Applications/kitty.app/Contents/MacOS/kitty
KITTEN=/Applications/kitty.app/Contents/MacOS/kitten
ROOT=${KITTY_SANDBOX_ROOT:-${TMPDIR:-/tmp}/kitty-sandbox}

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

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
  while [ $# -gt 0 ]; do
    case "$1" in
      --cmd) cmd=$2; shift 2 ;;
      --conf) extra_conf=$2; shift 2 ;;
      --zmx) use_zmx=1; shift ;;
      *) echo "unknown flag: $1" >&2; exit 1 ;;
    esac
  done

  mkdir -p "$dir"
  {
    echo "allow_remote_control yes"
    # The sandbox must never inherit the real config: a stray `map` or startup
    # session there would change what is being tested.
    echo "confirm_os_window_close 0"
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

  "$@" "$KITTY" \
    --config "$dir/kitty.conf" \
    --listen-on "unix:$sock" \
    --session "$dir/startup.session" \
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
  exit 0
  ;;

sock)
  echo "unix:$sock"
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

rm)
  # Matching on --instance-group is what keeps this from touching the real
  # kitty, which never carries that flag.
  pkill -f "instance-group $name" 2>/dev/null || true
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
