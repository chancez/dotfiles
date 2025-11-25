#!/usr/bin/env zsh

# Set FZF options before loading fzf plugin
export FZF_DEFAULT_COMMAND='rg --files'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
# adds previews to completion
export FZF_CTRL_T_OPTS="--preview '(highlight -O ansi -l {} 2> /dev/null || cat {} || tree -C {}) 2> /dev/null | head -200'"
export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window down:3:hidden:wrap --bind '?:toggle-preview'"
export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"

_args_index() {
  local needle=$1
  shift
  local index=0
  for arg in "$@"; do
    (( index++ ))
    if [[ "$arg" == "$needle"* ]]; then
      echo $index
      return 0
    fi
  done
  return 1
}

_args_contains() {
  local needle=$1
  shift
  # Ignore the index output
  _args_index "$needle" "$@" >/dev/null
}

# Custom fuzzy completion for "git" command
_fzf_complete_git() {
  local cmd=$1
  case "${${(z)cmd}[2]}" in
    # Function usage from: https://github.com/junegunn/fzf-git.sh
    add|rm|reset|restore) LBUFFER="${cmd}$(_fzf_git_files | __fzf_git_join)";;
    rebase|checkout|switch) LBUFFER="${cmd}$(_fzf_git_branches)";;
    *) _fzf_path_completion "$prefix" "$@";;
  esac
}

_fzf_complete_gco() {
  shift
  _fzf_complete_git "git checkout $@"
}

# fzf based cd without args
cd() {
  if [[ "$#" != 0 ]]; then
      builtin cd "$@";
      return
  fi
  cd "$(jump top | fzf --reverse)"
}
