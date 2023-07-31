# profile startup
zmodload zsh/zprof

# XDG
export XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}

# zgen options
export ZGEN_DIR=$XDG_DATA_HOME/zgenom
export ZGEN_RESET_ON_CHANGE=(${HOME}/.zshrc)
# install zgenom
[[ ! -d $ZGEN_DIR ]] && git clone https://github.com/jandamm/zgenom $ZGEN_DIR

# zsh opts
setopt extended_glob
setopt interactivecomments
# record the timestamp of each command
setopt EXTENDED_HISTORY
# append instead of replaci
setopt APPEND_HISTORY
# immediately add to history
setopt INC_APPEND_HISTORY
# number of entries in history file
export SAVEHIST=500000
# number of entries loaded from history file into memory
export HISTSIZE=50000

# autocd interfers with trying to call binaries that have the same name as a directory in CDPATH, so disable it.
unsetopt autocd

# zsh-autosuggestions config
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=red,bold,underline"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# Ensure path arrays do not contain duplicates.
typeset -gU cdpath fpath mailpath path manpath infopath


if [[ -d "/opt/homebrew" ]]; then
    export HOMEBREW_PREFIX="/opt/homebrew";
fi
if [[ -d "$HOME/.linuxbrew" ]]; then
    export HOMEBREW_PREFIX="$HOME/.linuxbrew";
fi
if [[ -d "/home/linuxbrew/.linuxbrew" ]]; then
    export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew";
fi

export GOPATH="$HOME/go"
export GOBIN="$GOPATH/bin"

# Set the the list of directories that cd searches.
cdpath=(
  $cdpath
  $HOME
  $HOME/projects
  $HOME/projects/work
  $HOME/go/src/github.com
)

# Set the list of directories that Zsh searches for programs.
brew_paths=()
if [[ -n "${HOMEBREW_PREFIX}" ]]; then
  brew_paths=(
    $HOMEBREW_PREFIX/opt/openssl@3/bin
    $HOMEBREW_PREFIX/{bin,sbin}
    $HOMEBREW_PREFIX/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/bin
  )
fi
path=(
  $HOME/.local/bin
  $HOME/.local/custom_bins
  $GOBIN
  $brew_paths
  /usr/local/{bin,sbin}
  "$HOME/.krew/bin"
  /usr/local/opt/curl/bin
  $path
)

# Add shell functions to zsh function path, this is needed for completition
if [[ -n "${HOMEBREW_PREFIX}" ]]; then
  fpath=( $HOMEBREW_PREFIX/share/zsh/site-functions $fpath)
fi

if [[ -n "${HOMEBREW_PREFIX}" ]]; then
  manpath=( $HOMEBREW_PREFIX/share/man $manpath )
fi

infopath=()
if [[ -n "${HOMEBREW_PREFIX}" ]]; then
  infopath=( $HOMEBREW_PREFIX/share/info $manpath)
fi

# load zgenom only after fpath is set, as it runs compinit
source "$ZGEN_DIR/zgenom.zsh"
autoload -U +X bashcompinit && bashcompinit

