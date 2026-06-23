#!/usr/bin/env zsh

# Use human-friendly identifiers.
zmodload zsh/terminfo

# open the currently entered command in a text editor using 'v' in normal mode,
# but when the command line is empty fall through to insert mode and type the 'v'
# (so typing "vim" from normal mode just works instead of opening an empty editor)
autoload edit-command-line
zle -N edit-command-line
edit-command-line-or-insert() {
  # ignore leading/trailing whitespace so a buffer of only spaces counts as empty
  if [[ -n "${BUFFER//[[:space:]]/}" ]]; then
    zle edit-command-line
  else
    zle vi-insert
    zle self-insert
  fi
}
zle -N edit-command-line-or-insert
bindkey -M vicmd v edit-command-line-or-insert

# Copy the current command line to clipboard with Ctrl-Y (without the trailing newline)
cmd_to_clip() { print -n -- "$BUFFER" | pbcopy }
zle -N cmd_to_clip
bindkey '^Y' cmd_to_clip

# Atuin mappings
bindkey '^R' atuin-search
bindkey -M vicmd "k" atuin-history-up
bindkey -M vicmd "j" atuin-history-down
bindkey -M viins '^[[A' atuin-history-up
bindkey -M viins '^[[B' atuin-history-down
