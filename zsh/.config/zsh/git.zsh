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

_gitLogLineToHash() {
  echo $1 | grep -o '[a-f0-9]\{7\}' | head -1
}

_viewGitLogLine() {
  git show --color=always $1 | diff-so-fancy
}

# gco - checkout git branch (including remote branches), sorted by most recent commit, limit 30 last branches
unalias gco
gco() {
  if [ $# -ne 0 ]; then
    git checkout "$@"
    return $?
  fi
  local branches branch
  branches=$(git for-each-ref --count=30 --sort=-committerdate refs/heads/ --format="%(refname:short)") &&
    echo "$branches" |
    fzf --no-sort --reverse --tiebreak=index --no-multi --ansi \
      --preview='_viewGitLogLine {}' \
      --header "enter to checkout, ctrl-e to view, ctrl-y to copy, ctrl-p to print -- branch" \
      --bind 'enter:become(echo {} | sed "s/.* //" | sed "s#remotes/[^/]*/##" | xargs git checkout)' \
      --bind 'ctrl-e:execute(_viewGitLogLine $(_gitLogLineToHash {}) | less -R)' \
      --bind 'ctrl-y:become(echo {} | pbcopy)' \
      --bind 'ctrl-p:accept'
}

# fcs - find git commit
fcs() {
  local commits commit
  commits=$(git log --color=always --pretty=oneline --decorate --abbrev-commit) &&
    echo "$commits" |
    fzf --no-sort --reverse --tiebreak=index --no-multi --ansi \
      --preview='_viewGitLogLine "$(_gitLogLineToHash {})"' \
      --header "enter to print, ctrl-y to copy, ctrl-v to view -- hash" \
      --bind 'enter:become(_gitLogLineToHash {})' \
      --bind 'ctrl-y:become(_gitLogLineToHash {} | pbcopy)' \
      --bind 'ctrl-v:execute(_viewGitLogLine $(_gitLogLineToHash {}) | less -R)'
}

# gshow - git commit browser with previews
gshow() {
  glNoGraph |
    fzf --no-sort --reverse --tiebreak=index --no-multi --ansi \
      --preview='_viewGitLogLine "$(_gitLogLineToHash {})"' \
      --header "enter to view, ctrl-y to copy, ctrl-p to print, ctrl-v to checkout -- hash" \
      --bind 'enter:execute(_viewGitLogLine $(_gitLogLineToHash {}) | less -R)' \
      --bind 'ctrl-y:become(_gitLogLineToHash {} | pbcopy)' \
      --bind 'ctrl-p:become(_gitLogLineToHash {})' \
      --bind 'ctrl-v:execute(_gitLogLineToHash {} | xargs git checkout)'
}
