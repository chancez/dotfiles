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
    # Use parameter substitution to replace 'head' with 'HEAD' in the argument
    corrected_arg="${arg//head/HEAD}"
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

git() {
  correct_git_commands "$@"
}

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
unalias gco
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
