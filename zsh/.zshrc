#
# Executes commands at the start of an interactive session.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#
#

fpath=(/usr/local/share/zsh-completions $fpath)
[[ -d /opt/brew/share/zsh/site-functions/ ]] && fpath+=(/opt/brew/share/zsh/site-functions/)
[[ -d /opt/homebrew/share/zsh/site-functions/ ]] && fpath+=(/opt/homebrew/share/zsh/site-functions/)


# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

setopt interactivecomments

command -v hub >/dev/null && eval "$(hub alias -s)"
command -v kubectl >/dev/null && source <(kubectl completion zsh | sed '/"-f"/d') && compdef k=kubectl
# Openshift completion for `oc`
command -v oc >/dev/null && source <(oc completion zsh)
command -v direnv >/dev/null && eval "$(direnv hook zsh)"
command -v fasd >/dev/null && eval "$(fasd --init auto)"

# Completion for kitty
command -v kitty >/dev/null && kitty + complete setup zsh | source /dev/stdin

# rg config
if which rg > /dev/null; then export RIPGREP_CONFIG_PATH=$HOME/.ripgreprc; fi

# List folders, and sizes
alias ducks='du -cksh * | sort -rn|head -11'

# ssh aliases
alias opsignin='eval $(op signin chancez.1password.com chance.zibolski@gmail.com A3-GERNM3-T7F7QX-WEQCD-5PARX-F59D6-AMGG7)'

# Find python file
alias pyfind='find . -name "*.py"'
# Remove python compiled byte-code
alias pyclean='find . -type f -name "*.py[co]" -exec rm -f \{\} \;'

alias gst='git status'
alias gi='git'

alias k=kubectl
alias kc=kubectx
alias kns=kubens

alias tf=terraform

if command -v nvim >/dev/null; then
    alias vim='nvim'
fi

function minikube() {
    CTX="$(kubectx -c)"
    kubectx minikube >/dev/null
    command minikube "$@"
    code=$?
    kubectx "$CTX" > /dev/null 2>&1 || :
    return $code
}

alias glgs="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%Creset' --abbrev-commit --date=relative"

alias firepower='sudo /usr/libexec/ApplicationFirewall/socketfilterfw'

[[ -s "$HOME/.dvm/dvm.sh" ]] && source "$HOME/.dvm/dvm.sh"
[[ -s "${HOME}/.iterm2_shell_integration.zsh" && "$UNAME" == "Darwin" ]] && source "$HOME/.iterm2_shell_integration.zsh"
[[ -s "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
export CARGO_HOME=$HOME/.cargo

# The next line updates PATH for the Google Cloud SDK.
[[ -s "$HOME/projects/google-cloud-sdk/path.zsh.inc" ]] && source "$HOME/projects/google-cloud-sdk/path.zsh.inc"

# The next line enables shell command completion for gcloud.
[[ -s "$HOME/projects/google-cloud-sdk/completion.zsh.inc" ]] && source "$HOME/projects/google-cloud-sdk/completion.zsh.inc"

[[ -s "/usr/local/etc/profile.d/z.sh" ]] && source "/usr/local/etc/profile.d/z.sh"

[[ -s "$HOME/dotfiles/zfuncs/fzf.zsh" ]] && source "$HOME/dotfiles/zfuncs/fzf.zsh"

if [[ -s "$HOME/.fzf.zsh" ]]; then
    source "$HOME/.fzf.zsh"
else
    [[ -s "$HOME/.vim/plugged/fzf/shell/key-bindings.zsh" ]] && source "$HOME/.vim/plugged/fzf/shell/key-bindings.zsh"
    [[ -s "$HOME/.vim/plugged/fzf/shell/completion.zsh" ]] && source "$HOME/.vim/plugged/fzf/shell/completion.zsh"
fi

if (( $+commands[rg] )); then
    export FZF_DEFAULT_COMMAND='rg --files'
elif (( $+commands[ag] )); then
    export FZF_DEFAULT_COMMAND='ag -l -g ""'
else
    echo "missing rg/ag for fzf"
fi

if [[ -s /opt/brew/opt/asdf/asdf.sh ]]; then
    source /opt/brew/opt/asdf/asdf.sh
elif [[ -s "$HOME/.asdf/asdf.sh" ]]; then
    source "$HOME/.asdf/asdf.sh"
elif [[ -s "/opt/homebrew/opt/asdf/libexec/asdf.sh" ]]; then
     source /opt/homebrew/opt/asdf/libexec/asdf.sh
fi

[[ -s "$HOME/.zshrc_work" ]] && source "$HOME/.zshrc_work"

autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /usr/local/bin/vault vault
complete -o nospace -C /usr/local/bin/kustomize kustomize

