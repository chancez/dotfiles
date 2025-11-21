#!/usr/bin/env zsh

# profile startup
zmodload zsh/zprof

# install zgenom
[[ ! -d $XDG_DATA_HOME/zgenom ]] && git clone https://github.com/jandamm/zgenom $XDG_DATA_HOME/zgenom

# load zgenom only after fpath is set, as it runs compinit
source "$XDG_DATA_HOME/zgenom/zgenom.zsh"
# autoload -U +X bashcompinit && bashcompinit

# Configure fpath and PATH before loading plugins
source "$ZDOTDIR/paths.zsh"

# Configure install plugins via zgenom
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
