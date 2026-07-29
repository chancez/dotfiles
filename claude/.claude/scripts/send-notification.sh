#!/bin/bash
# Send a macOS notification that focuses the originating kitty window when clicked.
# Usage: send-notification.sh TITLE MESSAGE [SOUND]

TITLE="$1"
MSG="$2"
SOUND="$3"

ARGS=(-title "$TITLE")
[ -n "$SOUND" ] && ARGS+=(-sound "$SOUND")

# Hooks inherit these from kitty, even when Claude runs headless inside neovim.
# Window id must be numeric since it is interpolated into the -execute shell command.
KITTY_BIN="/Applications/kitty.app/Contents/MacOS/kitty"
if [ -n "$KITTY_LISTEN_ON" ] && [[ "$KITTY_WINDOW_ID" =~ ^[0-9]+$ ]] && [ -x "$KITTY_BIN" ]; then
  ARGS+=(
    -activate net.kovidgoyal.kitty
    -execute "$(printf '%q @ --to %q focus-window --match id:%s' \
      "$KITTY_BIN" "$KITTY_LISTEN_ON" "$KITTY_WINDOW_ID")"
  )
fi

# Message is piped rather than passed via -message so a leading "-" isn't parsed as a flag
printf '%s' "$MSG" | terminal-notifier "${ARGS[@]}"
