typeset -aU path

if [[ -n $TMUX ]]; then
    return
fi

## locale
export LANG=en_US.UTF-8
# other stuff
export EDITOR="vim"
export DE=herbstluftwm
export BROWSER="google-chrome"

# set home path
path=($HOME/bin $HOME/.local/bin /usr/local/bin $path)

# set cabal
path=($path $HOME/.cabal/bin)

# add Go paths
export GOPATH=$HOME/go
path=($path $GOPATH/bin /usr/local/go/bin)

# add Node path
path=($HOME/.node/bin $path)

# add Rvm path
path=($path $HOME/.rvm/bin)# Add RVM to PATH for scripting)

# Java
export JAVA_HOME=/usr/lib/jvm/java-7-oracle

# apache ant
export ANT_HOME=/opt/apache-ant-1.9.3
path=($path $ANT_HOME/bin)

# add AndroidDev path
path=($path /opt/android-sdk-linux_86/tools:/opt/android-sdk-linux_86/platform-tools)

# Heroku
path=($path /usr/local/heroku/bin)

# App engine
path=($path /opt/google_appengine)

export WORKON_HOME=$HOME/.virtualenvs
export PROJECT_HOME=$HOME/projects

# texlive
path=($path /home/chance/texlive/2013/bin/x86_64-linux)
export INFOPATH=$INFOPATH:/home/chance/texlive/2013/texmf-dist/doc/info
export MANPATH=$MANPATH:/home/chance/texlive/2013/texmf-dist/doc/man


[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*

