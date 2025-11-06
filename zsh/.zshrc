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
export GOTOOLCHAIN=local

# Set the the list of directories that cd searches.
cdpath=(
  $cdpath
  $HOME
  $HOME/projects
  $HOME/projects/work
  $HOME/go/src/github.com
)

# Add mise shims to $PATH instead of using mise activate/mise hook-env, as it interfers with kitten ssh
mise_path=()
if [[ -d "$HOME/.local/share/mise/shims" ]]; then
  mise_path=( "$HOME/.local/share/mise/shims" )
fi

# Set the list of directories that Zsh searches for programs.
brew_paths=()
if [[ -n "${HOMEBREW_PREFIX}" ]]; then
  brew_paths=(
    $HOMEBREW_PREFIX/opt/openssl@3/bin
    $HOMEBREW_PREFIX/opt/curl/bin
    $HOMEBREW_PREFIX/{bin,sbin}
    $HOMEBREW_PREFIX/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/bin
  )
fi
path=(
  $mise_path
  $HOME/.local/bin
  $HOME/.local/custom_bins
  $HOME/.krew/bin
  $HOME/.cargo/bin
  "/Applications/Android Studio.app/Contents/MacOS"
  $GOBIN
  $brew_paths
  /snap/bin
  /usr/local/{bin,sbin}
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
  zgenom load zdharma-continuum/fast-syntax-highlighting
  zgenom load djui/alias-tips
  zgenom load so-fancy/diff-so-fancy

  # custom extensions
  (( $+commands[direnv] )) && zgenom eval --name direnv < <(direnv hook zsh)
  (( $+commands[hubble] )) && zgenom eval --name hubble < <(hubble completion zsh; echo compdef _hubble hubble)
  (( $+commands[jump] )) && zgenom eval --name jump < <(jump shell)
  (( $+commands[kitty] )) && zgenom eval --name kitty < <(kitty + complete setup zsh)
  zgenom eval-if-exists zsh_work "$HOME/.zshrc_work"
  (( $+commands[crc] )) && zgenom eval --name crc < <(crc completion zsh)
  (( $+commands[switcher] )) && zgenom eval --name switcher < <(switcher init zsh; echo alias s=switch; echo compdef _switcher switch)

  # generate the init script from plugins above
  zgenom save
fi

# Disable warning when using > and >>
unsetopt noclobber

function source_if_exists() { [[ -s $1 ]] && source $1 && return 0 || return 1}

source_if_exists "$HOME/.cargo/env"

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

# gco - checkout git branch (including remote branches), sorted by most recent commit, limit 30 last branches
unalias gco
gco() {
  if [  $# -ne 0 ]; then
    git checkout "$@"
    return $?
  fi
  local branches branch
  branches=$(git for-each-ref --count=30 --sort=-committerdate refs/heads/ --format="%(refname:short)") &&

  echo "$branches" |
    fzf --no-sort --reverse --tiebreak=index --no-multi --ansi \
    --preview='_viewGitLogLine {}' \
    --header "enter to checkout, ctrl-e to view, ctrl-y to copy, ctrl-p to print -- branch" \
    --bind 'enter:become(echo {} | sed "s/.* //" | sed "s#remotes/[^/]*/##" | xargs git checkout)' \
    --bind 'ctrl-e:execute(_viewGitLogLine $(_gitLogLineToHash {}) | less -R)' \
    --bind 'ctrl-y:become(echo {} | pbcopy)' \
    --bind 'ctrl-p:accept'
}

# fcs - find git commit
fcs() {
  local commits commit
  commits=$(git log --color=always --pretty=oneline --decorate --abbrev-commit) &&
  echo "$commits" |
    fzf --no-sort --reverse --tiebreak=index --no-multi --ansi \
    --preview='_viewGitLogLine "$(_gitLogLineToHash {})"' \
    --header "enter to print, ctrl-y to copy, ctrl-v to view -- hash" \
    --bind 'enter:become(_gitLogLineToHash {})' \
    --bind 'ctrl-y:become(_gitLogLineToHash {} | pbcopy)' \
    --bind 'ctrl-v:execute(_viewGitLogLine $(_gitLogLineToHash {}) | less -R)'
}

# gshow - git commit browser with previews
gshow() {
  glNoGraph |
    fzf --no-sort --reverse --tiebreak=index --no-multi --ansi \
    --preview='_viewGitLogLine "$(_gitLogLineToHash {})"' \
    --header "enter to view, ctrl-y to copy, ctrl-p to print, ctrl-v to checkout -- hash" \
    --bind 'enter:execute(_viewGitLogLine $(_gitLogLineToHash {}) | less -R)' \
    --bind 'ctrl-y:become(_gitLogLineToHash {} | pbcopy)' \
    --bind 'ctrl-p:become(_gitLogLineToHash {})' \
    --bind 'ctrl-v:execute(_gitLogLineToHash {} | xargs git checkout)'
}

echoerr() { echo "$@" 1>&2; }

function kssm() {
  local node=${1:?Usage: kssm <k8s-node_name>}
  shift
  local INSTANCE_ID=$(kubectl get nodes "${node}" -o yaml | yq '.spec.providerID | split("/") | .[-1]')
  if [[ -z "$INSTANCE_ID" ]]; then
    echoerr "Unable to get instance ID for $node"
    return 1
  fi
  local AWS_REGION=$(kubectl get nodes "${node}" -o json | jq '.metadata.labels["topology.kubernetes.io/region"]' -r)
  if [[ -z "$AWS_REGION" ]]; then
    echoerr "Unable to get region for $node"
    return 1
  fi
  local CMD=(aws ssm start-session --target "$INSTANCE_ID" $@)
  echoerr "${CMD[@]}"
  # subshell to scope export
  (
    export AWS_REGION
    "${CMD[@]}"
  )
}

function kssm-exec() {
  local node=${1:?Usage: kssm-exec <k8s-node_name> <args>}
  shift
  PARAMETERS="$(jq -rnc '{command: $ARGS.positional}' --args "$@")"
  CMD=(kssm "${node}" --document-name AWS-StartInteractiveCommand --parameters "${PARAMETERS}")
  echoerr "${CMD[@]}"
  "${CMD[@]}"
}

function kssm-ssh-copy-id() {
  local node=${1:?Usage: kssm-exec <k8s-node_name> <key>}
  local key_file=${2:-"${HOME}/.ssh/id_rsa.pub"}

  KEY="$(cat "${key_file}")"
  kssm-exec "${node}" "sudo [ ! -f /home/ec2-user/.ssh/authorized_keys ] || ! sudo grep -q '$KEY' /home/ec2-user/.ssh/authorized_keys && echo '$KEY' | sudo tee -a /home/ec2-user/.ssh/authorized_keys && echo key added || echo key already exists"
}

function kssm-ssh() {
  local node=${1:?Usage: kssm-exec <k8s-node_name>}
  shift
  local INSTANCE_ID=$(kubectl get nodes "${node}" -o yaml | yq '.spec.providerID | split("/") | .[-1]')
  if [[ -z "$INSTANCE_ID" ]]; then
    echoerr "Unable to get instance ID for $node"
    return 1
  fi
  local AWS_REGION=$(kubectl get nodes "${node}" -o json | jq '.metadata.labels["topology.kubernetes.io/region"]' -r)
  if [[ -z "$AWS_REGION" ]]; then
    echoerr "Unable to get region for $node"
    return 1
  fi
  local CMD=(ssh "ec2-user@$INSTANCE_ID" "$@")
  echoerr "${CMD[@]}"
  # subshell to scope export
  (
    export AWS_REGION
    "${CMD[@]}"
  )
}

function kube-get-pod-resources-json() {
  kubectl get pods -o json "$@" \
    | jq -r '
      (
        .items[]
        | {
          namespace: .metadata.namespace,
                pod: .metadata.name,
                resources: (
                  .spec.containers[].resources
                  | {
                    memory_request: .requests.memory,
                    cpu_request: .requests.cpu,
                    memory_limit: .limits.memory
                  }
              )
            }
      )
      '
}

function kube-get-pod-resources() {
  kube-get-pod-resources-json $@ \
    | jq -n -r '
      ["NAMESPACE", "POD", "MEMORY_REQUEST", "CPU_REQUEST", "MEMORY_LIMIT"],
      (
        inputs
        | [.namespace, .pod, (.resources | to_entries | map(.value // "unset"))[]]
      )
      | @tsv
      ' \
    | column -t -s $'\t'
}

function kube-get-pod-resources-missing() {
  kube-get-pod-resources-json $@ \
    | jq -n -r '
      ["NAMESPACE", "POD", "MEMORY_REQUEST", "CPU_REQUEST", "MEMORY_LIMIT"],
      (
        inputs
        | select(.resources | to_entries | select(any(.value==null)))
        | [.namespace, .pod, (.resources | to_entries | map(.value // "unset"))[]]
      )
      | @tsv
      ' \
    | column -t -s $'\t'
}

alias k=kubectl
if command -v kubecolor >/dev/null 2>&1; then
  alias kubectl="kubecolor"
fi
alias kc='switch'
alias kns='switch namespace'
alias tf=terraform
# we disable autocd so this is an alternative for common path changes
alias ..='cd ..'
alias ../..='cd ../..'

# time aliases
alias zur='TZ=Europe/Zurich date'
alias pst='TZ=Etc/GMT-8 date'
alias est='TZ=Etc/GMT-5 date'
alias utc='TZ=Etc/UTC date'
alias cppwd="pwd | tee /dev/stderr | tr -d '\n' | pbcopy"

if [[ -e "/Applications/Tailscale.app/Contents/MacOS/Tailscale" ]]; then
  alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
fi

alias m4b-tool='docker run -it --rm -u $(id -u):$(id -g) -v "$(pwd)":/mnt sandreas/m4b-tool:latest'

# https://sw.kovidgoyal.net/kitty/faq/#i-get-errors-about-the-terminal-being-unknown-or-opening-the-terminal-failing-when-sshing-into-a-different-computer
command -v kitty >/dev/null && alias kittyssh="kitty +kitten ssh"

function nvim() {
  local no_session=false
  local args=()

  # Parse arguments
  for arg in "$@"; do
    case "$arg" in
      --no-session|--nosession)
        no_session=true
        ;;
      *)
        args+=("$arg")
        ;;
    esac
  done

  if "$no_session"; then
     args+=(--cmd "let g:auto_session_enabled = v:false")
  fi

  command nvim "${args[@]}"
}

if (( $+commands[nvim] )); then
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

# Set FZF options before loading fzf plugin
export FZF_DEFAULT_COMMAND='rg --files'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
# adds previews to completion
export FZF_CTRL_T_OPTS="--preview '(highlight -O ansi -l {} 2> /dev/null || cat {} || tree -C {}) 2> /dev/null | head -200'"
export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window down:3:hidden:wrap --bind '?:toggle-preview'"
export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"

# TODO: figure out why ohmyzsh fzf plugin doesn't work
eval "$(fzf --zsh)"

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
export LIMA_INSTANCE=docker

# Add kube-ps1 to prompt
if (( $+commands[kubectl] )); then
  PROMPT='$(kube_ps1) '$PROMPT
fi

# open the currently entered command in a text editor using 'v' in normal mode
bindkey -M vicmd v edit-command-line

function correct_git_commands() {
  local final_command=()
  local changes_made=false
  for arg in "$@"; do
    # if arg starts with refs/heads or if it's a path then we don't need to modify it
    if [[ "$arg" == refs/heads/* || "$arg" == */head* ]]; then
      final_command+=("$arg")
      continue
    fi
    # Use parameter substitution to replace 'head' with 'HEAD' in the argument
    corrected_arg="${arg//head/HEAD}"
    final_command+=("$corrected_arg")
    if [[ "$corrected_arg" != "$arg" ]]; then
      changes_made=true
    fi
  done
  if $changes_made; then
    echo "Executing corrected command: git ${final_command[*]}"
  fi
  command git "${final_command[@]}"
}

alias git=correct_git_commands
