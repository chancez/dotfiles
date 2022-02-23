fpath=(/usr/local/share/zsh-completions $fpath)
[[ -d /opt/brew/share/zsh/site-functions/ ]] && fpath+=(/opt/brew/share/zsh/site-functions/)
[[ -d /opt/homebrew/share/zsh/site-functions/ ]] && fpath+=(/opt/homebrew/share/zsh/site-functions/)

# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

setopt interactivecomments

BREW_PREFIX="$(brew --prefix)"

command -v hub >/dev/null && eval "$(hub alias -s)"
command -v kubectl >/dev/null && source <(kubectl completion zsh | sed '/"-f"/d') && compdef k=kubectl
command -v oc >/dev/null && source <(oc completion zsh)
command -v direnv >/dev/null && eval "$(direnv hook zsh)"
command -v fasd >/dev/null && eval "$(fasd --init auto)"
command -v kitty >/dev/null && kitty + complete setup zsh | source /dev/stdin

[[ -s "${HOME}/.iterm2_shell_integration.zsh" && "$UNAME" == "Darwin" ]] && source "$HOME/.iterm2_shell_integration.zsh"

if [[ -s "$BREW_PREFIX/opt/fzf/shell/completion.zsh" ]]; then
  source "$BREW_PREFIX/opt/fzf/shell/completion.zsh"
  source "$BREW_PREFIX/opt/fzf/shell/key-bindings.zsh"
elif [[ -s "$HOME/.fzf.zsh" ]]; then
  source "$HOME/.fzf.zsh"
fi

if [[ -s "$BREW_PREFIX/opt/asdf/asdf.sh" ]]; then
    source "$BREW_PREFIX/opt/asdf/asdf.sh"
elif [[ -s "$HOME/.asdf/asdf.sh" ]]; then
    source "$HOME/.asdf/asdf.sh"
fi

[[ -s "$HOME/.zshrc_work" ]] && source "$HOME/.zshrc_work"

alias opsignin='eval $(op signin chancez.1password.com chance.zibolski@gmail.com A3-GERNM3-T7F7QX-WEQCD-5PARX-F59D6-AMGG7)'
alias gst='git status'
alias k=kubectl
alias kc=kubectx
alias kns=kubens
alias tf=terraform

if command -v nvim >/dev/null; then
    alias vim='nvim'
fi

if (( $+commands[rg] )); then
    export FZF_DEFAULT_COMMAND='rg --files'
elif (( $+commands[ag] )); then
    export FZF_DEFAULT_COMMAND='ag -l -g ""'
else
    echo "missing rg/ag for fzf"
fi

# rg config
if which rg > /dev/null; then
  export RIPGREP_CONFIG_PATH=$HOME/.ripgreprc;
fi
