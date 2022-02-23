#!/bin/zsh
set -e
setopt EXTENDED_GLOB

DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

if [[ ! -d "${HOME}/.zgen" ]]; then
  echo "Installing zgen"
  git clone https://github.com/tarjoilija/zgen.git "${HOME}/.zgen"
fi

find . -depth 1 -type d -not -path './.git' |  cut -d/ -f2- | sort -h | while read -r dir; do
    stow -R "${dir}" 2>&1 | grep -v "BUG in find_stowed_path"
done
