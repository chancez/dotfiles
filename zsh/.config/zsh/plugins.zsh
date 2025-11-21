#!/usr/bin/env zsh

# Check for plugin and zgenom updates every 7 days
# This does not increase the startup time.
zgenom autoupdate

if ! zgenom saved; then
  echo "Creating a zgenom save"

  zgenom compdef

  # extensions
  zgenom load jandamm/zgenom-ext-eval

  # ohmyzsh plugins
  zgenom ohmyzsh
  zgenom ohmyzsh plugins/gcloud
  zgenom ohmyzsh plugins/ssh-agent
  if (($+commands[starship])) then
    zgenom eval --name starship < <(starship init zsh)
  else
    # Fallback to sorin theme if starship is not installed
    zgenom ohmyzsh themes/sorin
    zgenom load jonmosco/kube-ps1
    PROMPT='$(kube_ps1) '$PROMPT
  fi

  # zsh plugins
  zgenom load zsh-users/zsh-autosuggestions
  zgenom load zsh-users/zsh-history-substring-search
  zgenom load zdharma-continuum/fast-syntax-highlighting
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
  # (($+commands[fzf])) && zgenom eval --name fzf < <(fzf --zsh)

  # generate the init script from plugins above
  zgenom save
fi
