#!/usr/bin/env bash
# Claude Code status line — two-line display with context, git, and cost info.
# Receives JSON session data on stdin, outputs ANSI-colored lines to stdout.

set -euo pipefail

# --- Read and parse JSON from stdin ---
INPUT=$(cat)

MODEL=$(echo "$INPUT" | jq -r '.model.display_name // "?"')
CWD=$(echo "$INPUT" | jq -r '.workspace.current_dir // "~"')
PCT=$(echo "$INPUT" | jq -r '.context_window.used_percentage // 0')
CTX_SIZE=$(echo "$INPUT" | jq -r '.context_window.context_window_size // 200000')
USED_TOKENS=$((PCT * CTX_SIZE / 100))
COST=$(echo "$INPUT" | jq -r '.cost.total_cost_usd // 0')
DURATION_MS=$(echo "$INPUT" | jq -r '.cost.total_duration_ms // 0')

# Reserved compaction buffer (system_prompt_cap=20000 + compact_buffer=13000).
# These are hardcoded in Claude Code's binary. Override with env var if they change.
COMPACT_BUFFER=${CLAUDE_STATUSLINE_BUFFER:-33000}
AVAILABLE=$((CTX_SIZE - COMPACT_BUFFER))
[[ "$AVAILABLE" -lt 1 ]] && AVAILABLE=1

# Scale percentage so compaction threshold = 100%
ADJ_PCT=$((USED_TOKENS * 100 / AVAILABLE))
[[ "$ADJ_PCT" -gt 100 ]] && ADJ_PCT=100

# --- Shorten CWD (collapse $HOME to ~) ---
SHORT_CWD="${CWD/#$HOME/\~}"

# --- Terminal width for LINE1 truncation ---
TERM_WIDTH=${COLUMNS:-$(stty size 2>/dev/null </dev/tty | awk '{print $2}' || tput cols 2>/dev/null || echo 120)}
((TERM_WIDTH < 40)) && TERM_WIDTH=40

# --- Git info (cached for performance) ---
CACHE_FILE="/tmp/claude-statusline-git-cache"
CACHE_TTL=5
GIT_BRANCH=""
GIT_STAGED=0
GIT_MODIFIED=0
GIT_DETACHED=0
GIT_AHEAD=0
GIT_BEHIND=0
GIT_TOPLEVEL=""

get_git_info() {
  if [[ ! -d "$CWD" ]]; then
    return
  fi

  # Check cache freshness
  if [[ -f "$CACHE_FILE" ]]; then
    local -a lines
    mapfile -t lines <"$CACHE_FILE" 2>/dev/null
    local cache_dir="${lines[0]:-}"
    local cache_age=$(($(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)))
    if [[ "$cache_dir" == "$CWD" && "$cache_age" -lt "$CACHE_TTL" ]]; then
      GIT_BRANCH="${lines[1]:-}"
      GIT_STAGED="${lines[2]:-0}"
      GIT_MODIFIED="${lines[3]:-0}"
      GIT_DETACHED="${lines[4]:-0}"
      GIT_AHEAD="${lines[5]:-0}"
      GIT_BEHIND="${lines[6]:-0}"
      GIT_TOPLEVEL="${lines[7]:-}"
      return
    fi
  fi

  # Get fresh git info
  local branch staged modified
  if ! branch=$(git -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null); then
    return
  fi
  staged=$(git -C "$CWD" diff --cached --numstat 2>/dev/null | wc -l || echo 0)
  modified=$(git -C "$CWD" diff --numstat 2>/dev/null | wc -l || echo 0)
  local toplevel
  toplevel=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null) || true
  GIT_TOPLEVEL="${toplevel:-}"

  GIT_BRANCH="$branch"
  GIT_DETACHED=0
  if [[ "$GIT_BRANCH" == "HEAD" ]]; then
    GIT_BRANCH=$(git -C "$CWD" rev-parse --short=8 HEAD 2>/dev/null || echo "HEAD")
    GIT_DETACHED=1
  fi
  GIT_STAGED="$staged"
  GIT_MODIFIED="$modified"

  # Ahead/behind upstream
  local ahead_behind
  if ahead_behind=$(git -C "$CWD" rev-list --left-right --count HEAD...@{u} 2>/dev/null); then
    GIT_AHEAD=$(echo "$ahead_behind" | awk '{print $1}')
    GIT_BEHIND=$(echo "$ahead_behind" | awk '{print $2}')
  else
    GIT_AHEAD=0
    GIT_BEHIND=0
  fi

  # Write cache
  printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s' "$CWD" "$GIT_BRANCH" "$staged" "$modified" "$GIT_DETACHED" "$GIT_AHEAD" "$GIT_BEHIND" "$GIT_TOPLEVEL" \
    >"$CACHE_FILE" 2>/dev/null || true
}

get_git_info

