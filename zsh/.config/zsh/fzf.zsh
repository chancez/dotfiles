#!/usr/bin/env zsh

# Set FZF options before loading fzf plugin
export FZF_DEFAULT_COMMAND='rg --files'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
# adds previews to completion
export FZF_CTRL_T_OPTS="--preview '(highlight -O ansi -l {} 2> /dev/null || cat {} || tree -C {}) 2> /dev/null | head -200'"
export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window down:3:hidden:wrap --bind '?:toggle-preview'"
export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"

# ** completion uses fzf's built-in walker unless these exist, and the walker
# ignores .fdignore/.rgignore.
_fzf_compgen_path() {
  fd --hidden --follow --exclude .git . "$1"
}

_fzf_compgen_dir() {
  fd --type d --hidden --follow --exclude .git . "$1"
}

# Custom fuzzy completion for "git" command
_fzf_complete_git() {
  local cmd=$1
  case "${${(z)cmd}[2]}" in
    # Function usage from: https://github.com/junegunn/fzf-git.sh
    add|rm|reset|restore) LBUFFER="${cmd}$(_fzf_git_files | __fzf_git_join)";;
    # rebase|checkout|switch) LBUFFER="${cmd}$(_fzf_git_branches)";;
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
