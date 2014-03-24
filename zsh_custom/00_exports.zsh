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
export PATH=$HOME/bin:$HOME/.local/bin:$PATH

# set cabal
export PATH=$PATH:$HOME/.cabal/bin

# add Go paths
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin:/usr/local/go/bin

# add Node path
export PATH=$HOME/.node/bin:$PATH

# add Rvm path
export PATH=$PATH:$HOME/.rvm/bin # Add RVM to PATH for scripting

# Java
export JAVA_HOME=/usr/lib/jvm/java-7-oracle

# apache ant
export ANT_HOME=/opt/apache-ant-1.9.3
export PATH=$PATH:$ANT_HOME/bin

# add AndroidDev path
export PATH=$PATH:/opt/android-sdk-linux_86/tools:/opt/android-sdk-linux_86/platform-tools

# Heroku
export PATH=$PATH:/usr/local/heroku/bin

# App engine
export PATH=$PATH:/opt/google_appengine

export WORKON_HOME=$HOME/.virtualenvs
export PROJECT_HOME=$HOME/projects

# texlive
export PATH=$PATH:/home/chance/texlive/2013/bin/x86_64-linux
export INFOPATH=$INFOPATH:/home/chance/texlive/2013/texmf-dist/doc/info
export MANPATH=$MANPATH:/home/chance/texlive/2013/texmf-dist/doc/man

# macports
if [[ $platform == 'osx' ]]; then
    export PATH=$PATH:/opt/local/bin
    export MANPATH=$MANPATH:/opt/local/man
    export INFOPATH=$INFOPATH:/opt/local/share/info
fi


# Key bindings
# Vim keybindings
bindkey -v

# Incremental search is elite!
bindkey "^r" history-incremental-search-backward
bindkey "^s" history-incremental-search-forward
