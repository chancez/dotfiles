#!/bin/bash
# Send a macOS notification that says which session it came from, and focuses that
# session's kitty window when clicked.
#
# Usage: send-notification.sh EVENT MESSAGE [CWD] [SESSION_ID] [SOUND]
#
#   EVENT       short description of what happened ("Permission needed", "Task done")
#   MESSAGE     notification body
#   CWD         session's working directory, for the repo/worktree line. Defaults to $PWD
#   SESSION_ID  hook input's session_id, used to look up the Claude session name
#   SOUND       terminal-notifier sound name

EVENT="$1"
MSG="$2"
CWD="${3:-$PWD}"
SESSION_ID="$4"
SOUND="$5"

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

# Hooks inherit these from kitty, even when Claude runs headless inside neovim.
KITTY_BIN="/Applications/kitty.app/Contents/MacOS/kitty"
CM_BIN=$(command -v cm 2>/dev/null)

# The title Claude Code shows for the session, which is how a session is recognised on
# screen. Nothing in the hook input carries it, and it does not live in one place
# either. Two sources, and the precedence between them is not guessable, so it was
# checked against the live titles of every open session:
#
#   1. `name` in ~/.claude/sessions/<pid>.json, when `nameSource` is not "derived".
#      An explicitly set name outranks the generated one: the session named
#      "hs-fw policy status delta delivery" shows exactly that, NOT its generated
#      "Set up worktree for HS FW delta delivery".
#   2. the last `ai-title` entry in the transcript, holding the generated title. This
#      is what reading only the sessions file missed: it said "hubble-timescape-37"
#      while the terminal read "Review PR 9258 for leader-follower gateway
#      compatibility".
#   3. `name` when it IS derived, a cwd placeholder like "hubble-timescape-37". Its
#      per-session suffix still separates the several sessions open on one repo.
claude_session_name() {
  local sid="$1" files=() rec name="" src="" ai transcript
  local -a matches
  [ -n "$sid" ] || return 0

  # Newest first, because more than one file can carry the same sessionId: resuming
  # leaves the previous process's file behind, holding whatever the name was then. One
  # jq over all of them is a single call, and jq emits matches in the order the files
  # were given, so the first line is current.
  #
  # Word splitting is safe: these paths are ~/.claude/sessions/<pid>.json.
  # shellcheck disable=SC2207
  files=($(ls -t "$HOME"/.claude/sessions/*.json 2>/dev/null))
  if [ ${#files[@]} -gt 0 ]; then
    rec=$(jq -r --arg sid "$sid" \
      'select(.sessionId == $sid) | [(.name // ""), (.nameSource // "")] | @tsv' \
      "${files[@]}" 2>/dev/null | head -1)
    name=${rec%%$'\t'*}
    src=${rec#*$'\t'}
  fi

  if [ -n "$name" ] && [ "$src" != derived ]; then
    printf '%s' "$name"
    return 0
  fi

  # A plain glob, not ls: session ids are unique, so at most one path matches.
  matches=("$HOME"/.claude/projects/*/"$sid".jsonl)
  transcript=${matches[0]}
  if [ -f "$transcript" ]; then
    # ai-title is rewritten every turn, so the last occurrence is the current title.
    # grep rather than jq because transcripts reach tens of megabytes and only one
    # field is wanted: 26MB scans in 20ms. The match is handed back to jq to decode
    # JSON escapes, which also drops a fragment truncated by an escaped quote instead
    # of showing a mangled title.
    ai=$(grep -o '"aiTitle":"[^"]*"' "$transcript" 2>/dev/null | tail -1)
    if [ -n "$ai" ]; then
      ai=$(printf '{%s}' "$ai" | jq -r '.aiTitle // empty' 2>/dev/null)
      [ -n "$ai" ] && printf '%s' "$ai" && return 0
    fi
  fi

  printf '%s' "$name"
}

SESSION=$(claude_session_name "$SESSION_ID")

# Fall back to the cm session name, which at least says which window to go to.
# CM_SESSION sometimes holds the session id rather than a name, which is what a
# session gets when it was created without one. An id like @fqwk9zdt says nothing at
# a glance, so trade a `cm info` call for the name. Guarded on the @ prefix so the
# usual case pays nothing.
if [ -z "$SESSION" ]; then
  SESSION="$CM_SESSION"
  if [ -n "$CM_BIN" ] && [ "${SESSION#@}" != "$SESSION" ]; then
    SESSION=$("$CM_BIN" info "$SESSION" --json 2>/dev/null | jq -r '.name // empty') || SESSION=""
    SESSION=${SESSION:-$CM_SESSION}
  fi
fi

# The event moved out of the title once titles became real generated ones: "Review PR
# 9258 for leader-follower gateway compatibility" is 55 characters, so a trailing
# ": Task done" was the part macOS cut off, losing the one thing that distinguishes
# waiting from finished. In the subtitle it is always visible, and the title gets the
# full width for identifying the session.
ARGS=(
  -title "${SESSION:-Claude}"
  -subtitle "$EVENT - $(location "$CWD")"
)
[ -n "$SOUND" ] && ARGS+=(-sound "$SOUND")

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
