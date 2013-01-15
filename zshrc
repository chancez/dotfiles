HISTFILE=~/.histfile
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
setopt nomatch
setopt notify
setopt incappendhistory
setopt sharehistory
setopt extendedhistory
setopt hist_ignore_dups     # Ignore same command run twice+
setopt nobeep
setopt extendedglob
unsetopt autocd

# locale
export LANG=en_US.UTF-8
# other stuff
export EDITOR="vim"
export DE=herbstluftwm

# set path
PATH=$HOME/bin:$PATH:$HOME/.gem/ruby/1.9.1/bin

# Vim keybindings
bindkey -v
bindkey '^[[Z' reverse-menu-complete

DISABLE_AUTO_TITLE="false"

# aliases!

if [ -e /usr/bin/vimx ]; then alias vim='/usr/bin/vimx'; fi

alias pacman='pacman-color'
alias hc='herbstclient'

# list aliases
alias ls='ls -F --color=auto' 
alias ll='ls -lh'
alias la='ls -a'
alias lla='ls -la'
alias lg='ls | grep'
alias sl=ls # Anti typo

# List folders, and sizes
alias ducks='du -cksh * | sort -rn|head -11'

# ssh aliases
alias chat="ssh cloud -t 'tmux attach -d -t chat'"
alias ash="ssh ash -t tmux att -d -t ash"

# rdesktop aliases
# alias umbrella="rdesktop -g 1280x720 -T umbrella -d ONID -u zibolskc umbrella.scf.oregonstate.edu </dev/null &>/dev/null & disown"
alias umbrella="rdesktop -g 1280x720 -T umbrella -d ONID -u zibolskc umbrella.scf.oregonstate.edu"

# mount aliases
alias mnt-onid="sudo mount -t cifs -o username=zibolskc,domain=ONID //ONID-FS.onid.orst.edu/zibolskc /mnt/ONID"

# grep aliases:
alias grep='grep --color=auto' 
alias -g G="| grep"
alias -g L="| less"
alias gaux='ps aux | grep'

# Find python file
alias pyfind='find . -name "*.py"'
# Remove python compiled byte-code
alias pyclean='find . -type f -name "*.py[co]" -exec rm -f \{\} \;'

# Serves the current directory
alias serve='twistd -n web --path .'

# Auto Completion
autoload -Uz compinit promptinit
compinit -i
zstyle ':completion:*' menu select
setopt completealiases

# more extensive tab completion
setopt completeinword

# allow approximate
zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*:match:*' original only
zstyle ':completion:*:approximate:*' max-errors 1 numeric

# tab completion for PID :D
zstyle ':completion:*:*:kill:*' menu yes select
zstyle ':completion:*:kill:*' force-list always

# cd not select parent dir
zstyle ':completion:*:cd:*' ignore-parents parent pwd

# Key bindings
# Incremental search is elite!
bindkey -M vicmd "/" history-incremental-search-backward
bindkey -M vicmd "?" history-incremental-search-forward

# Search based on what you typed in already
bindkey -M vicmd "//" history-beginning-search-backward
bindkey -M vicmd "??" history-beginning-search-forward

# Functions!

# useful for path editing -- backward-delete-word, but with / as additional delimiter
backward-delete-to-slash () {
  local WORDCHARS=${WORDCHARS//\//}
    zle .backward-delete-word
    }
    zle -N backward-delete-to-slash

# extract
extract () {
    if [ -f $1 ] ; then
        case $1 in
            *.tar.bz2)   tar xvjf $1        ;;
            *.tar.gz)    tar xvzf $1     ;;
            *.bz2)       bunzip2 $1       ;;
            *.rar)       unrar x $1     ;;
            *.gz)        gunzip $1     ;;
            *.tar)       tar xvf $1        ;;
            *.tbz2)      tar xvjf $1      ;;
            *.tgz)       tar xvzf $1       ;;
            *.zip)       unzip $1     ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7z x $1    ;;
            *)           echo "'$1' cannot be extracted via >extract<" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# eval `keychain --quiet --nogui --eval --agents ssh `
eval $(keychain --eval --agents ssh -Q --quiet ~/.ssh/id_rsa)

# source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Include various sub-.zshrc files
# but don't include vim .swp files
# files sourced need to end in .zsh
for file in $(ls $HOME/.zshrc.d/*.zsh | grep -ve ".swp$" | grep -ve ".bak$")
do
    source $file
done

