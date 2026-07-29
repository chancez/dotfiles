#!/bin/bash

INPUT=$(cat)
TITLE="ClaudeCode"
MSG=$(echo "$INPUT" | jq -r '.message')

# Message is piped rather than passed via -message so a leading "-" isn't parsed as a flag
printf '%s' "$MSG" | terminal-notifier -title "$TITLE" -sound Glass
