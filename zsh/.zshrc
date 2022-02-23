# XDG
export XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}

# zgen options
export ZGEN_DIR=$XDG_DATA_HOME/zgen
export ZGEN_RESET_ON_CHANGE=(${HOME}/.zshrc)
# install zgen
[[ ! -d $ZGEN_DIR ]] && git clone git@github.com:tarjoilija/zgen.git $ZGEN_DIR

# load zgen
source "$ZGEN_DIR/zgen.zsh"

# if the init script doesn't exist
if ! zgen saved; then
  # prezto options
  zgen prezto prompt theme 'sorin'
  zgen prezto editor key-bindings 'vi'
  zgen prezto history-substring-search color 'yes'
  zgen prezto ssh:load identities 'id_rsa'
  zgen prezto '*:*' case-sensitive 'no'
  zgen prezto '*:*' color 'yes'
  zgen prezto 'module:syntax-highlighting' highlighters 'main' 'brackets' 'pattern' 'cursor'

  # zgen plugins
  zgen prezto
  zgen prezto environment
  zgen prezto terminal
  zgen prezto editor
  zgen prezto history
  zgen prezto directory
  zgen prezto spectrum
  zgen prezto utility
  zgen prezto git
  zgen prezto prompt
  zgen prezto syntax-highlighting
  zgen prezto completion
  zgen prezto history-substring-search
  zgen prezto ssh
  if [[ "$OSTYPE" == darwin* ]]; then
    zgen prezto homebrew
    zgen prezto osx
  fi

  zgen load jonmosco/kube-ps1
  zgen load zsh-users/zsh-autosuggestions

  # generate the init script from plugins above
  zgen save
fi

# zsh opts
setopt extended_glob
setopt interactivecomments

# zsh-autosuggestions config
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=red,bold,underline"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# Ensure path arrays do not contain duplicates.
typeset -gU cdpath fpath mailpath path manpath infopath

export HOMEBREW_PREFIX="/opt/homebrew";

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
  $HOMEBREW_PREFIX/{bin,sbin}
  /usr/local/{bin,sbin}
  "$HOME/.krew/bin"
  /usr/local/opt/curl/bin
  $path
)

# Add shell functions to zsh function path, this is needed for completition
fpath=(
  $HOMEBREW_PREFIX/share/zsh/site-functions/
  /usr/local/share/zsh-completions
  $fpath
)

manpath=(
  $HOMEBREW_PREFIX/share/man
  $infopath
)

infopath=(
  $HOMEBREW_PREFIX/share/info
  $infopath
)

command -v hub >/dev/null && eval "$(hub alias -s)"
command -v kubectl >/dev/null && source <(kubectl completion zsh | sed '/"-f"/d') && compdef k=kubectl
command -v oc >/dev/null && source <(oc completion zsh)
command -v direnv >/dev/null && eval "$(direnv hook zsh)"
command -v fasd >/dev/null && eval "$(fasd --init auto)"
command -v kitty >/dev/null && kitty + complete setup zsh | source /dev/stdin

# source a script, if it exists
function source_if_exists() { [[ -s $1 ]] && source $1 && return 0 || return 1}

if source_if_exists "$HOMEBREW_PREFIX/opt/fzf/shell/completion.zsh"; then
  source_if_exists "$HOMEBREW_PREFIX/opt/fzf/shell/key-bindings.zsh"
else
  # fallback
  source_if_exists "$HOME/.fzf.zsh"
fi

if ! source_if_exists "$HOMEBREW_PREFIX/opt/asdf/asdf.sh"; then
  # fallback
  source_if_exists "$HOME/.asdf/asdf.sh"
fi

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
if [[ $(uname -r) == *Microsoft ]]; then
  export BROWSER=wsl-open
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

# Add kube-ps1 to prompt
PROMPT='$(kube_ps1) '$PROMPT