function zgenom-eval-if-exists() {
  name="${1:?name must be provided}"
  file="${2:?file must be provided}"
  if [[ -s ${@[$#]} ]]; then
    zgenom eval --name "$name" < "$file"
    return 0
  else
    return 1
  fi
}

# Check for plugin and zgenom updates every 7 days
# This does not increase the startup time.
zgenom autoupdate

if ! zgenom saved; then
  echo "Creating a zgenom save"

  zgenom compdef

  # extensions
  zgenom load jandamm/zgenom-ext-eval

  # ohmyzsh plugins
  zgenom ohmyzsh
  zgenom ohmyzsh plugins/gcloud

  # prezto options
  zgenom prezto prompt theme 'sorin'
  zgenom prezto editor key-bindings 'vi'
  zgenom prezto history-substring-search color 'yes'
  zgenom prezto ssh:load identities 'id_rsa'
  zgenom prezto '*:*' case-sensitive 'no'
  zgenom prezto '*:*' color 'yes'

  # prezto plugins
  zgenom prezto
  zgenom prezto environment
  zgenom prezto terminal
  zgenom prezto editor
  zgenom prezto history
  zgenom prezto directory
  zgenom prezto spectrum
  zgenom prezto utility
  zgenom prezto git
  zgenom prezto prompt
  zgenom prezto completion
  zgenom prezto history-substring-search
  zgenom prezto ssh

  # zsh plugins
  zgenom load jonmosco/kube-ps1
  zgenom load zsh-users/zsh-autosuggestions
  # zgenom load unixorn/fzf-zsh-plugin
  zgenom load zdharma-continuum/fast-syntax-highlighting

  # custom extensions
  (( $+commands[direnv] )) && zgenom eval --name direnv < <(direnv hook zsh)
  (( $+commands[hubble] )) && zgenom eval --name hubble < <(hubble completion zsh; echo compdef _hubble hubble)
  (( $+commands[jump] )) && zgenom eval --name jump < <(jump shell)
  (( $+commands[rtx] )) && zgenom eval --name rtx < <(rtx activate zsh; rtx hook-env)
  (( $+commands[kitty] )) && zgenom eval --name kitty < <(kitty + complete setup zsh)
  zgenom eval-if-exists zsh_work "$HOME/.zshrc_work"

  # generate the init script from plugins above
  zgenom save
fi

function source_if_exists() { [[ -s $1 ]] && source $1 && return 0 || return 1}

if source_if_exists "$HOMEBREW_PREFIX/opt/fzf/shell/completion.zsh"; then
  source_if_exists "$HOMEBREW_PREFIX/opt/fzf/shell/key-bindings.zsh"
elif source_if_exists "/usr/share/doc/fzf/examples/completion.zsh"; then
   source_if_exists  "/usr/share/doc/fzf/examples/key-bindings.zsh"
else
  # fallback
  source_if_exists "$HOME/.fzf.zsh"
fi

alias gst='git status'

function git-prune-branches-list() {
  git fetch --prune && (
    git branch -vv | grep -F ": gone]" | awk '{print $1}'
  )
}

function git-prune-branches-dry() {
  git-prune-branches-list | xargs echo git branch -D
}

function git-prune-branches() {
  git-prune-branches-list | xargs git branch -D
}

# fbr - checkout git branch (including remote branches), sorted by most recent commit, limit 30 last branches
fbr() {
  local branches branch
  branches=$(git for-each-ref --count=30 --sort=-committerdate refs/heads/ --format="%(refname:short)") &&
  branch=$(echo "$branches" |
           fzf-tmux -d $(( 2 + $(wc -l <<< "$branches") )) +m) &&
  git checkout $(echo "$branch" | sed "s/.* //" | sed "s#remotes/[^/]*/##")
}

function kssm() {
  node=$1
  INSTANCE_ID=$(kubectl get nodes "${node}" -o yaml | yq '.spec.providerID | split("/") | .[-1]')
  CMD=(aws ssm start-session --target "$INSTANCE_ID")
  echo "${CMD[@]}"
  "${CMD[@]}"
}

alias k=kubectl
alias kc=kubectx
alias kns=kubens
alias tf=terraform
# we disable autocd so this is an alternative for common path changes
alias ..='cd ..'
alias ../..='cd ../..'

# time aliases
alias zur='TZ=Europe/Zurich date'
alias pst='TZ=Etc/GMT-8 date'
alias utc='TZ=Etc/UTC date'
alias cppwd="pwd | tee /dev/stderr | tr -d '\n' | pbcopy"

# https://sw.kovidgoyal.net/kitty/faq/#i-get-errors-about-the-terminal-being-unknown-or-opening-the-terminal-failing-when-sshing-into-a-different-computer
command -v kitty >/dev/null && alias kssh="kitty +kitten ssh"

if command -v nvim >/dev/null; then
    alias vim='nvim'
    export EDITOR='nvim'
else
    export EDITOR='vim'
fi
export VISUAL="$EDITOR"
export GIT_EDITOR="$EDITOR"
export SUDO_EDITOR="$(which "$EDITOR")"
export PAGER='less'

# Set the default Less options.
# Mouse-wheel scrolling has been disabled by -X (disable screen clearing).
# Remove -X and -F (exit if the content fits on one screen) to enable it.
export LESS='-F -g -i -M -R -S -w -X -z-4'

if [[ -z "$LANG" ]]; then
  export LANG='en_US.UTF-8'
fi

if [[ "$OSTYPE" == darwin* ]]; then
  export BROWSER='open'
fi
if [[ $(uname -r) == *Microsoft ]]; then
  export BROWSER=wsl-open
fi

if (( $+commands[rg] )); then
    export FZF_DEFAULT_COMMAND='rg --files'
elif (( $+commands[ag] )); then
    export FZF_DEFAULT_COMMAND='ag -l -g ""'
else
    echo "missing rg/ag for fzf"
fi

export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
# adds previews to completion
export FZF_CTRL_T_OPTS="--preview '(highlight -O ansi -l {} 2> /dev/null || cat {} || tree -C {}) 2> /dev/null | head -200'"
export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window down:3:hidden:wrap --bind '?:toggle-preview'"
export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"

# fzf based cd without args
function cd() {
    if [[ "$#" != 0 ]]; then
        builtin cd "$@";
        return
    fi
    while true; do
        local lsd=$(echo ".." && ls -p | grep '/$' | sed 's;/$;;')
        local dir="$(printf '%s\n' "${lsd[@]}" |
            fzf --reverse --preview '
                __cd_nxt="$(echo {})";
                __cd_path="$(echo $(pwd)/${__cd_nxt} | sed "s;//;/;")";
                echo $__cd_path;
                echo;
                ls -p --color=always "${__cd_path}";
        ')"
        [[ ${#dir} != 0 ]] || return 0
        builtin cd "$dir" &> /dev/null
    done
}

function j() {
  cd "$(jump top | fzf --reverse)"
}

# rg config
if which rg > /dev/null; then
  export RIPGREP_CONFIG_PATH=$HOME/.ripgreprc;
fi

export HOMEBREW_NO_INSTALL_CLEANUP=true
export BC_ENV_ARGS="$HOME/.bc"

# Add kube-ps1 to prompt
if command -v kubectl >/dev/null; then
  PROMPT='$(kube_ps1) '$PROMPT
fi

# open the currently entered command in a text editor using 'v' in normal mode
bindkey -M vicmd v edit-command-line
