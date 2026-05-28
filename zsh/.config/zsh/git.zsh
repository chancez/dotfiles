#!/usr/bin/env zsh

correct_git_commands() {
  local final_command=()
  local changes_made=false
  for arg in "$@"; do
    # if arg starts with refs/heads or if it's a path then we don't need to modify it
    if [[ "$arg" == refs/heads/* || "$arg" == */head* ]]; then
      final_command+=("$arg")
      continue
    fi
    # Replace 'head' with 'HEAD' only when it's a standalone ref, not inside words like 'ahead'
    corrected_arg=$(printf '%s' "$arg" | sed -E 's/(^|[^a-zA-Z0-9_])head($|[^a-zA-Z0-9_])/\1HEAD\2/g')
    final_command+=("$corrected_arg")
    if [[ "$corrected_arg" != "$arg" ]]; then
      changes_made=true
    fi
  done
  if $changes_made; then
    echo "Executing corrected command: git ${final_command[*]}"
  fi
  command git "${final_command[@]}"
}

__wrap_git() {
  correct_git_commands "$@"
}

alias git='noglob __wrap_git'
compdef __wrap_git=git

git-prune-branches-list() {
  git fetch --prune && (
    git branch -vv | grep -F ": gone]" | awk '{print $1}'
  )
}

git-prune-branches-dry() {
  git-prune-branches-list | xargs echo git branch -D
}

git-prune-branches() {
  git-prune-branches-list | xargs git branch -D
}

# gco - checkout git branch
gco() {
  if [ $# -ne 0 ]; then
    git checkout "$@"
    return $?
  fi
  local branch="$(_fzf_git_branches)"
  if [ -z "$branch" ]; then
    echo "No branch selected"
    return 1
  fi
  git checkout "$branch"
}
