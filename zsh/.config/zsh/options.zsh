#!/usr/bin/env zsh

# General
setopt INTERACTIVE_COMMENTS   # Enable comments in interactive shell.
unsetopt NOCLOBBER            # Disable warning when using > and >>

# History

export SAVEHIST=500000        # number of entries in history file
export HISTSIZE=50000         # number of entries loaded from history file into memory
setopt BANG_HIST              # Treat the '!' character specially during expansion.
setopt EXTENDED_HISTORY       # Write the history file in the ':start:elapsed;command' format.
setopt SHARE_HISTORY          # Share history between all sessions.
setopt HIST_EXPIRE_DUPS_FIRST # Expire a duplicate event first when trimming history.
setopt HIST_IGNORE_DUPS       # Do not record an event that was just recorded again.
setopt HIST_IGNORE_ALL_DUPS   # Delete an old recorded event if a new event is a duplicate.
setopt HIST_FIND_NO_DUPS      # Do not display a previously found event.
setopt HIST_IGNORE_SPACE      # Do not record an event starting with a space.
setopt HIST_SAVE_NO_DUPS      # Do not write a duplicate event to the history file.
setopt HIST_VERIFY            # Do not execute immediately upon history expansion.
setopt HIST_BEEP              # Beep when accessing non-existent history.
setopt APPEND_HISTORY         # append instead of replacing
setopt INC_APPEND_HISTORY     # immediately add to history

# Directory navigation
setopt AUTO_PUSHD             # Push the old directory onto the stack on cd.
setopt PUSHD_IGNORE_DUPS      # Do not store duplicates in the stack.
setopt PUSHD_SILENT           # Do not print the directory stack after pushd or popd.
setopt PUSHD_TO_HOME          # Push to home directory when no argument is given.
setopt CDABLE_VARS            # Change directory to a path stored in a variable.
setopt MULTIOS                # Write to multiple descriptors.
unsetopt AUTOCD               # autocd interfers with trying to call binaries that have the same name as a directory in CDPATH, so disable it.

# Completion
setopt COMPLETE_IN_WORD     # Complete from both ends of a word.
setopt ALWAYS_TO_END        # Move cursor to the end of a completed word.
setopt PATH_DIRS            # Perform path search even on command names with slashes.
setopt AUTO_MENU            # Show completion menu on a successive tab press.
setopt AUTO_LIST            # Automatically list choices on ambiguous completion.
setopt AUTO_PARAM_SLASH     # If completed parameter is a directory, add a trailing slash.
setopt EXTENDED_GLOB        # Needed for file modification glob modifiers with compinit.
unsetopt MENU_COMPLETE      # Do not autoselect the first completion entry.
unsetopt FLOW_CONTROL       # Disable start/stop characters in shell editor.

# Use vi keybindings
# NOTE: This must be set before fzf to ensure fzf completion works
bindkey -v

# This needs to happen after we configure our path so it's in options.zsh
if (( $+commands[nvim] )); then
  export EDITOR='nvim'
else
  export EDITOR='vim'
fi

export VISUAL="$EDITOR"
export GIT_EDITOR="$EDITOR"
export SUDO_EDITOR="$EDITOR"
