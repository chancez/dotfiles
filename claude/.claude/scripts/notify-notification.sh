#!/bin/bash

INPUT=$(cat)
TITLE="ClaudeCode"
MSG=$(echo "$INPUT" | jq -r '.message')

"$(dirname "$0")/send-notification.sh" "$TITLE" "$MSG" Glass
