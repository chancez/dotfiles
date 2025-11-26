#!/usr/bin/env zsh

# XDG
export XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
export ZDOTDIR=${XDG_CONFIG_HOME}/zsh
export ZGEN_INSTALL_DIR=${XDG_DATA_HOME}/zgenom

# zgen options
export ZGEN_RESET_ON_CHANGE=(${ZDOTDIR}/.zshrc ${ZDOTDIR}/plugins.zsh)

# zsh-autosuggestions config
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=red,bold,underline"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

export PAGER='less'
# Set the default Less options.
# Mouse-wheel scrolling has been disabled by -X (disable screen clearing).
# Remove -X and -F (exit if the content fits on one screen) to enable it.
export LESS='-F -g -i -M -R -S -w -X -z-4'

if [[ -z "$LANG" ]]; then
  export LANG='en_US.UTF-8'
  export LC_ALL='en_US.UTF-8'
fi

if [[ "$OSTYPE" == darwin* ]]; then
  export BROWSER='open'
elif [[ $(uname -r) == *Microsoft ]]; then
  export BROWSER=wsl-open
fi


if [[ -d "/opt/homebrew" ]]; then
  export HOMEBREW_PREFIX="/opt/homebrew"
elif [[ -d "$HOME/.linuxbrew" ]]; then
  export HOMEBREW_PREFIX="$HOME/.linuxbrew"
elif [[ -d "/home/linuxbrew/.linuxbrew" ]]; then
  export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
fi

export HOMEBREW_NO_INSTALL_CLEANUP=true
export BC_ENV_ARGS="$HOME/.bc"
export LIMA_INSTANCE=docker
export RIPGREP_CONFIG_PATH=$HOME/.ripgreprc

export GOPATH="$HOME/go"
export GOBIN="$GOPATH/bin"
export GOTOOLCHAIN=local

if [ -f "$HOME/.zshenv.local" ]; then
  source "$HOME/.zshenv.local"
fi
