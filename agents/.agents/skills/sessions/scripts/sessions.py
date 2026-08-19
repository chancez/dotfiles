#!/usr/bin/env python3
"""Claude Code session manager - list, inspect, and delete sessions."""

import argparse
import json
import os
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

CLAUDE_DIR = Path.home() / ".claude"
PROJECTS_DIR = CLAUDE_DIR / "projects"
DEBUG_DIR = CLAUDE_DIR / "debug"
FILE_HISTORY_DIR = CLAUDE_DIR / "file-history"
TODOS_DIR = CLAUDE_DIR / "todos"


def decode_project_path(encoded: str) -> str:
    """Convert encoded project dir name back to a readable path.

    Encoding replaces both '/' and '.' with '-', so decoding is lossy.
    We reconstruct the path by trying each '-' as either '/' or '.',
    preferring real filesystem paths.
    """
    # Brute force is too expensive, so we use a greedy approach:
    # Walk through the encoded string building the path segment by segment.
    # At each '-', try: keep building current segment, or split as '/', or split as '.'
    # We prefer the interpretation that matches an existing directory.
    chars = list(encoded.lstrip("-"))
    # Start with /
    return _decode_recursive("/" , chars, 0)


def _decode_recursive(built: str, chars: list, idx: int) -> str:
    """Recursively try to decode the path."""
    if idx >= len(chars):
        return built

    if chars[idx] == "-":
        # Try three interpretations in order of likelihood:
        # 1. '/' separator (most common)
        # 2. '.' for dot-prefixed dirs
        # 3. literal '-' in directory name
        candidates = []

        # Try '/' - check if current built path is a valid dir
        path_slash = built + "/"
        result_slash = _decode_recursive(path_slash, chars, idx + 1)
        if os.path.isdir(result_slash) or os.path.isdir(os.path.dirname(result_slash)):
            candidates.append(("slash", result_slash))

        # Try '.'
        path_dot = built + "."
        result_dot = _decode_recursive(path_dot, chars, idx + 1)
        if os.path.isdir(result_dot) or os.path.isdir(os.path.dirname(result_dot)):
            candidates.append(("dot", result_dot))

        # Try literal '-'
        path_dash = built + "-"
        result_dash = _decode_recursive(path_dash, chars, idx + 1)
        if os.path.isdir(result_dash) or os.path.isdir(os.path.dirname(result_dash)):
            candidates.append(("dash", result_dash))

        # Prefer the longest existing path
        for _, c in candidates:
            if os.path.isdir(c):
                return c

        # If none fully exist, prefer slash
        if candidates:
            return candidates[0][1]
        return _decode_recursive(built + "/", chars, idx + 1)
    else:
        return _decode_recursive(built + chars[idx], chars, idx + 1)


def get_session_summary(session_path: Path) -> dict | None:
    """Extract summary info from a session JSONL file."""
    session_id = session_path.stem
    first_user_msg = None
    first_timestamp = None
    last_timestamp = None
    message_count = 0

    try:
        with open(session_path) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue

                ts = obj.get("timestamp")

                if obj.get("type") == "user":
                    message_count += 1
                    if first_user_msg is None:
                        content = obj.get("message", {}).get("content", "")
                        if isinstance(content, str):
                            raw = content
                        elif isinstance(content, list):
                            raw = ""
                            for part in content:
                                if isinstance(part, dict) and part.get("type") == "text":
                                    raw = part["text"]
                                    break
                        else:
                            raw = ""
                        cleaned = clean_message_text(raw)
                        if cleaned:
                            first_user_msg = cleaned[:120]
                        if ts:
                            first_timestamp = ts
                elif obj.get("type") == "assistant":
                    message_count += 1

                if ts:
                    last_timestamp = ts

    except (OSError, PermissionError):
        return None

    if first_user_msg is None:
        return None

    return {
        "session_id": session_id,
        "path": session_path,
        "first_message": first_user_msg,
        "first_timestamp": first_timestamp,
        "last_timestamp": last_timestamp,
        "message_count": message_count,
        "size_bytes": session_path.stat().st_size,
    }


