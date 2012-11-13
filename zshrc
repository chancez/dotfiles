HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
setopt appendhistory nomatch notify
setopt incappendhistory
setopt sharehistory
setopt extendedhistory
unsetopt autocd beep extendedglob
export EDITOR="vim"
PATH=$PATH:$HOME/bin

#locale
export LANG=en_US.UTF-8

# Vim keybindings
bindkey -v
bindkey '^[[Z' reverse-menu-complete

DISABLE_AUTO_TITLE="false"

# aliases!

if [ -e /usr/bin/vimx ]; then alias vim='/usr/bin/vimx'; fi

#list aliases
alias ls='ls -F --color=auto' 
alias ll='ls -lh'
alias la='ls -a'
alias lg='ls | grep'
alias sl=ls # Anti typo

#List folders, and sizes
alias ducks='du -cksh * | sort -rn|head -11'

#ssh aliases
alias chat="mosh cloud -- tmux attach -d -t chat"

#rdesktop aliases
alias cn-workshop="rdesktop -T cn-workshop -d cn -u czibolsk cn-workshop.tss.oregonstate.edu </dev/null &>/dev/null & disown"
alias umbrella="rdesktop -T umbrella -d ONID -u zibolskc umbrella.scf.oregonstate.edu </dev/null &>/dev/null & disown"

#mount aliases
alias mnt-cn-share="sudo mount -t cifs -o username=zibolskc,domain=CN //cn-share.tss.oregonstate.edu/G0/ /media/cn-share"
alias mnt-onid="sudo mount -t cifs -o username=zibolskc,domain=ONID //ONID-FS.onid.orst.edu/zibolskc /media/ONID"

#grep aliases:
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

#Auto Completion
autoload -Uz compinit promptinit
compinit -i
zstyle ':completion:*' menu select
setopt completealiases

# more extensive tab completion
setopt completeinword

# Stuff to make my life easier

# auto change directories
setopt autocd


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


#uberj's extract function from his bashrc
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

#eval `keychain --quiet --nogui --eval --agents ssh `
eval $(keychain --eval --agents ssh -Q --quiet ~/.ssh/tidus_x220_key)

#source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Include various sub-.zshrc files
# but don't include vim .swp files
for file in $(ls $HOME/dotfiles/zshrc.d/*.zsh | grep -ve ".swp$" | grep -ve ".bak$")
do
    source $file
done

