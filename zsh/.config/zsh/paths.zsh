#!/usr/bin/env zsh

# Ensure path arrays do not contain duplicates.
typeset -gU cdpath fpath mailpath path manpath infopath

# Force PATH into the environment. Assigning to `path` only marks PATH exported if it was
# already exported, which is not true when zsh starts from an environment with no PATH at
# all (`env -i zsh`, some launchd/cron jobs). Without this, child processes fall back to
# zsh's built-in default instead of inheriting this PATH.
typeset -gx PATH

# Set the the list of directories that cd searches.
cdpath=(
  $cdpath
  $HOME
  $HOME/projects
  $HOME/projects/work
  $HOME/go/src/github.com
)

# Add mise shims to $PATH instead of using mise activate/mise hook-env, as it interfers with kitten ssh
mise_path=()
if [[ -d "$HOME/.local/share/mise/shims" ]]; then
  mise_path=("$HOME/.local/share/mise/shims")
fi

brew_paths=()
if [[ -n "${HOMEBREW_PREFIX}" ]]; then
  brew_paths=(
    $HOMEBREW_PREFIX/opt/openssl@3/bin
    $HOMEBREW_PREFIX/opt/curl/bin
    $HOMEBREW_PREFIX/{bin,sbin}
    $HOMEBREW_PREFIX/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/bin
  )
fi

# Read the system path files the way /usr/libexec/path_helper does: the base file first, then
# each drop-in under its .d directory. /etc/zprofile would normally run path_helper for us,
# but only for login shells and only after .zshenv, where it would reorder $PATH and put the
# system directories ahead of Homebrew and mise. .zshenv unsets GLOBAL_RCS to skip it, so
# gather the same inputs here and position them deliberately below.
#
# Parsing in-shell rather than shelling out keeps /etc/paths.d drop-ins working, which is the
# one thing path_helper is genuinely needed for, and avoids a fork in .zshenv that every
# `zsh -c` would pay for. Results go in $reply rather than being printed, so there is no
# command substitution either. Verified to produce output identical to `path_helper -s` for
# both PATH and MANPATH.
read_path_files() {
  local file line
  reply=()
  for file in "$1" "$1".d/*(N); do
    [[ -r $file ]] || continue
    while IFS= read -r line || [[ -n $line ]]; do
      [[ -n $line ]] && reply+=("$line")
    done < $file
  done
}

# Scoped to darwin because these files are Apple's, and it is macOS where skipping
# /etc/zprofile means nothing else reads them. The file tests above already make this a no-op
# elsewhere, but the guard keeps the intent obvious.
system_paths=() system_manpaths=()
if [[ "$OSTYPE" == darwin* ]]; then
  read_path_files /etc/paths;    system_paths=($reply)
  read_path_files /etc/manpaths; system_manpaths=($reply)
fi

# Set the list of directories that Zsh searches for programs.
path=(
  $HOME/.local/bin
  $HOME/.krew/bin
  $HOME/.cargo/bin
  $mise_path
  "/Applications/Android Studio.app/Contents/MacOS"
  $GOBIN
  $brew_paths
  /snap/bin
  /usr/local/{bin,sbin}
  /usr/local/opt/curl/bin
  $system_paths
  $path
)

# Add shell functions to zsh function path, this is needed for completition
if [[ -n "${HOMEBREW_PREFIX}" ]]; then
  fpath=($HOMEBREW_PREFIX/share/zsh/site-functions $fpath)
fi

# Autoloaded functions, and the completion stubs that generate a tool's completion the first time
# it is used. First in $fpath so a stub takes precedence over a copy shipped elsewhere, and set
# here rather than in plugins.zsh because compinit reads $fpath as it is when the zgenom save runs.
fpath=($ZDOTDIR/functions $ZDOTDIR/completions $fpath)

if [[ -n "${HOMEBREW_PREFIX}" ]]; then
  manpath=($HOMEBREW_PREFIX/share/man $manpath)
fi
manpath+=($system_manpaths)

infopath=()
if [[ -n "${HOMEBREW_PREFIX}" ]]; then
  infopath=($HOMEBREW_PREFIX/share/info $manpath)
fi

unset mise_path brew_paths system_paths system_manpaths reply
unfunction read_path_files