def list_sessions(project_filter: str | None = None, limit: int = 20):
    """List sessions across all projects."""
    if not PROJECTS_DIR.exists():
        print("No sessions found.")
        return

    sessions = []
    for project_dir in sorted(PROJECTS_DIR.iterdir()):
        if not project_dir.is_dir():
            continue
        project_path = decode_project_path(project_dir.name)
        if project_filter and project_filter.lower() not in project_path.lower():
            continue

        for session_file in project_dir.glob("*.jsonl"):
            summary = get_session_summary(session_file)
            if summary:
                summary["project"] = project_path
                summary["project_dir"] = project_dir.name
                sessions.append(summary)

    # Sort by last activity, most recent first
    sessions.sort(key=lambda s: s.get("last_timestamp") or "", reverse=True)

    if not sessions:
        print("No sessions found.")
        return

    if limit > 0:
        sessions = sessions[:limit]

    print(f"Found {len(sessions)} session(s):\n")
    for s in sessions:
        ts = s.get("first_timestamp", "unknown")
        if ts and ts != "unknown":
            try:
                dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                ts = dt.strftime("%Y-%m-%d %H:%M")
            except (ValueError, TypeError):
                pass
        last_ts = s.get("last_timestamp", "")
        if last_ts:
            try:
                dt = datetime.fromisoformat(last_ts.replace("Z", "+00:00"))
                last_ts = dt.strftime("%Y-%m-%d %H:%M")
            except (ValueError, TypeError):
                pass
        size_kb = s["size_bytes"] / 1024
        print(f"  Session: {s['session_id']}")
        print(f"  Project: {s['project']}")
        print(f"  Started: {ts}  Last active: {last_ts}")
        print(f"  Messages: {s['message_count']}  Size: {size_kb:.0f} KB")
        desc = s['first_message']
        if len(desc) > 100:
            desc = desc[:100] + "..."
        print(f"  Description: {desc}")
        print()


def find_session(session_id: str) -> tuple[Path | None, str | None]:
    """Find a session file by ID (supports prefix match)."""
    if not PROJECTS_DIR.exists():
        return None, None
    for project_dir in PROJECTS_DIR.iterdir():
        if not project_dir.is_dir():
            continue
        for session_file in project_dir.glob("*.jsonl"):
            if session_file.stem == session_id or session_file.stem.startswith(session_id):
                return session_file, project_dir.name
    return None, None


def clean_message_text(text: str) -> str:
    """Strip XML tags, leading whitespace, and other noise from message text."""
    # Remove XML/HTML-style tags and their content for known noise tags
    text = re.sub(r"<(?:local-command-caveat|environment_info|system-reminder)[^>]*>.*?</(?:local-command-caveat|environment_info|system-reminder)>", "", text, flags=re.DOTALL)
    # Remove any remaining XML-style tags
    text = re.sub(r"<[^>]+>", "", text)
    # Collapse whitespace
    text = re.sub(r"\s+", " ", text).strip()
    return text


def extract_message_text(obj: dict) -> str | None:
    """Extract text content from a user or assistant message."""
    msg = obj.get("message", {})
    content = msg.get("content", "")
    if isinstance(content, str):
        return content if content else None
    if isinstance(content, list):
        texts = []
        for part in content:
            if isinstance(part, dict) and part.get("type") == "text":
                texts.append(part["text"])
        return "\n".join(texts) if texts else None
    return None


def format_timestamp(ts: str) -> str:
    """Format an ISO timestamp to a readable string."""
    try:
        dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
        return dt.strftime("%Y-%m-%d %H:%M:%S")
    except (ValueError, TypeError):
        return ts


