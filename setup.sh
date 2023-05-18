#!/bin/zsh
set -e
setopt EXTENDED_GLOB

DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

find . -maxdepth 1 -type d -not -path './.git' -not -path . | cut -d/ -f2- | sort -h | while read -r dir; do
    stow --no-folding -v "${dir}" 2>&1 | { grep -v "BUG in find_stowed_path" || test $? = 1; }
done
