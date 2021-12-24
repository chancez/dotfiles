#!/bin/zsh
setopt EXTENDED_GLOB

set -x
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

git submodule update --init --recursive

STOW_DIRS=(\
    ag \
    bins \
    ctags \
    git \
    neovim \
    postgres \
    ssh \
    tmux \
    zsh \
)

for dir in "${STOW_DIRS}"; do
    stow -R "${dir}"
done