def show_session(session_id: str, tail: int = 10):
    """Show detailed info about a session."""
    session_file, project_dir_name = find_session(session_id)
    if not session_file:
        print(f"Session not found: {session_id}")
        sys.exit(1)

    full_id = session_file.stem
    project_path = decode_project_path(project_dir_name) if project_dir_name else "unknown"

    # Parse all messages
    messages = []
    first_user_msg = None
    model = None
    git_branch = None
    version = None

    try:
        with open(session_file) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue

                msg_type = obj.get("type")
                if msg_type not in ("user", "assistant"):
                    continue

                text = extract_message_text(obj)
                if text is None:
                    continue

                ts = obj.get("timestamp", "")
                entry = {
                    "type": msg_type,
                    "timestamp": ts,
                    "text": text,
                }

                if msg_type == "user":
                    if first_user_msg is None:
                        first_user_msg = text
                    if not git_branch:
                        git_branch = obj.get("gitBranch")
                    if not version:
                        version = obj.get("version")

                if msg_type == "assistant":
                    m = obj.get("message", {}).get("model")
                    if m:
                        model = m

                messages.append(entry)
    except (OSError, PermissionError) as e:
        print(f"Error reading session: {e}")
        sys.exit(1)

    size_kb = session_file.stat().st_size / 1024
    user_count = sum(1 for m in messages if m["type"] == "user")
    assistant_count = sum(1 for m in messages if m["type"] == "assistant")

    # Header
    print(f"Session: {full_id}")
    print(f"Project: {project_path}")
    if git_branch:
        print(f"Branch:  {git_branch}")
    if model:
        print(f"Model:   {model}")
    if version:
        print(f"Version: {version}")
    if messages:
        print(f"Started: {format_timestamp(messages[0]['timestamp'])}")
        print(f"Last:    {format_timestamp(messages[-1]['timestamp'])}")
    print(f"Messages: {user_count} user, {assistant_count} assistant ({size_kb:.0f} KB)")
    print()

    # Original prompt
    if first_user_msg:
        print("--- Original prompt ---")
        # Show up to 500 chars of the first message
        display = first_user_msg[:500]
        if len(first_user_msg) > 500:
            display += f"\n... ({len(first_user_msg)} chars total)"
        print(display)
        print()

    # Recent messages
    if messages:
        recent = messages[-tail:]
        if len(messages) > tail:
            print(f"--- Last {tail} messages (of {len(messages)} total) ---")
        else:
            print(f"--- All {len(messages)} messages ---")

        for msg in recent:
            role = "USER" if msg["type"] == "user" else "ASSISTANT"
            ts = format_timestamp(msg["timestamp"]) if msg["timestamp"] else ""
            # Truncate long messages for readability
            text = msg["text"]
            if len(text) > 300:
                text = text[:300] + f"... ({len(msg['text'])} chars)"
            print(f"\n[{role}] {ts}")
            print(text)


def collect_session_artifacts(session_file: Path) -> tuple[list[Path], list[Path]]:
    """Collect all files and directories related to a session."""
    full_id = session_file.stem
    files = [session_file]
    dirs = []

    subagent_dir = session_file.parent / full_id
    if subagent_dir.is_dir():
        dirs.append(subagent_dir)

    debug_file = DEBUG_DIR / f"{full_id}.txt"
    if debug_file.exists():
        files.append(debug_file)

    fh_dir = FILE_HISTORY_DIR / full_id
    if fh_dir.is_dir():
        dirs.append(fh_dir)

    if TODOS_DIR.exists():
        for todo_file in TODOS_DIR.glob(f"{full_id}*.json"):
            files.append(todo_file)

    return files, dirs


