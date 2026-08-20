#!/usr/bin/env zsh

# profile startup
zmodload zsh/zprof

# $PATH and $fpath are configured in .zshenv, so they are already set by the time plugins
# load here.

# Set options before loading plugins since some plugins require specific options to be set
source "$ZDOTDIR/options.zsh"

# Install zgenom and load plugins
source "$ZDOTDIR/plugins.zsh"

# Functions/aliases/etc.
source "$ZDOTDIR/aliases.zsh"
source "$ZDOTDIR/fzf.zsh"
source "$ZDOTDIR/git.zsh"
source "$ZDOTDIR/kube.zsh"
source "$ZDOTDIR/bindings.zsh"
source "$ZDOTDIR/title.zsh"
source "$ZDOTDIR/kitty.zsh"

# Allow per-machine overrides and customizations
if [ -f "$HOME/.zshrc.local" ]; then
  source "$HOME/.zshrc.local"
fi
