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

_title_set() {
  print -rn -- $'\e]2;'"${(V)1}"$'\a'
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
# that discards it needs the shell to say it again. Reattaching a zmx session is
# the case that matters: no new shell runs, so precmd never fires and the window
# keeps the process name kitty falls back to. zsh runs this between commands
# only, so a foreground program's own title is left alone.
TRAPWINCH() {
  _title_precmd
}