def remove_session(session_file: Path, dry_run: bool = False, verbose: bool = False) -> int:
    """Remove a single session and its artifacts. Returns bytes freed."""
    files, dirs = collect_session_artifacts(session_file)
    size = sum(f.stat().st_size for f in files if f.exists())
    size += sum(
        sum(ff.stat().st_size for ff in d.rglob("*") if ff.is_file())
        for d in dirs if d.exists()
    )

    if verbose:
        action = "Would delete" if dry_run else "Deleting"
        print(f"  {action}: {session_file.stem}")
        for f in files[1:]:  # skip the session file itself
            print(f"    + {f}")
        for d in dirs:
            print(f"    + {d}/")

    if not dry_run:
        for f in files:
            f.unlink(missing_ok=True)
        for d in dirs:
            shutil.rmtree(d, ignore_errors=True)

    return size


def parse_age(age_str: str) -> datetime:
    """Parse a relative age string like '7d', '2w', '1m' into a cutoff datetime."""
    units = {"h": "hours", "d": "days", "w": "weeks"}
    match = re.match(r"^(\d+)([hdwm])$", age_str)
    if not match:
        print(f"Invalid age format: '{age_str}'. Use e.g. 12h, 7d, 2w, or 1m.")
        sys.exit(1)

    amount = int(match.group(1))
    unit = match.group(2)

    now = datetime.now(timezone.utc)
    if unit == "m":
        # Approximate months as 30 days
        from datetime import timedelta
        return now - timedelta(days=amount * 30)
    else:
        from datetime import timedelta
        return now - timedelta(**{units[unit]: amount})


def get_last_timestamp(session_path: Path) -> str | None:
    """Get the last timestamp from a session file (read from end for speed)."""
    last_ts = None
    try:
        with open(session_path) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                ts = obj.get("timestamp")
                if ts:
                    last_ts = ts
    except (OSError, PermissionError):
        pass
    return last_ts


def resolve_sessions_to_delete(
    session_ids: list[str],
    project_filter: str | None,
    older_than: str | None,
    before: str | None,
) -> list[Path]:
    """Resolve deletion criteria into a list of session file paths."""
    if not PROJECTS_DIR.exists():
        return []

    # If explicit session IDs given, resolve them directly
    if session_ids:
        results = []
        for sid in session_ids:
            session_file, _ = find_session(sid)
            if session_file:
                results.append(session_file)
            else:
                print(f"Warning: session not found: {sid}")
        return results

    # Otherwise, filter by project / age / date
    cutoff = None
    if older_than:
        cutoff = parse_age(older_than)
    elif before:
        try:
            cutoff = datetime.fromisoformat(before).replace(tzinfo=timezone.utc)
        except ValueError:
            print(f"Invalid date format: '{before}'. Use ISO format, e.g. 2026-01-15.")
            sys.exit(1)

    if not project_filter and not cutoff:
        print("Error: bulk delete requires at least one filter (--project, --older-than, or --before).")
        print("To delete a specific session, pass its ID as an argument.")
        sys.exit(1)

    results = []
    for project_dir in PROJECTS_DIR.iterdir():
        if not project_dir.is_dir():
            continue
        if project_filter:
            project_path = decode_project_path(project_dir.name)
            if project_filter.lower() not in project_path.lower():
                continue

        for session_file in project_dir.glob("*.jsonl"):
            if cutoff:
                last_ts = get_last_timestamp(session_file)
                if not last_ts:
                    continue
                try:
                    session_dt = datetime.fromisoformat(last_ts.replace("Z", "+00:00"))
                except (ValueError, TypeError):
                    continue
                if session_dt >= cutoff:
                    continue
            results.append(session_file)

    return results


