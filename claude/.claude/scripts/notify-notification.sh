#!/bin/bash
# Notification hook: tell me which session wants something, and what.

INPUT=$(cat)
MSG=$(printf '%s' "$INPUT" | jq -r '.message // "Claude needs your input"')
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
KIND=$(printf '%s' "$INPUT" | jq -r '.notification_type // empty')
# Present only when the notification came from inside a subagent.
AGENT=$(printf '%s' "$INPUT" | jq -r '.agent_type // empty')

# Claude Code sends a title of its own for most types. Fall back to spelling out the
# two types wired up in settings.json, then to the raw type for anything new.
EVENT=$(printf '%s' "$INPUT" | jq -r '.title // empty')
if [ -z "$EVENT" ]; then
  case "$KIND" in
  permission_prompt) EVENT="Permission needed" ;;
  idle_prompt) EVENT="Waiting for input" ;;
  *) EVENT="${KIND:-Notification}" ;;
  esac
fi
[ -n "$AGENT" ] && EVENT="$EVENT ($AGENT)"

"$(dirname "$0")/send-notification.sh" "$EVENT" "$MSG" "$CWD" Glass
