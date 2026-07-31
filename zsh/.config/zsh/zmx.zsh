#!/usr/bin/env zsh

# zmx rejects label values containing anything outside [a-zA-Z0-9-_.] and prints
# the error into the terminal, so anything derived from a path or a command name
# has to be folded into that charset first. '/' is among the rejected
# characters, which is why paths end up separator-substituted rather than intact.
_zmx_label_safe() {
  print -r -- "${1//[^a-zA-Z0-9_.-]/-}"
}

# Home is marked with '_' because '~' is itself rejected. This has to happen
# before the separators are folded, while the string still looks like a path.
_zmx_session_update_cwd() {
  if [[ -z $ZMX_SESSION ]]; then
    return 0
  fi

  local cwd=$PWD
  if [[ $cwd == $HOME || $cwd == $HOME/* ]]; then
    cwd=_${cwd#$HOME}
  fi

  zmx set $ZMX_SESSION "CWD=$(_zmx_label_safe $cwd)"
}

_zmx_session_update_prog() {
  if [[ -z $ZMX_SESSION ]]; then
    return 0
  fi

  local cmd=${${1%% *}:t}

  # zmx attach/run spawns a nested session; PROG belongs to that one, not this.
  if [[ $cmd == zmx ]]; then
    return 0
  fi

  _zmx_prog_set=1
  zmx set $ZMX_SESSION "PROG=$(_zmx_label_safe $cmd)"
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

# chpwd and preexec only fire on a change, so a session stays unlabelled until
# its first cd or command. Labels also outlive the shell that set them, so a
# reused session name can inherit a stale PROG that precmd won't clear (its
# guard starts unset in a new shell). Seed CWD and clear PROG on startup.
if [[ -n $ZMX_SESSION ]]; then
  _zmx_session_update_cwd
  _zmx_prog_set=1
  _zmx_session_clear_prog
fi
