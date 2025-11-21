#!/usr/bin/env zsh

# Add kube-ps1 to prompt if it's installed
if (( $+functions[kube_ps1] )); then
  PROMPT='$(kube_ps1) '$PROMPT
fi