def delete_sessions(
    session_ids: list[str],
    project_filter: str | None = None,
    older_than: str | None = None,
    before: str | None = None,
    dry_run: bool = False,
    verbose: bool = False,
):
    """Delete sessions matching the given criteria."""
    targets = resolve_sessions_to_delete(session_ids, project_filter, older_than, before)

    if not targets:
        print("No sessions matched the given criteria.")
        return

    action = "Would delete" if dry_run else "Deleting"
    print(f"{action} {len(targets)} session(s):\n")

    total_freed = 0
    for sf in targets:
        project_name = decode_project_path(sf.parent.name)
        summary = get_session_summary(sf)
        desc = ""
        if summary:
            desc = summary["first_message"]
            if len(desc) > 80:
                desc = desc[:80] + "..."
        print(f"  {sf.stem[:8]}..  {project_name}")
        if desc:
            print(f"             {desc}")
        total_freed += remove_session(sf, dry_run=dry_run, verbose=verbose)

    print(f"\n{action}: {len(targets)} session(s), {total_freed / 1024:.0f} KB {'would be ' if dry_run else ''}freed.")


def cleanup(
    max_messages: int = 4,
    max_size_kb: int = 10,
    older_than: str | None = None,
    project_filter: str | None = None,
    delete: bool = False,
    dry_run: bool = False,
):
    """Find short/small/old sessions that look like cleanup candidates."""
    if not PROJECTS_DIR.exists():
        print("No sessions found.")
        return

    cutoff = parse_age(older_than) if older_than else None

    candidates = []
    total_sessions = 0

    for project_dir in PROJECTS_DIR.iterdir():
        if not project_dir.is_dir():
            continue
        project_path = decode_project_path(project_dir.name)
        if project_filter and project_filter.lower() not in project_path.lower():
            continue

        for session_file in project_dir.glob("*.jsonl"):
            total_sessions += 1
            summary = get_session_summary(session_file)
            if not summary:
                # Sessions with no parseable user messages are candidates
                candidates.append({
                    "session_id": session_file.stem,
                    "path": session_file,
                    "project": project_path,
                    "first_message": "(no user messages)",
                    "message_count": 0,
                    "size_bytes": session_file.stat().st_size,
                    "last_timestamp": None,
                    "reasons": ["empty"],
                })
                continue

            summary["project"] = project_path
            reasons = []

            # Check message count
            if summary["message_count"] <= max_messages:
                reasons.append(f"{summary['message_count']} msgs")

            # Check size
            size_kb = summary["size_bytes"] / 1024
            if size_kb <= max_size_kb:
                reasons.append(f"{size_kb:.0f} KB")

            # Check age
            if cutoff and summary.get("last_timestamp"):
                try:
                    session_dt = datetime.fromisoformat(
                        summary["last_timestamp"].replace("Z", "+00:00")
                    )
                    if session_dt < cutoff:
                        age_days = (datetime.now(timezone.utc) - session_dt).days
                        reasons.append(f"{age_days}d old")
                except (ValueError, TypeError):
                    pass

            if reasons:
                summary["reasons"] = reasons
                candidates.append(summary)

    if not candidates:
        print(f"No cleanup candidates found (checked {total_sessions} sessions).")
        return

    # Sort: emptiest/smallest first
    candidates.sort(key=lambda s: (s["message_count"], s["size_bytes"]))

    total_size = sum(c["size_bytes"] for c in candidates)
    print(f"Found {len(candidates)} cleanup candidate(s) out of {total_sessions} total sessions")
    print(f"Total reclaimable: {total_size / 1024:.0f} KB\n")

    for c in candidates:
        sid = c["session_id"][:8]
        project = c.get("project", "unknown")
        reasons = ", ".join(c["reasons"])
        desc = c.get("first_message", "")
        if len(desc) > 70:
            desc = desc[:70] + "..."
        print(f"  {sid}..  [{reasons}]  {project}")
        if desc:
            print(f"             {desc}")

    if delete:
        print()
        action = "Would delete" if dry_run else "Deleting"
        print(f"{action} {len(candidates)} session(s):\n")
        total_freed = 0
        for c in candidates:
            total_freed += remove_session(c["path"], dry_run=dry_run)
        print(f"{action}: {len(candidates)} session(s), {total_freed / 1024:.0f} KB {'would be ' if dry_run else ''}freed.")
    else:
        print(f"\nTo delete these, re-run with --delete (and --dry-run to preview).")


