#!/bin/bash
# Stop hook: say the turn is over, and which session finished it.
# https://nakamasato.medium.com/claude-code-hooks-automating-macos-notifications-for-task-completion-42d200e751cc

INPUT=$(cat)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty')
MSG=$(printf '%s' "$INPUT" | jq -r '.last_assistant_message // ""')

# last_assistant_message is the documented source for the final text of the turn.
# The transcript is written asynchronously and lags, so it is only a fallback.
if [ -z "$MSG" ]; then
  TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty')
  if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    # Latest assistant text from the tail, newlines flattened and clipped so the
    # notification stays one readable line.
    MSG=$(tail -10 "$TRANSCRIPT_PATH" |
      jq -r 'select(.message.role == "assistant")
             | .message.content[]?
             | select(.type == "text")
             | .text' 2>/dev/null |
      tail -1 |
      tr '\n' ' ' |
      cut -c1-120)
  fi
  MSG=${MSG:-"Task completed"}
fi

"$(dirname "$0")/send-notification.sh" "Task done" "$MSG" "$CWD" "$SESSION_ID"
