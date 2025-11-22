#!/usr/bin/env zsh

# profile startup
zmodload zsh/zprof

# Configure fpath and PATH before loading plugins
source "$ZDOTDIR/paths.zsh"

# Install zgenom and load plugins
source "$ZDOTDIR/plugins.zsh"

# Set options after loading plugins since some plugins set options that we want to unset
source "$ZDOTDIR/options.zsh"

# Functions/aliases/etc.
source "$ZDOTDIR/aliases.zsh"
source "$ZDOTDIR/fzf.zsh"
source "$ZDOTDIR/git.zsh"
source "$ZDOTDIR/kube.zsh"
source "$ZDOTDIR/bindings.zsh"

# Allow per-machine overrides and customizations
if [ -f "$HOME/.zshrc.local" ]; then
  source "$HOME/.zshrc.local"
fi
