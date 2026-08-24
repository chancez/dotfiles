#!/bin/bash
# Send a macOS notification that says which session it came from, and focuses that
# session's kitty window when clicked.
#
# Usage: send-notification.sh EVENT MESSAGE [CWD] [SOUND]
#
#   EVENT    short description of what happened ("Permission needed", "Task done")
#   MESSAGE  notification body
#   CWD      session's working directory, for the repo/worktree line. Defaults to $PWD
#   SOUND    terminal-notifier sound name

EVENT="$1"
MSG="$2"
CWD="${3:-$PWD}"
SOUND="$4"

# terminal-notifier is a GUI app: it runs NSApplicationMain and blocks in its event
# loop waiting on a Mach reply from usernoted. That bootstrap port only resolves
# inside the Aqua session, so from anywhere else the connection is invalid and the
# process parks forever rather than exiting. A hook that never returns burns the
# full 600s command-hook timeout and shows up as a Stop hook stuck at 0 of 2.
#
# Both of the ways Claude runs here land outside Aqua: over ssh the shell is in the
# System domain, and a kitty window reattached to a launchd-parented cm server
# inherits no GUI session either. Neither is detectable from SSH_TTY alone, so ask
# launchd directly. It answers in ~4ms. Checked before anything else so a headless
# run pays none of the cost below.
if [ "$(launchctl managername 2>/dev/null)" != "Aqua" ]; then
  exit 0
fi

# Where the session is working, as a human would name it. A repo name alone does not
# distinguish the several sessions usually open on the same repo, so worktrees are
# named after the worktree and everything else after the branch. Both layouts in use
# here are handled: .worktrees/ for hand-made ones and .claude/worktrees/ for the
# ones Claude creates.
location() {
  local dir="$1" top repo wt="" branch
  [ -d "$dir" ] || dir="$PWD"
  top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || top="$dir"
  case "$top" in
  */.claude/worktrees/*)
    repo=${top%%/.claude/worktrees/*}
    wt=${top##*/.claude/worktrees/}
    ;;
  */.worktrees/*)
    repo=${top%%/.worktrees/*}
    wt=${top##*/.worktrees/}
    ;;
  *)
    repo=$top
    ;;
  esac
  repo=${repo##*/}

  if [ -n "$wt" ]; then
    printf '%s@%s' "$repo" "$wt"
    return
  fi
  branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null) || branch=""
  if [ -n "$branch" ]; then
    printf '%s (%s)' "$repo" "$branch"
  else
    printf '%s' "$repo"
  fi
}

# The cm session name leads the title: it is what you type to reach the session, and
# it is the only identifier that stays stable while the window it is shown in does
# not. cm exports CM_SESSION and never reads it, so this is the session the hook
# really ran in.
if [ -n "$CM_SESSION" ]; then
  TITLE="$CM_SESSION: $EVENT"
else
  TITLE="Claude: $EVENT"
fi

ARGS=(-title "$TITLE" -subtitle "$(location "$CWD")")
[ -n "$SOUND" ] && ARGS+=(-sound "$SOUND")

# Hooks inherit these from kitty, even when Claude runs headless inside neovim.
KITTY_BIN="/Applications/kitty.app/Contents/MacOS/kitty"
CM_BIN=$(command -v cm 2>/dev/null)

# A notification can be clicked long after it was posted, so the target window has to
# be resolved then rather than now.
#
# The inherited KITTY_WINDOW_ID and KITTY_LISTEN_ON cannot do it. cm sessions outlive
# kitty: quit and reopen, and the restored window reattaches the same session while
# kitty hands out a fresh socket path and reassigns window ids. A shell that started
# before that restart keeps the old values, so the socket is gone and the id now
# belongs to somebody else's window. Focusing the wrong session is worse than not
# focusing at all, and that is what this used to do.
#
# cm tracks what its session's current client reported, so ask cm at click time. This
# is also why the previous ZMX_SESSION lookup never ran: zmx became cm, so the
# variable was never set and every click fell through to the stale id.
if [ -n "$CM_SESSION" ] && [ -n "$CM_BIN" ] && [ -x "$KITTY_BIN" ]; then
  # The single quotes are the point: KITTY_LISTEN_ON and KITTY_WINDOW_ID have to reach
  # the click-time shell unexpanded, so it reads what the eval above just set.
  # shellcheck disable=SC2016
  ARGS+=(
    -activate net.kovidgoyal.kitty
    -execute "$(printf 'eval "$(%q get-env %q --format=posix)" && exec %q @ --to "$KITTY_LISTEN_ON" focus-window --match "id:$KITTY_WINDOW_ID"' \
      "$CM_BIN" "$CM_SESSION" "$KITTY_BIN")"
  )
elif [ -n "$KITTY_LISTEN_ON" ] && [[ "$KITTY_WINDOW_ID" =~ ^[0-9]+$ ]] && [ -x "$KITTY_BIN" ]; then
  # Not in a cm session, so nothing reattaches this window and the inherited values
  # describe it correctly for as long as it exists.
  ARGS+=(
    -activate net.kovidgoyal.kitty
    -execute "$(printf '%q @ --to %q focus-window --match id:%s' \
      "$KITTY_BIN" "$KITTY_LISTEN_ON" "$KITTY_WINDOW_ID")"
  )
fi

# Message is piped rather than passed via -message so a leading "-" isn't parsed as a flag
printf '%s' "$MSG" | terminal-notifier "${ARGS[@]}"
