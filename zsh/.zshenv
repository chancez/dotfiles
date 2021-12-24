#
# Defines environment variables.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

# Ensure that a non-login, non-interactive shell has a defined environment.
if [[ ( "$SHLVL" -eq 1 && ! -o LOGIN ) && -s "${ZDOTDIR:-$HOME}/.zprofile" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprofile"
fi

export FZF_TMUX=0
# https://github.com/junegunn/fzf/issues/809
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
[ -n "$NVIM_LISTEN_ADDRESS" ] && export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --no-height"

export FZF_CTRL_T_COMMAND=$FZF_DEFAULT_COMMAND
# adds previews to completion
export FZF_CTRL_T_OPTS="--preview '(highlight -O ansi -l {} 2> /dev/null || cat {} || tree -C {}) 2> /dev/null | head -200'"
export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window down:3:hidden:wrap --bind '?:toggle-preview'"
export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"

alias fzf="fzf --bind 'ctrl-l:execute(less -f {}),ctrl-y:execute-silent(echo {} | pbcopy)+abort,ctrl-v:execute(vim {})+abort'"

export HISTSIZE=20000
export SAVEHIST=100000
export AWS_DEFAULT_REGION='us-west-1'
export GOPATH="$HOME/go"
export GOBIN="$GOPATH/bin"
export WORKON_HOME="$HOME/.virtualenvs"
export PROJECT_HOME="$HOME/projects"
export HOMEBREW_NO_INSTALL_CLEANUP=true
export BC_ENV_ARGS="$HOME/.bc"
