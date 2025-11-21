#!/usr/bin/env zsh

setopt extended_glob
setopt interactivecomments
# record the timestamp of each command
setopt EXTENDED_HISTORY
# append instead of replacing
setopt APPEND_HISTORY
# immediately add to history
setopt INC_APPEND_HISTORY

# autocd interfers with trying to call binaries that have the same name as a directory in CDPATH, so disable it.
unsetopt autocd

# Disable warning when using > and >>
unsetopt noclobber
