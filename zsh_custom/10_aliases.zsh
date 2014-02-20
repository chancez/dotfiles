if [ -e /usr/bin/vimx ]; then alias vim='/usr/bin/vimx'; fi

# Use hub if it exists.
#if [ -e ~/bin/hub ]; then alias git='hub'; fi
eval "$(hub alias -s)"

#alias pacman='pacman-color'
alias hc='herbstclient'

# list aliases
alias ll='ls -lh'
alias la='ls -a'
alias lla='ls -la'
alias lg='ls | grep'
alias sl=ls # Anti typo

# List folders, and sizes
alias ducks='du -cksh * | sort -rn|head -11'

# ssh aliases
alias chat="ssh cloud -t 'tmux attach -d -t chat'"
alias chatm="mosh cloud -- tmux attach -d -t chat"
alias ash="ssh ash -t tmux att -d"

# rdesktop aliases
# alias umbrella="rdesktop -g 1280x720 -T umbrella -d ONID -u zibolskc umbrella.scf.oregonstate.edu </dev/null &>/dev/null & disown"
alias umbrella="rdesktop -g 1280x720 -T umbrella -d ONID -u zibolskc umbrella.scf.oregonstate.edu"

# mount aliases
alias mnt-onid="sudo mount -t cifs -o username=zibolskc,domain=ONID //ONID-FS.onid.orst.edu/zibolskc /mnt/ONID"

# grep aliases:
alias grep='grep --color=auto'
alias grpe='grep --color=auto'
alias gerp='grep --color=auto'
alias -g G="| grep"
alias -g L="| less"
alias gaux='ps aux | grep'

# Find python file
alias pyfind='find . -name "*.py"'
# Remove python compiled byte-code
alias pyclean='find . -type f -name "*.py[co]" -exec rm -f \{\} \;'

alias ipy="python -c 'import IPython; IPython.terminal.ipapp.launch_new_instance()'"

alias dls="$HOME/Downloads"
