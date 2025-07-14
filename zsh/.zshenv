#!/usr/bin/env zsh

alias glNoGraph='git log --color=always --format="%C(auto)%h%d %s %C(black)%C(bold)%cr% C(auto)%an" "$@"'

_gitLogLineToHash() {
  echo $1 | grep -o '[a-f0-9]\{7\}' | head -1
}

_viewGitLogLine() {
  git show --color=always $1 | diff-so-fancy
}


if [ -f "$HOME/.zshenv_secrets" ]; then
  source "$HOME/.zshenv_secrets"
fi
