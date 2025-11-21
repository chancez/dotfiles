#!/usr/bin/env zsh

# open the currently entered command in a text editor using 'v' in normal mode
bindkey -M vicmd v edit-command-line

# Copy the current command line to clipboard with Ctrl-Y
cmd_to_clip() { pbcopy <<< ${BUFFER} }
zle -N cmd_to_clip
bindkey '^Y' cmd_to_clip
