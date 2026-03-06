#!/bin/bash

INPUT=$(cat)
TITLE="ClaudeCode"
MSG=$(echo "$INPUT" | jq -r '.message')

osascript -e "display notification \"$MSG\" with title \"$TITLE\" sound name \"Glass\""