# --- Detect worktree: use git toplevel to identify worktree root ---
WORKTREE_NAME=""
if [[ -n "$GIT_TOPLEVEL" && "$GIT_TOPLEVEL" == */.claude/worktrees/* ]]; then
  WORKTREE_NAME="${GIT_TOPLEVEL##*/.claude/worktrees/}"
  wt_project_root="${GIT_TOPLEVEL%%/.claude/worktrees/*}"
  wt_subdir="${CWD#"$GIT_TOPLEVEL"}"
  SHORT_CWD="${wt_project_root/#$HOME/\~}${wt_subdir}"
fi

# --- Format tokens as Xk ---
format_tokens() {
  local t=$1
  if [[ "$t" -ge 1000 ]]; then
    echo "$((t / 1000))k"
  else
    echo "$t"
  fi
}

DISPLAY_USED=$USED_TOKENS
[[ "$DISPLAY_USED" -gt "$AVAILABLE" ]] && DISPLAY_USED=$AVAILABLE
USED_FMT=$(format_tokens "$DISPLAY_USED")
SIZE_FMT=$(format_tokens "$AVAILABLE")

# --- Format duration ---
DURATION_S=$((DURATION_MS / 1000))
DURATION_D=$((DURATION_S / 86400))
DURATION_H=$(((DURATION_S % 86400) / 3600))
DURATION_M=$(((DURATION_S % 3600) / 60))
DURATION_RS=$((DURATION_S % 60))
DUR_FMT=""
[[ $DURATION_D -gt 0 ]] && DUR_FMT+="${DURATION_D}d "
[[ $DURATION_H -gt 0 ]] && DUR_FMT+="${DURATION_H}h "
[[ $DURATION_M -gt 0 ]] && DUR_FMT+="${DURATION_M}m "
DUR_FMT+="${DURATION_RS}s"

# --- Format cost ---
COST_FMT=$(printf '$%.2f' "$COST")

# --- Progress bar (20 chars) ---
BAR_WIDTH=20
FILLED=$(((ADJ_PCT * BAR_WIDTH + 50) / 100)) # round
[[ "$FILLED" -gt "$BAR_WIDTH" ]] && FILLED=$BAR_WIDTH
EMPTY=$((BAR_WIDTH - FILLED))

# Color by usage level
if [[ "$ADJ_PCT" -ge 90 ]]; then
  BAR_COLOR="\033[1;31m" # bold red
elif [[ "$ADJ_PCT" -ge 80 ]]; then
  BAR_COLOR="\033[31m" # red
elif [[ "$ADJ_PCT" -ge 60 ]]; then
  BAR_COLOR="\033[33m" # yellow
else
  BAR_COLOR="\033[32m" # green
fi
RESET="\033[0m"

BAR="${BAR_COLOR}"
for ((i = 0; i < FILLED; i++)); do BAR+="█"; done
BAR+="${RESET}"
for ((i = 0; i < EMPTY; i++)); do BAR+="░"; done

# --- Line 1: Model, Path, Git (with progressive truncation) ---

# Collapse intermediate path segments to first char (preserve leading dot).
# ~/ .local/share/chezmoi -> ~/.l/s/chezmoi
collapse_path() {
  local p="$1"
  [[ "$p" != */* ]] && printf '%s' "$p" && return
  local IFS='/'
  read -ra segs <<<"$p"
  local n=${#segs[@]}
  ((n <= 2)) && printf '%s' "$p" && return
  local out="${segs[0]}" i seg
  for ((i = 1; i < n - 1; i++)); do
    seg="${segs[$i]}"
    if [[ "$seg" == .* ]]; then
      out+="/${seg:0:2}"
    else
      out+="/${seg:0:1}"
    fi
  done
  out+="/${segs[$n - 1]}"
  printf '%s' "$out"
}

# Extract just the last path component (project root).
project_root() {
  printf '%s' "${1##*/}"
}

# Strip known branch prefixes: pr/<user>/, dontmerge/<user>/, backports/<user>/<ver>/
strip_branch_prefix() {
  local br="$1"
  if [[ "$br" =~ ^(pr|dontmerge)/[^/]+/(.+)$ ]]; then
    printf '%s' "${BASH_REMATCH[2]}"
  elif [[ "$br" =~ ^backports/[^/]+/[^/]+/(.+)$ ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  else
    printf '%s' "$br"
  fi
}

# Truncate string with ellipsis: keep prefix + … + suffix.
truncate_mid() {
  local s="$1" max="$2"
  ((${#s} <= max)) && printf '%s' "$s" && return
  ((max < 5)) && printf '%s' "${s:0:$((max - 1))}…" && return
  local avail=$((max - 1)) # 1 for …
  local pre=$((avail / 2))
  local suf=$((avail - pre))
  printf '%s' "${s:0:$pre}…${s: -$suf}"
}

# Build LINE1 with progressive collapse to fit TERM_WIDTH.
build_line1() {
  local model_w=$((${#MODEL} + 2)) # "[MODEL]"
  local fixed=$((model_w + 1))     # + space after model

  # Worktree indicator width (always shown if present): @name
  local wt_w=0
  [[ -n "$WORKTREE_NAME" ]] && wt_w=$((1 + ${#WORKTREE_NAME})) # @name

  # Git counts width
  local counts_w=0 counts_ansi=""
  if [[ $GIT_AHEAD -gt 0 ]]; then
    ((counts_w += 2 + ${#GIT_AHEAD})) # " ↑N"
    counts_ansi+=" \033[36m↑${GIT_AHEAD}\033[0m"
  fi
  if [[ $GIT_BEHIND -gt 0 ]]; then
    ((counts_w += 2 + ${#GIT_BEHIND})) # " ↓N"
    counts_ansi+=" \033[35m↓${GIT_BEHIND}\033[0m"
  fi
  if [[ $GIT_STAGED -gt 0 ]]; then
    ((counts_w += 2 + ${#GIT_STAGED})) # " +N"
    counts_ansi+=" \033[32m+${GIT_STAGED}\033[0m"
  fi
  if [[ $GIT_MODIFIED -gt 0 ]]; then
    ((counts_w += 2 + ${#GIT_MODIFIED})) # " ~N"
    counts_ansi+=" \033[33m~${GIT_MODIFIED}\033[0m"
  fi

  local has_git=0
  [[ -n "$GIT_BRANCH" ]] && has_git=1
  local sep_w=3 # " | "

  # Helper: compute total width for given path and branch strings
  calc_width() {
    local pw=${#1} bw=${#2} show_br=$3
    local total=$((fixed + pw + wt_w + counts_w))
    ((show_br)) && ((total += sep_w + bw))
    printf '%d' "$total"
  }

  local display_path="$SHORT_CWD"
  local display_branch="$GIT_BRANCH"
  local show_branch=$has_git

  # Level 0: full path, full branch
  local total
  total=$(calc_width "$display_path" "$display_branch" "$show_branch")
  if ((total <= TERM_WIDTH)); then
    :
  else
    # Level 1: collapse path
    display_path=$(collapse_path "$SHORT_CWD")
    total=$(calc_width "$display_path" "$display_branch" "$show_branch")

    if ((total <= TERM_WIDTH)); then
      :
    elif [[ $has_git -eq 1 ]]; then
      # Level 2: collapse path + strip branch prefix
      display_branch=$(strip_branch_prefix "$GIT_BRANCH")
      total=$(calc_width "$display_path" "$display_branch" "$show_branch")

      if ((total <= TERM_WIDTH)); then
        :
      else
        # Level 3: project root only + stripped branch
        display_path=$(project_root "$SHORT_CWD")
        total=$(calc_width "$display_path" "$display_branch" "$show_branch")

        if ((total <= TERM_WIDTH)); then
          :
        else
          # Level 4: project root + truncate branch (last resort)
          local branch_budget=$((TERM_WIDTH - fixed - ${#display_path} - wt_w - sep_w - counts_w))
          if ((branch_budget >= 5)); then
            display_branch=$(truncate_mid "$display_branch" "$branch_budget")
          elif ((branch_budget >= 1)); then
            display_branch="${display_branch:0:$((branch_budget - 1))}…"
          else
            show_branch=0
          fi
        fi
      fi
    else
      # No git: project root only
      display_path=$(project_root "$SHORT_CWD")
      local path_budget=$((TERM_WIDTH - fixed - wt_w))
      if ((${#display_path} > path_budget)); then
        ((path_budget < 3)) && path_budget=3
        display_path="${display_path:0:$((path_budget - 1))}…"
      fi
    fi
  fi

  # Assemble with ANSI codes
  # Dim parent path segments, keep final segment (project root) normal
  local path_ansi
  if [[ "$display_path" == */* ]]; then
    local path_prefix="${display_path%/*}/"
    local path_last="${display_path##*/}"
    path_ansi="\033[90m${path_prefix}\033[0m${path_last}"
  else
    path_ansi="$display_path"
  fi
  LINE1="\033[1m[${MODEL}]\033[0m ${path_ansi}"
  if [[ -n "$WORKTREE_NAME" ]]; then
    LINE1+="\033[36m@${WORKTREE_NAME}\033[0m"
  fi
  if [[ $show_branch -eq 1 && -n "$display_branch" ]]; then
    local branch_color=34                        # blue
    [[ $GIT_DETACHED -eq 1 ]] && branch_color=31 # red
    LINE1+=" | \033[${branch_color}m${display_branch}\033[0m"
  fi
  LINE1+="${counts_ansi}"
}

build_line1

# --- Line 2: Progress bar, tokens, cost, duration ---
LINE2="${BAR} ${BAR_COLOR}${ADJ_PCT}%${RESET} (${USED_FMT}/${SIZE_FMT}) | ${COST_FMT} | ${DUR_FMT}"

# --- Output ---
echo -e "$LINE1"
echo -e "$LINE2"
