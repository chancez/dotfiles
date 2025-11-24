#!/usr/bin/env zsh

# install zgenom
[[ ! -d $ZGEN_INSTALL_DIR ]] && git clone https://github.com/jandamm/zgenom $ZGEN_INSTALL_DIR

# load zgenom only after fpath is set, as it runs compinit
source "$XDG_DATA_HOME/zgenom/zgenom.zsh"

# ohmyzsh compinit dump location
export ZSH_COMPDUMP=$ZDOTDIR/.zcompdump
# ZGENOM compinit dump location
export ZGEN_CUSTOM_COMPDUMP=$ZDOTDIR/.zcompdump

# Check for plugin and zgenom updates every 7 days
# This does not increase the startup time.
zgenom autoupdate

if ! zgenom saved; then
  echo "Creating a zgenom save"

  # extensions
  zgenom load jandamm/zgenom-ext-eval

  zgenom compdef

  zgenom load $ZDOTDIR/plugins/ssh.zsh

  if (($+commands[starship])) then
    zgenom eval --name starship < <(starship init zsh)
  else
    # Fallback to sorin theme if starship is not installed
    zgenom ohmyzsh themes/sorin
    zgenom load jonmosco/kube-ps1
    PROMPT='$(kube_ps1) '$PROMPT
  fi

  # zsh plugins
  zgenom load zdharma-continuum/fast-syntax-highlighting
  zgenom load zsh-users/zsh-autosuggestions
  zgenom load zsh-users/zsh-history-substring-search
  zgenom load djui/alias-tips
  zgenom load so-fancy/diff-so-fancy
  zgenom load junegunn/fzf-git.sh

  # custom extensions
  (($+commands[direnv])) && zgenom eval --name direnv < <(direnv hook zsh)
  (($+commands[hubble])) && zgenom eval --name hubble < <(hubble completion zsh)
  (($+commands[jump])) && zgenom eval --name jump < <(jump shell)
  (($+commands[kitty])) && zgenom eval --name kitty < <(kitty + complete setup zsh)
  (($+commands[crc])) && zgenom eval --name crc < <(crc completion zsh)
  (($+commands[switcher])) && zgenom eval --name switcher < <(switcher init zsh)

  # NOTE: This must be done after bindkey -v in options.zsh to ensure fzf completion works
  (($+commands[fzf])) && zgenom eval --name fzf < <(fzf --zsh)

  # generate the init script from plugins above
  zgenom save
fi
