#!/usr/bin/env zsh

# install zgenom
[[ ! -d $ZGEN_INSTALL_DIR ]] && git clone https://github.com/jandamm/zgenom $ZGEN_INSTALL_DIR

# load zgenom only after fpath is set, as it runs compinit
source "$XDG_DATA_HOME/zgenom/zgenom.zsh"

# ohmyzsh compinit dump location
export ZSH_COMPDUMP=$ZDOTDIR/.zcompdump
# ZGENOM compinit dump location
export ZGEN_CUSTOM_COMPDUMP=$ZDOTDIR/.zcompdump

# Used by the completion stubs in $ZDOTDIR/completions, so it has to be declared on every startup
# and not just while building the save below.
autoload -Uz zsh-load-completion

# Check for plugin and zgenom updates every 7 days
# This does not increase the startup time.
zgenom autoupdate

if ! zgenom saved; then
  echo "Creating a zgenom save"

  # extensions
  zgenom load jandamm/zgenom-ext-eval

  zgenom compdef

  zgenom load $ZDOTDIR/plugins/ssh.zsh
  zgenom load $ZDOTDIR/plugins/atuin-history-substring-search.zsh

  if (($+commands[starship])) then
    # Use sed to replace the hardcoded versioned path with the 'starship' command
    # This prevents breakage when upgrading starship via mise
    zgenom eval --name starship < <(starship init zsh | sed "s|$HOME/.local/share/mise/installs/starship/[^/]*/starship|starship|g")
  fi

  # zsh plugins
  zgenom load zdharma-continuum/fast-syntax-highlighting
  zgenom load zsh-users/zsh-autosuggestions
  zgenom load djui/alias-tips
  zgenom load so-fancy/diff-so-fancy
  zgenom load junegunn/fzf-git.sh
  zgenom ohmyzsh plugins/timer
  zgenom load atuinsh/atuin

  # custom extensions
  #
  # Only integrations that have to be in place before the first prompt belong here, because a
  # snapshot is taken once and never revisited: it goes stale the moment the tool is upgraded.
  # A tool whose output is only a completion function has a stub in $ZDOTDIR/completions instead,
  # which reruns the generator itself once it notices the tool has changed.
  (($+commands[direnv])) && zgenom eval --name direnv < <(direnv hook zsh)
  (($+commands[jump])) && zgenom eval --name jump < <(jump shell)
  (($+commands[switcher])) && zgenom eval --name switcher < <(switcher init zsh; echo compdef switch=switcher)
  (($+commands[cm])) && zgenom eval --name cm < <(cm shell-init zsh)

  # NOTE: This must be done after bindkey -v in options.zsh to ensure fzf completion works
  (($+commands[fzf])) && zgenom eval --name fzf < <(fzf --zsh; echo compdef _gnu_generic fzf)

  # Fill the completion caches those stubs read, at the same point the snapshots above are taken,
  # so the first completion of a command in a new shell never has to wait for its tool. Sourcing a
  # stub while warming runs only its generator, and each one skips the work if its cache is
  # already current, which is why this is not repeated on every startup.
  _zsh_completion_warm=1
  # `-` so the file test follows symlinks: these are symlinked in from the dotfiles repo.
  for _zsh_completion_stub in $ZDOTDIR/completions/_*(N-.); do
    source $_zsh_completion_stub
  done
  unset _zsh_completion_warm _zsh_completion_stub

  # generate the init script from plugins above
  zgenom save
fi
