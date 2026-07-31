#!/usr/bin/env zsh

_zmx_session_update_cwd() {
  if [[ -z $ZMX_SESSION ]]; then
    return 0
  fi

  SANITIZED_PWD="${PWD//\//-}"
  # Handle tilde too
  SANITIZED_PWD="${SANITIZED_PWD/#$HOME/~}"

  zmx set $ZMX_SESSION "CWD=$SANITIZED_PWD"
}

_zmx_session_update_prog() {
  if [[ -z $ZMX_SESSION ]]; then
    return 0
  fi

  # Basename of the command word: zmx labels reject '/', and a rejected label
  # prints an error into the terminal.
  local cmd=${${1%% *}:t}

  # zmx attach/run spawns a nested session; PROG belongs to that one, not this.
  if [[ $cmd == zmx ]]; then
    return 0
  fi

  _zmx_prog_set=1
  zmx set $ZMX_SESSION PROG="$cmd"
}

# PROG describes what's running right now, so drop it once we're back at the prompt.
_zmx_session_clear_prog() {
  if [[ -z $ZMX_SESSION || -z $_zmx_prog_set ]]; then
    return 0
  fi

  _zmx_prog_set=
  zmx set $ZMX_SESSION PROG=
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _zmx_session_update_cwd
add-zsh-hook preexec _zmx_session_update_prog
add-zsh-hook precmd _zmx_session_clear_prog
