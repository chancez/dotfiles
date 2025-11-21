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

  # prezto options
  zgenom prezto prompt theme 'sorin'
  zgenom prezto editor key-bindings 'vi'
  zgenom prezto history-substring-search color 'yes'
  zgenom prezto ssh:load identities  'id_ed25519' 'id_rsa'
  zgenom prezto '*:*' case-sensitive 'no'
  zgenom prezto '*:*' color 'yes'

  # prezto plugins
  zgenom prezto
  zgenom prezto environment
  zgenom prezto terminal
  zgenom prezto editor
  zgenom prezto history
  zgenom prezto directory
  zgenom prezto spectrum
  zgenom prezto utility
  zgenom prezto git
  zgenom prezto prompt
  zgenom prezto completion
  zgenom prezto history-substring-search
  zgenom prezto ssh

  # zsh plugins
  zgenom load jonmosco/kube-ps1
  zgenom load zsh-users/zsh-autosuggestions
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
