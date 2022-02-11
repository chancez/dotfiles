#!/bin/zsh
setopt EXTENDED_GLOB

DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

git submodule update --init --recursive

STOW_DIRS=(\
    ag \
    brew \
    bins \
    ctags \
    git \
    kitty \
    neovim \
    postgres \
    rg \
    ssh \
    tmux \
    zsh \
)

for dir in "${STOW_DIRS[@]}"; do
    stow -R "${dir}" 2>&1 | grep -v "BUG in find_stowed_path"
done
