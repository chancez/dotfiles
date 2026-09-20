#!/usr/bin/env zsh

# macOS-only shell setup. Both of these exist to work around files that only Apple ships, so
# they are scoped to darwin rather than applied everywhere.
if [[ "$OSTYPE" == darwin* ]]; then
  # Don't run /etc/zprofile and /etc/zshrc. The one that matters is /etc/zprofile: it calls
  # path_helper, which reorders $PATH to put the system directories first, undoing the
  # ordering in paths.zsh. It also runs only for login shells and only after this file, so
  # honoring it would mean setting $PATH in two places. paths.zsh reads the same /etc/paths
  # inputs itself.
  #
  # What /etc/zshrc contributed is reproduced instead: `disable log` below, and
  # COMBINING_CHARS in options.zsh since that only affects line editing. Its default key
  # bindings are not carried over, the plugins in plugins.zsh rebind those anyway (verified
  # identical before and after).
  #
  # On Debian and Ubuntu the equivalent files live in /etc/zsh/ and are mostly harmless:
  # zprofile is comment-only, there is no path_helper, and zshenv runs before this file so
  # GLOBAL_RCS cannot suppress it anyway. Their zshrc does run a compinit, which is not
  # harmless; skip_global_compinit below turns that off rather than the whole file.
  unsetopt GLOBAL_RCS

  # zsh's `log` builtin shadows /usr/bin/log, and it takes entirely different arguments, so
  # `log show ...` fails. This has to be here rather than .zshrc to also cover scripts.
  # Linux has no /usr/bin/log, so disabling the builtin there would only remove a feature.
  disable log
fi

# Ubuntu's /etc/zsh/zshrc runs its own compinit. That lands before .zshrc, so before zgenom puts
# the plugin completion directories on $fpath, and it dumps to ${ZDOTDIR}/.zcompdump, which is the
# same file plugins.zsh hands zgenom. The generated init.zsh then loads that dump with `compinit -C`,
# and -C skips the rescan, so every completion zgenom installs is silently absent. Measured on an
# Ubuntu 22.04 host: 961 functions in the dump against 978 on $fpath, with _cm, _mise and _atuin
# among the 17 missing. /etc/zsh/zshrc documents this variable as the way out. Read in the same
# shell, so it does not need exporting, and nothing on macOS reads it.
skip_global_compinit=1

# XDG
export XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
export ZDOTDIR=${XDG_CONFIG_HOME}/zsh
export ZGEN_INSTALL_DIR=${XDG_DATA_HOME}/zgenom

# zgen options
# paths.zsh is included because the save bakes in $fpath and the compinit dump built from it, so
# adding a completion directory there has no effect until init.zsh is regenerated.
export ZGEN_RESET_ON_CHANGE=(${ZDOTDIR}/.zshrc ${ZDOTDIR}/plugins.zsh ${ZDOTDIR}/paths.zsh)

# zsh-autosuggestions config
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=red,bold,underline"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

export PAGER='less'
# Set the default Less options.
export LESS='-F -g -i -M -R -S -w -X -z-4 --mouse'

if [[ -z "$LANG" ]]; then
  export LANG='en_US.UTF-8'
  export LC_ALL='en_US.UTF-8'
fi

if [[ "$OSTYPE" == darwin* ]]; then
  export BROWSER='open'
elif [[ $(uname -r) == *Microsoft ]]; then
  export BROWSER=wsl-open
fi


if [[ -d "/opt/homebrew" ]]; then
  export HOMEBREW_PREFIX="/opt/homebrew"
elif [[ -d "$HOME/.linuxbrew" ]]; then
  export HOMEBREW_PREFIX="$HOME/.linuxbrew"
elif [[ -d "/home/linuxbrew/.linuxbrew" ]]; then
  export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
fi

export HOMEBREW_NO_INSTALL_CLEANUP=true
export BC_ENV_ARGS="$HOME/.bc"
export LIMA_INSTANCE=docker
export RIPGREP_CONFIG_PATH=$HOME/.ripgreprc

export GOPATH="$HOME/go"
export GOBIN="$GOPATH/bin"
export GOTOOLCHAIN=local

# Set $PATH here rather than in .zshrc so non-interactive shells get it too: anything that
# runs `zsh -c ...` (editor subprocesses, agent tool calls, git hooks, cron) reads only
# .zshenv. This has to come after HOMEBREW_PREFIX and GOBIN above, which it consumes.
source "$ZDOTDIR/paths.zsh"

if [ -f "$HOME/.dircolors" ]; then
  eval "$(dircolors -b "$HOME/.dircolors")"
fi

if [ -f "$HOME/.zshenv.local" ]; then
  source "$HOME/.zshenv.local"
fi
