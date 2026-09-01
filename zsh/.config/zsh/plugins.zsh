#!/usr/bin/env zsh

# install zgenom
[[ ! -d $ZGEN_INSTALL_DIR ]] && git clone https://github.com/jandamm/zgenom $ZGEN_INSTALL_DIR

# load zgenom only after fpath is set, as it runs compinit
source "$XDG_DATA_HOME/zgenom/zgenom.zsh"

# ohmyzsh compinit dump location
export ZSH_COMPDUMP=$ZDOTDIR/.zcompdump
# ZGENOM compinit dump location
export ZGEN_CUSTOM_COMPDUMP=$ZDOTDIR/.zcompdump

# Local zgenom extensions, in $ZDOTDIR/functions. zgenom calls any `zgenom-*` function as a
# subcommand, and $ZGENOM_EXTENSIONS is what puts one in `zgenom help` and its completion.
autoload -Uz zgenom-refresh-tools zsh-generate-file zsh-tool-changed-since
ZGENOM_EXTENSIONS+=(
  'eval-tool:Keep the output of a tool as a plugin, recording the command that generated it'
  'refresh-tools:Regenerate every eval-tool output whose tool has changed'
)

# Regenerate whatever a tool upgrade has made stale, before `zgenom saved` loads it below. This has
# to happen at startup rather than on demand: a completion could wait to be asked for, but a prompt
# or a hook is needed before there is anything to ask.
zgenom refresh-tools

# Check for plugin and zgenom updates every 7 days
# This does not increase the startup time.
zgenom autoupdate

if ! zgenom saved; then
  echo "Creating a zgenom save"

  # Declared here rather than with the functions above because only building the save needs it.
  # jandamm/zgenom-ext-eval used to be loaded for `zgenom eval`, which this replaced.
  autoload -Uz zgenom-eval-tool

  zgenom compdef

  zgenom load $ZDOTDIR/plugins/ssh.zsh
  zgenom load $ZDOTDIR/plugins/atuin-history-substring-search.zsh

  # sed replaces the hardcoded versioned path with the 'starship' command, so upgrading starship via
  # mise does not break the prompt
  zgenom eval-tool starship 'starship init zsh | sed "s|$HOME/.local/share/mise/installs/starship/[^/]*/starship|starship|g"'

  # zsh plugins
  zgenom load zdharma-continuum/fast-syntax-highlighting
  zgenom load zsh-users/zsh-autosuggestions
  zgenom load djui/alias-tips
  zgenom load so-fancy/diff-so-fancy
  zgenom load junegunn/fzf-git.sh
  zgenom ohmyzsh plugins/timer
  zgenom load atuinsh/atuin

  # custom extensions
  #
  # Sourced at every startup, so only what has to be in place before the first prompt belongs here.
  zgenom eval-tool direnv direnv hook zsh
  zgenom eval-tool jump jump shell
  zgenom eval-tool switcher 'switcher init zsh; echo compdef switch=switcher'
  # --no-completions leaves out the half generated as a completion below, so this is cm_report and
  # the hooks
  zgenom eval-tool cm cm shell-init zsh --no-completions
  # Sourced rather than generated as a completion because its output registers itself for kitten and
  # clone-in-kitty as well as kitty, which only happens if it runs. It is 15 lines.
  zgenom eval-tool kitty kitty + complete setup zsh

  # NOTE: This must be done after bindkey -v in options.zsh to ensure fzf completion works
  zgenom eval-tool fzf 'fzf --zsh; echo compdef _gnu_generic fzf'

  # Completions, which go in $fpath rather than being sourced, so compinit loads one when its
  # command is first completed instead of every shell paying to define it.
  zgenom eval-tool --completion mise mise completion zsh
  zgenom eval-tool --completion atuin atuin gen-completions --shell zsh
  zgenom eval-tool --completion hubble hubble completion zsh
  zgenom eval-tool --completion cm cm completions zsh
  zgenom eval-tool --completion crc crc completion zsh

  # generate the init script from plugins above
  zgenom save
fi
