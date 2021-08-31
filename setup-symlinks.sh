#!/bin/zsh
setopt EXTENDED_GLOB

set -x
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

git submodule update --init --recursive

mkdir -p "$HOME/.vim/tmp/{backup,undo,swap}"
ln -s "$DOTFILES_DIR/vimrc" "$HOME/.vimrc"
ln -s "$DOTFILES_DIR/tmux.conf" "$HOME/.tmux.conf"

ln -s "$DOTFILES_DIR/ctags" "$HOME/.ctags"
mkdir -p "$HOME/.ctags.d"
ln -s "$DOTFILES_DIR/ctags" "$HOME/.ctags.d/default.ctags"

ln -s "$DOTFILES_DIR/agignore" "$HOME/.agignore"
ln -s "$DOTFILES_DIR/psqlrc" "$HOME/.psqlrc"
ln -s "$DOTFILES_DIR/pgclirc" "$HOME/.pgclirc"
ln -s "$DOTFILES_DIR/inputrc" "$HOME/.inputrc"
ln -s "$DOTFILES_DIR/gitconfig" "$HOME/.gitconfig"
ln -s "$DOTFILES_DIR/gitignore" "$HOME/.gitconfig"
ln -s "$DOTFILES_DIR/ssh_config" "$HOME/.ssh/config"

ln -s "$DOTFILES_DIR/prezto" "$HOME/.zprezto"

for rcfile in "${HOME}"/.zprezto/runcoms/^README.md(.N); do
  ln -s "$rcfile" "${HOME}/.${rcfile:t}"
done