def stats():
    """Show overall session statistics."""
    if not PROJECTS_DIR.exists():
        print("No sessions found.")
        return

    total_sessions = 0
    total_size = 0
    projects = {}

    for project_dir in PROJECTS_DIR.iterdir():
        if not project_dir.is_dir():
            continue
        project_path = decode_project_path(project_dir.name)
        count = 0
        size = 0
        for sf in project_dir.glob("*.jsonl"):
            count += 1
            size += sf.stat().st_size
        if count > 0:
            projects[project_path] = {"count": count, "size": size}
            total_sessions += count
            total_size += size

    print(f"Total sessions: {total_sessions}")
    print(f"Total size: {total_size / 1024 / 1024:.1f} MB\n")
    print("By project:")
    for proj, info in sorted(projects.items(), key=lambda x: x[1]["size"], reverse=True):
        print(f"  {proj}: {info['count']} sessions, {info['size'] / 1024:.0f} KB")


def main():
    parser = argparse.ArgumentParser(description="Manage Claude Code sessions")
    sub = parser.add_subparsers(dest="command")

    ls = sub.add_parser("list", help="List sessions")
    ls.add_argument("--project", "-p", help="Filter by project path substring")
    ls.add_argument("--limit", "-n", type=int, default=20, help="Max sessions to show")

    show = sub.add_parser("show", help="Show detailed session info")
    show.add_argument("session_id", help="Session ID or prefix")
    show.add_argument("--tail", "-t", type=int, default=10, help="Number of recent messages to show (default: 10)")

    rm = sub.add_parser("delete", help="Delete sessions (by ID, project, or age)")
    rm.add_argument("session_ids", nargs="*", help="Session ID(s) or prefixes to delete")
    rm.add_argument("--project", "-p", help="Delete sessions matching project path substring")
    rm.add_argument("--older-than", help="Delete sessions older than age (e.g. 12h, 7d, 2w, 1m)")
    rm.add_argument("--before", help="Delete sessions last active before date (ISO format, e.g. 2026-01-15)")
    rm.add_argument("--dry-run", action="store_true", help="Show what would be deleted")
    rm.add_argument("--verbose", "-v", action="store_true", help="Show all files that would be removed")

    cl = sub.add_parser("cleanup", help="Find short/small/old sessions to clean up")
    cl.add_argument("--max-messages", type=int, default=4, help="Flag sessions with this many or fewer messages (default: 4)")
    cl.add_argument("--max-size", type=int, default=10, help="Flag sessions smaller than this many KB (default: 10)")
    cl.add_argument("--older-than", help="Also flag sessions older than age (e.g. 7d, 2w, 1m)")
    cl.add_argument("--project", "-p", help="Only check sessions matching project path substring")
    cl.add_argument("--delete", action="store_true", help="Delete the matched sessions (use with --dry-run to preview)")
    cl.add_argument("--dry-run", action="store_true", help="Preview deletions without removing files")

    sub.add_parser("stats", help="Show session statistics")

    args = parser.parse_args()

    if args.command == "list":
        list_sessions(project_filter=args.project, limit=args.limit)
    elif args.command == "show":
        show_session(args.session_id, tail=args.tail)
    elif args.command == "delete":
        delete_sessions(
            session_ids=args.session_ids,
            project_filter=args.project,
            older_than=args.older_than,
            before=args.before,
            dry_run=args.dry_run,
            verbose=args.verbose,
        )
    elif args.command == "cleanup":
        cleanup(
            max_messages=args.max_messages,
            max_size_kb=args.max_size,
            older_than=args.older_than,
            project_filter=args.project,
            delete=args.delete,
            dry_run=args.dry_run,
        )
    elif args.command == "stats":
        stats()
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
