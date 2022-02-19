#
# Executes commands at login pre-zshrc.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

if [[ -e /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -e /opt/brew/bin/brew ]]; then
    eval "$(/opt/brew/bin/brew shellenv)"
fi

#
# Browser
#
if [[ "$OSTYPE" == darwin* ]]; then
  export BROWSER='open'
fi

#
# Editors
#
if command -v nvim > /dev/null; then
    export EDITOR='nvim'
else
    export EDITOR='vim'
fi
export VISUAL="$EDITOR"
export GIT_EDITOR="$EDITOR"
export PAGER='less'

#
# Language
#

if [[ -z "$LANG" ]]; then
  export LANG='en_US.UTF-8'
fi

#
# Paths
#

# Ensure path arrays do not contain duplicates.
typeset -gU cdpath fpath mailpath path

# Set the the list of directories that cd searches.
cdpath=(
  $cdpath
  $HOME
  $HOME/projects
  $HOME/go/src/github.com/chancez
  $HOME/go/src/github.com
)

# Set the list of directories that Zsh searches for programs.
path=(
  $HOME/.local/bin
  $HOME/dotfiles/custom_bins
  $HOME/.tmuxifier/bin
  $HOME/.fzf/bin
  $HOME/.vim/plugged/fzf/bin
  $GOPATH/bin
  $GOROOT/bin
  $HOME/Library/Python/3.8/bin
  $HOME/Library/Python/2.7/bin
  /usr/local/{bin,sbin}
  /usr/local/opt/python/libexec/bin
  "${KREW_ROOT:-$HOME/.krew}/bin"
  /usr/local/opt/curl/bin
  $path
)

#
# Less
#

# Set the default Less options.
# Mouse-wheel scrolling has been disabled by -X (disable screen clearing).
# Remove -X and -F (exit if the content fits on one screen) to enable it.
export LESS='-F -g -i -M -R -S -w -X -z-4'

# Set the Less input preprocessor.
# Try both `lesspipe` and `lesspipe.sh` as either might exist on a system.
if (( $#commands[(i)lesspipe(|.sh)] )); then
  export LESSOPEN="| /usr/bin/env $commands[(i)lesspipe(|.sh)] %s 2>&-"
fi
