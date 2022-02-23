# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# zsh opts
setopt extended_glob
setopt interactivecomments

# Ensure path arrays do not contain duplicates.
typeset -gU cdpath fpath mailpath path

# Set the the list of directories that cd searches.
cdpath=(
  $cdpath
  $HOME
  $HOME/projects
  $HOME/go/src/github.com
)

# Set the list of directories that Zsh searches for programs.
path=(
  $HOME/.local/bin
  $GOPATH/bin
  /opt/brew/{bin,sbin}
  /opt/homebrew/{bin,sbin}
  /usr/local/{bin,sbin}
  "$HOME/.krew/bin"
  /usr/local/opt/curl/bin
  $path
)

# Add shell functions to zsh function path, this is needed for completition
fpath=(
  /opt/homebrew/share/zsh/site-functions/
  /opt/brew/share/zsh/site-functions/
  /usr/local/share/zsh-completions
  $fpath
)

eval "$(brew shellenv)"

command -v hub >/dev/null && eval "$(hub alias -s)"
command -v kubectl >/dev/null && source <(kubectl completion zsh | sed '/"-f"/d') && compdef k=kubectl
command -v oc >/dev/null && source <(oc completion zsh)
command -v direnv >/dev/null && eval "$(direnv hook zsh)"
command -v fasd >/dev/null && eval "$(fasd --init auto)"
command -v kitty >/dev/null && kitty + complete setup zsh | source /dev/stdin

[[ -s "${HOME}/.iterm2_shell_integration.zsh" && "$UNAME" == "Darwin" ]] && source "$HOME/.iterm2_shell_integration.zsh"

if [[ -s "$BREW_PREFIX/opt/fzf/shell/completion.zsh" ]]; then
  source "$BREW_PREFIX/opt/fzf/shell/completion.zsh"
  source "$BREW_PREFIX/opt/fzf/shell/key-bindings.zsh"
elif [[ -s "$HOME/.fzf.zsh" ]]; then
  source "$HOME/.fzf.zsh"
fi

if [[ -s "$BREW_PREFIX/opt/asdf/asdf.sh" ]]; then
    source "$BREW_PREFIX/opt/asdf/asdf.sh"
elif [[ -s "$HOME/.asdf/asdf.sh" ]]; then
    source "$HOME/.asdf/asdf.sh"
fi

[[ -s "$HOME/.zshrc_work" ]] && source "$HOME/.zshrc_work"

alias opsignin='eval $(op signin chancez.1password.com chance.zibolski@gmail.com A3-GERNM3-T7F7QX-WEQCD-5PARX-F59D6-AMGG7)'
alias gst='git status'
alias k=kubectl
alias kc=kubectx
alias kns=kubens
alias tf=terraform

if command -v nvim >/dev/null; then
    alias vim='nvim'
    export EDITOR='nvim'
else
    export EDITOR='vim'
fi
export VISUAL="$EDITOR"
export GIT_EDITOR="$EDITOR"
export PAGER='less'

# Set the default Less options.
# Mouse-wheel scrolling has been disabled by -X (disable screen clearing).
# Remove -X and -F (exit if the content fits on one screen) to enable it.
export LESS='-F -g -i -M -R -S -w -X -z-4'

if [[ -z "$LANG" ]]; then
  export LANG='en_US.UTF-8'
fi

if [[ "$OSTYPE" == darwin* ]]; then
  export BROWSER='open'
fi


if (( $+commands[rg] )); then
    export FZF_DEFAULT_COMMAND='rg --files'
elif (( $+commands[ag] )); then
    export FZF_DEFAULT_COMMAND='ag -l -g ""'
else
    echo "missing rg/ag for fzf"
fi

export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
# adds previews to completion
export FZF_CTRL_T_OPTS="--preview '(highlight -O ansi -l {} 2> /dev/null || cat {} || tree -C {}) 2> /dev/null | head -200'"
export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window down:3:hidden:wrap --bind '?:toggle-preview'"
export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"

# rg config
if which rg > /dev/null; then
  export RIPGREP_CONFIG_PATH=$HOME/.ripgreprc;
fi

export HISTSIZE=20000
export SAVEHIST=100000
export GOPATH="$HOME/go"
export GOBIN="$GOPATH/bin"
export HOMEBREW_NO_INSTALL_CLEANUP=true
export BC_ENV_ARGS="$HOME/.bc"
