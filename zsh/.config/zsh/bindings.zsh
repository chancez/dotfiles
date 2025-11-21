#!/usr/bin/env zsh

# open the currently entered command in a text editor using 'v' in normal mode
bindkey -M vicmd v edit-command-line

# Copy the current command line to clipboard with Ctrl-Y
cmd_to_clip() { pbcopy <<< ${BUFFER} }
zle -N cmd_to_clip
bindkey '^Y' cmd_to_clip

# History substring search mappings
bindkey -M vicmd "k" history-substring-search-up
bindkey -M vicmd "j" history-substring-search-down
for keymap in 'emacs' 'viins'; do
  # Up arrow
  bindkey '^[[A' history-substring-search-up
  # Down arrow
  bindkey '^[[B' history-substring-search-down
done
