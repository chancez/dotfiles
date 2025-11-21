#!/usr/bin/env zsh

# Ensure path arrays do not contain duplicates.
typeset -gU cdpath fpath mailpath path manpath infopath

# Set the the list of directories that cd searches.
cdpath=(
  $cdpath
  $HOME
  $HOME/projects
  $HOME/projects/work
  $HOME/go/src/github.com
)

# Add mise shims to $PATH instead of using mise activate/mise hook-env, as it interfers with kitten ssh
local mise_path=()
if [[ -d "$HOME/.local/share/mise/shims" ]]; then
  mise_path=("$HOME/.local/share/mise/shims")
fi

local brew_paths=()
if [[ -n "${HOMEBREW_PREFIX}" ]]; then
  brew_paths=(
    $HOMEBREW_PREFIX/opt/openssl@3/bin
    $HOMEBREW_PREFIX/opt/curl/bin
    $HOMEBREW_PREFIX/{bin,sbin}
    $HOMEBREW_PREFIX/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/bin
  )
fi

# Set the list of directories that Zsh searches for programs.
path=(
  $mise_path
  $HOME/.local/bin
  $HOME/.local/custom_bins
  $HOME/.krew/bin
  $HOME/.cargo/bin
  "/Applications/Android Studio.app/Contents/MacOS"
  $GOBIN
  $brew_paths
  /snap/bin
  /usr/local/{bin,sbin}
  /usr/local/opt/curl/bin
  $path
)

# Add shell functions to zsh function path, this is needed for completition
if [[ -n "${HOMEBREW_PREFIX}" ]]; then
  fpath=($HOMEBREW_PREFIX/share/zsh/site-functions $fpath)
fi

if [[ -n "${HOMEBREW_PREFIX}" ]]; then
  manpath=($HOMEBREW_PREFIX/share/man $manpath)
fi

infopath=()
if [[ -n "${HOMEBREW_PREFIX}" ]]; then
  infopath=($HOMEBREW_PREFIX/share/info $manpath)
fi
