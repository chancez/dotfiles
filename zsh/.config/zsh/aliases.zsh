#!/usr/bin/env zsh

alias gst='git status'
alias gd='git diff'
alias gb='git branch'
alias gdc='git diff --cached'
alias gc='git commit'
alias gcv='git commit --verbose'
alias ga='git add'
alias rm='rm -i'
alias grc='git rebase --continue'

if (($+commands[nvim])); then
  alias vim='nvim'
fi

alias k=kubectl
if (($+commands[kubecolor])); then
  alias kubectl="kubecolor"
  compdef kubecolor=kubectl
fi
alias kc='switch'
alias kns='switch namespace'
alias tf=terraform

# we disable autocd so this is an alternative for common path changes
alias ~='cd ~'
alias ..='cd ..'
alias ../..='cd ../..'

alias ls='ls --color=auto'
alias grep='grep --color=auto'

# time aliases
alias zur='TZ=Europe/Zurich date'
alias pst='TZ=Etc/GMT-8 date'
alias est='TZ=Etc/GMT-5 date'
alias utc='TZ=Etc/UTC date'
alias cppwd="pwd | tee /dev/stderr | tr -d '\n' | pbcopy"

if [[ -e "/Applications/Tailscale.app/Contents/MacOS/Tailscale" ]]; then
  alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
fi

alias m4b-tool='docker run -it --rm -u $(id -u):$(id -g) -v "$(pwd)":/mnt sandreas/m4b-tool:latest'

# https://sw.kovidgoyal.net/kitty/faq/#i-get-errors-about-the-terminal-being-unknown-or-opening-the-terminal-failing-when-sshing-into-a-different-computer
if (( $+commands[kitty] )); then
  alias kittyssh="kitty +kitten ssh"
fi

nvim() {
  local no_session=false
  local args=()

  # Parse arguments
  for arg in "$@"; do
    case "$arg" in
      --no-session|--nosession)
        no_session=true
        ;;
      *)
        args+=("$arg")
        ;;
    esac
  done

  if "$no_session"; then
     args+=(--cmd "let g:auto_session_enabled = v:false")
  fi

  command nvim "${args[@]}"
}

if (( $+commands[switcher] )); then
  alias s=switch
fi
