#!/usr/bin/env zsh

# profile startup
zmodload zsh/zprof

# $PATH and $fpath are configured in .zshenv, so they are already set by the time plugins
# load here.

# Set options before loading plugins since some plugins require specific options to be set
source "$ZDOTDIR/options.zsh"

# Install zgenom and load plugins
source "$ZDOTDIR/plugins.zsh"

# Interactive shells get the full activation: [env] vars, and tools switched per directory on cd.
# Non-interactive shells make do with the shims on $PATH from paths.zsh, which is all they can use
# without a prompt to hook.
#
# Deliberately eval'd live rather than snapshotted with `zgenom eval-tool`: the script carries the
# generating shell's $PATH in literal `export PATH=` lines (the pre-mise baseline it restores to,
# and the shims entry it moves to the front), so replaying it in a later shell would reinstate a
# stale $PATH. That is what broke `kitten ssh`, whose bootstrap appends its own bin directory
# before any rc file runs: the stale assignment overwrote it.
(( $+commands[mise] )) && eval "$(mise activate zsh)"

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
