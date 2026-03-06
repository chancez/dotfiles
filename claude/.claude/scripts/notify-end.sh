#!/bin/bash
# ~/.claude/scripts/notify-end.sh
# https://nakamasato.medium.com/claude-code-hooks-automating-macos-notifications-for-task-completion-42d200e751cc

# Read hook Input data from standard input
INPUT=$(cat)
# Get current session directory name (hooks run in the same directory as the session)
SESSION_DIR=$(basename "$(pwd)")
MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // ""')

if [ -z "$MSG" ]; then
  # Extract transcript_path
  TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path')
  # If transcript_path exists, get the latest assistant message
  if [ -f "$TRANSCRIPT_PATH" ]; then
    # Extract assistant messages from the last 10 lines and get the latest one
    # Remove newlines and limit to 60 characters
    MSG=$(tail -10 "$TRANSCRIPT_PATH" |
      jq -r 'select(.message.role == "assistant") | .message.content[0].text' |
      tail -1 |
      tr '\n' ' ' |
      cut -c1-60)

    # Fallback if no message is retrieved
    MSG=${MSG:-"Task completed"}
  else
    MSG="Task completed"
  fi
fi

TITLE="ClaudeCode ($SESSION_DIR) Task Done"
# Display macOS notification with sound using osascript
osascript -e "display notification \"$MSG\" with title \"$TITLE\""
