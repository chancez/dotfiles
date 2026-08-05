#!/bin/bash
# Send a macOS notification that focuses the originating kitty window when clicked.
# Usage: send-notification.sh TITLE MESSAGE [SOUND]

TITLE="$1"
MSG="$2"
SOUND="$3"

ARGS=(-title "$TITLE")
[ -n "$SOUND" ] && ARGS+=(-sound "$SOUND")

# terminal-notifier is a GUI app: it runs NSApplicationMain and blocks in its event
# loop waiting on a Mach reply from usernoted. That bootstrap port only resolves
# inside the Aqua session, so from anywhere else the connection is invalid and the
# process parks forever rather than exiting. A hook that never returns burns the
# full 600s command-hook timeout and shows up as a Stop hook stuck at 0 of 2.
#
# Both of the ways Claude runs here land outside Aqua: over ssh the shell is in the
# System domain, and a kitty window reattached to a launchd-parented zmx server
# inherits no GUI session either. Neither is detectable from SSH_TTY alone, so ask
# launchd directly. It answers in ~4ms.
if [ "$(launchctl managername 2>/dev/null)" != "Aqua" ]; then
  exit 0
fi

# Hooks inherit these from kitty, even when Claude runs headless inside neovim.
KITTY_BIN="/Applications/kitty.app/Contents/MacOS/kitty"

# A notification can be clicked long after it was posted, so the target has to be
# resolved then rather than now. KITTY_WINDOW_ID and KITTY_LISTEN_ON both go stale
# the moment kitty restarts: window ids are reassigned, and the socket carries
# kitty's pid. The zmx session name is the one identifier that survives, because the
# session outlives kitty and a restored window reattaches to the same one. So match
# on the session and discover the socket at click time.
#
# The match is a regex, so it is anchored and dots are escaped: unanchored,
# kitty.7 would also match kitty.71 and focus an unrelated window.
if [ -n "$ZMX_SESSION" ] && [ -x "$KITTY_BIN" ]; then
  session_re=${ZMX_SESSION//./\\.}
  ARGS+=(
    -activate net.kovidgoyal.kitty
    -execute "$(printf 'for s in /tmp/kitty-[0-9]*; do %q @ --to "unix:$s" focus-window --match %q && break; done' \
      "$KITTY_BIN" "cmdline:^${session_re}\$")"
  )
elif [ -n "$KITTY_LISTEN_ON" ] && [[ "$KITTY_WINDOW_ID" =~ ^[0-9]+$ ]] && [ -x "$KITTY_BIN" ]; then
  # No zmx session: fall back to the window id, which is correct until kitty restarts.
  ARGS+=(
    -activate net.kovidgoyal.kitty
    -execute "$(printf '%q @ --to %q focus-window --match id:%s' \
      "$KITTY_BIN" "$KITTY_LISTEN_ON" "$KITTY_WINDOW_ID")"
  )
fi

# Message is piped rather than passed via -message so a leading "-" isn't parsed as a flag
printf '%s' "$MSG" | terminal-notifier "${ARGS[@]}"
