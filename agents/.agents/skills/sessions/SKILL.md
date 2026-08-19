---
name: sessions
description: Manage and delete Claude Code sessions. Use when the user wants to list, inspect, delete, or get stats about their Claude sessions.
argument-hint: [list|show|delete|cleanup|stats] [options]
allowed-tools: Bash, Read
---

# Session Manager

You are helping the user manage their Claude Code sessions. Use the helper script at `${CLAUDE_SKILL_DIR}/scripts/sessions.py` to perform operations.

## Available Commands

Run these via `python3 ${CLAUDE_SKILL_DIR}/scripts/sessions.py <command>`:

- **`list`** - List sessions (most recent first)
  - `--project/-p <filter>` - Filter by project path substring
  - `--limit/-n <N>` - Limit results (default: 20)
- **`show <session_id>`** - Show detailed info about a session: metadata, original prompt, and recent messages
  - `--tail/-t <N>` - Number of recent messages to show (default: 10)
  - Supports prefix matching on session IDs
- **`delete [session_ids...]`** - Delete sessions by ID, project, or age
  - Pass one or more session IDs (or prefixes) as positional arguments
  - `--project/-p <filter>` - Delete all sessions matching a project path substring
  - `--older-than <age>` - Delete sessions older than a relative age (e.g. `12h`, `7d`, `2w`, `1m`)
  - `--before <date>` - Delete sessions last active before a date (ISO format, e.g. `2026-01-15`)
  - `--dry-run` - Preview what would be deleted
  - `--verbose/-v` - Show all related files that would be removed
  - Filters can be combined (e.g. `--project hubble --older-than 2w`)
- **`cleanup`** - Find short, small, or old sessions that are cleanup candidates
  - `--max-messages <N>` - Flag sessions with N or fewer messages (default: 4)
  - `--max-size <KB>` - Flag sessions smaller than KB (default: 10)
  - `--older-than <age>` - Also flag sessions older than age (e.g. `7d`, `2w`, `1m`)
  - `--project/-p <filter>` - Only check sessions matching project path substring
  - `--delete` - Delete the matched sessions (combine with `--dry-run` to preview)
  - `--dry-run` - Preview deletions without removing files
  - Without `--delete`, just lists candidates with reasons
- **`stats`** - Show overall session statistics by project

## Instructions

1. Parse the user's `$ARGUMENTS` to determine what they want to do. If no arguments or unclear, start with `stats` to show an overview, then ask what they'd like to do.
2. For **delete and cleanup --delete operations**, always do a `--dry-run` first and show the user what will be deleted. Only proceed with actual deletion after user confirmation.
3. When listing sessions, present them in a readable format. Offer to filter or show more if needed.
4. The current session ID is `${CLAUDE_SESSION_ID}` - warn the user if they try to delete the current session.
5. When the user seems to be looking for a session to resume, or after showing session details, suggest they can resume it with `/resume <session-id>` (the built-in resume command). They can also use `claude --resume <session-id>` from the terminal.
