#!/usr/bin/env zsh

# Set the terminal title to a shortened cwd plus the git branch.
# kitty's shell integration is started with no-title so it doesn't fight this.

# ~/projects/foo/bar/baz -> ~/p/f/b/baz
_title_shorten_path() {
  local -a parts=("${(@s:/:)1}")
  local i seg
  # Abbreviate every component except the last one.
  for (( i = 1; i < $#parts; i++ )); do
    seg=$parts[i]
    [[ -z $seg || $seg == '~' ]] && continue
    # Keep the dot on hidden dirs, otherwise they all collapse to '.'
    if [[ $seg == .* ]]; then
      parts[i]=${seg[1,2]}
    else
      parts[i]=${seg[1,1]}
    fi
  done
  print -r -- ${(j:/:)parts}
}

_title_git_branch() {
  local branch
  # symbolic-ref rather than describe: describe prefers a tag pointing at HEAD
  # over the branch name, which is not what we want in the title.
  branch=$(command git symbolic-ref --quiet --short HEAD 2>/dev/null) && {
    print -r -- $branch
    return 0
  }
  # Detached HEAD still has a useful short sha; non-repos print nothing.
  branch=$(command git rev-parse --short HEAD 2>/dev/null) && print -r -- $branch
}

# Written to /dev/tty rather than stdout, which is load-bearing rather than style.
#
# A title is a message to the terminal, so stdout is the wrong channel the moment stdout is
# something other than the terminal. TRAPWINCH below can fire while a command substitution is
# capturing, and then the escape sequence lands in the captured text instead of on screen. That
# broke `eval "$(...)"` callers with errors naming the title itself:
#
#   (eval):1: command not found: ^[]2
#   (eval):1: bad pattern: (pr/chancez/integrate_dex)^G
#
# eval split the OSC 2 payload at its own ';', so the branch name in the title became a command.
# /dev/tty makes that impossible for every path here, not just the one that was caught.
# 2>/dev/null because a shell with no controlling terminal has no title to set, and losing the
# title there beats an error on every prompt.
_title_set() {
  print -rn -- $'\e]2;'"${(V)1}"$'\a' > /dev/tty 2>/dev/null
}

_title_location() {
  local dir branch
  dir=$(_title_shorten_path ${(%):-%~})
  branch=$(_title_git_branch)
  if [[ -n $branch ]]; then
    print -r -- "$dir ($branch)"
  else
    print -r -- "$dir"
  fi
}

_title_precmd() {
  _title_set "$(_title_location)"
}

# While a command runs, lead with its name so the tab says what is executing.
_title_preexec() {
  # Assign to an array first: indexing a scalar expansion would take the first
  # character instead of the first word.
  local -a words=(${(z)3})
  local i=1
  # Skip leading VAR=value assignments and sudo/env wrappers.
  while (( i <= $#words )); do
    case $words[i] in
      (*=*) ;;
      (sudo|env) ;;
      (-*) ;;
      (*) break ;;
    esac
    (( i++ ))
  done
  local cmd=${words[i]:-$words[1]}
  _title_set "${cmd:t} $(_title_location)"
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _title_precmd
add-zsh-hook preexec _title_preexec

# The title only exists as an escape sequence the shell emitted, so anything
# that discards it needs the shell to say it again. Reattaching a session is the
# case that matters: no new shell runs, so precmd never fires and the window
# keeps the process name kitty falls back to. zsh runs this between commands
# only, so a foreground program's own title is left alone.
#
# cm re-emits OSC 2 as part of the screen it restores, so this is now a backstop
# rather than the only mechanism. Kept because it costs nothing and covers a
# session whose title changed while no client was attached.
#
# Guarded to the top-level shell. A trap is inherited by subshells, so without this every command
# substitution running when the window resized would fork a child that also rebuilt the title,
# which means two `git` calls per capture and, before _title_set wrote to /dev/tty, the sequence
# landing in the captured output.
#
# The guard is an `if` rather than the shorter `(( ZSH_SUBSHELL == 0 )) || return`, and that is the
# whole point of writing it out. A nonzero return from TRAPWINCH makes zsh abandon the command
# substitution it interrupted, so the caller silently captures the empty string. Measured all three
# forms: `|| return` and `|| return 1` both yield captured='', `|| return 0` and this `if` both
# yield the real output. An empty capture is worse than the bug being fixed, because it has no
# error message at all.
TRAPWINCH() {
  if (( ZSH_SUBSHELL == 0 )); then
    _title_precmd
  fi
}
