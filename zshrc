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

## locale
export LANG=en_US.UTF-8
# other stuff
export EDITOR="vim"
export DE=herbstluftwm
export BROWSER="google-chrome"

platform='unknown'
unamestr=`uname`
if [[ "$unamestr" == 'Linux' ]]; then
    platform='linux'
elif [[ "$unamestr" == 'Darwin' ]]; then
    platform='osx'
fi

# set home path
export PATH=$PATH:$HOME/bin:$HOME/.local/bin

# set cabal
export PATH=$PATH:$HOME/.cabal/bin

# add Go paths
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin:/usr/local/go/bin

# add Node path
export PATH=$PATH:/usr/local/share/npm/bin

# add Rvm path
export PATH=$PATH:$HOME/.rvm/bin # Add RVM to PATH for scripting

# macports
if [[ $platform == 'osx' ]]; then
    export PATH=$PATH:/opt/local/bin
    export MANPATH=$MANPATH:/opt/local/man
    export INFOPATH=$INFOPATH:/opt/local/share/info
fi

# Vim keybindings
bindkey -v
bindkey '^[[Z' reverse-menu-complete

DISABLE_AUTO_TITLE="false"

# aliases!

if [ -e /usr/bin/vimx ]; then alias vim='/usr/bin/vimx'; fi

# Use hub if it exists.
#if [ -e ~/bin/hub ]; then alias git='hub'; fi
eval "$(hub alias -s)"

#alias pacman='pacman-color'
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
bindkey "^r" history-incremental-search-backward
bindkey "^s" history-incremental-search-forward


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

# source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Include various sub-.zshrc files
# but don't include vim .swp files
# files sourced need to end in .zsh
for file in $(ls $HOME/.zshrc.d/*.zsh | grep -ve ".swp$" | grep -ve ".bak$")
do
    source $file
done


export WORKON_HOME=$HOME/.virtualenvs
export PROJECT_HOME=$HOME/projects

[[ -e "$HOME/.local/bin/virtualenvwrapper.sh" ]] && source "$HOME/.local/bin/virtualenvwrapper.sh"
[[ -e "/usr/local/bin/virtualenvwrapper.sh" ]] && source "/usr/local/bin/virtualenvwrapper.sh"
[[ -e "/usr/bin/virtualenvwrapper.sh" ]] && source "/usr/bin/virtualenvwrapper.sh"

function fsh () {
        ssh -t fir "sudo bash -i -c \"ssh $@\""
}

# Add ssh keys
eval $(keychain --eval --agents ssh -Q --quiet ~/.ssh/id_rsa ~/.ssh/id_rsa_fir)

### Added by the Heroku Toolbelt
export PATH="/usr/local/heroku/bin:$PATH"

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

# Store VMS on localdisk if at work
if [[ `hostname` == *osuosl* ]]; then
    local vm_base_path="/data/virtualbox-vms/$USER"
    if [[ -e "$vm_base_path" ]]; then
        export VAGRANT_HOME="$vm_base_path/vagrant"
    else
        mkdir -p "$vm_base_path"
    fi
fi
