#!/usr/bin/env zsh

# install zgenom
[[ ! -d $ZGEN_INSTALL_DIR ]] && git clone https://github.com/jandamm/zgenom $ZGEN_INSTALL_DIR

# load zgenom only after fpath is set, as it runs compinit
source "$XDG_DATA_HOME/zgenom/zgenom.zsh"

# ohmyzsh compinit dump location
export ZSH_COMPDUMP=$ZDOTDIR/.zcompdump
# ZGENOM compinit dump location
export ZGEN_CUSTOM_COMPDUMP=$ZDOTDIR/.zcompdump

# zsh-load-completion is used by the completion stubs in $ZDOTDIR/completions, so these have to be
# declared on every startup and not just while building the save below.
autoload -Uz zsh-load-completion zsh-refresh-integration zsh-tool-changed-since

# Shell integrations snapshotted below, as the name of the snapshot and the command that generates
# it. Kept as data so the command that took a snapshot can also regenerate it, and read by name at
# each call site rather than looped over, because the order these are loaded in is the order they
# appear in below.
typeset -A _zsh_integrations=(
  direnv   'direnv hook zsh'
  jump     'jump shell'
  switcher 'switcher init zsh; echo compdef switch=switcher'
  # --no-completions leaves out the half that _cm generates on demand, so this is cm_report and
  # the hooks
  cm       'cm shell-init zsh --no-completions'
  fzf      'fzf --zsh; echo compdef _gnu_generic fzf'
  # sed replaces the hardcoded versioned path with the 'starship' command, so upgrading starship
  # via mise does not break the prompt
  starship 'starship init zsh | sed "s|$HOME/.local/share/mise/installs/starship/[^/]*/starship|starship|g"'
)

# Unlike a completion, this output has to be in place before the first prompt, so it cannot wait
# for something to ask for it. Rewrite any snapshot whose tool has been upgraded since it was
# taken, before `zgenom saved` sources them below. Costs a couple of builtin file tests per entry
# and runs a tool only when one of them reports a change.
for _zsh_name in ${(k)_zsh_integrations}; do
  zsh-refresh-integration $_zsh_name
done
unset _zsh_name

# Check for plugin and zgenom updates every 7 days
# This does not increase the startup time.
zgenom autoupdate

if ! zgenom saved; then
  echo "Creating a zgenom save"

  # extensions
  zgenom load jandamm/zgenom-ext-eval

  # Wraps `zgenom eval` with the generator named in $_zsh_integrations. Declared here rather than
  # with the functions above because only building the save needs it.
  autoload -Uz zsh-eval-integration

  zgenom compdef

  zgenom load $ZDOTDIR/plugins/ssh.zsh
  zgenom load $ZDOTDIR/plugins/atuin-history-substring-search.zsh

  zsh-eval-integration starship

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
  # Only integrations that have to be in place before the first prompt belong here. A tool whose
  # output is only a completion function has a stub in $ZDOTDIR/completions instead, which reruns
  # the generator itself once it notices the tool has changed.
  zsh-eval-integration direnv
  zsh-eval-integration jump
  zsh-eval-integration switcher
  zsh-eval-integration cm

  # NOTE: This must be done after bindkey -v in options.zsh to ensure fzf completion works
  zsh-eval-integration fzf

  # Fill the completion caches those stubs read, at the same point the snapshots above are taken,
  # so the first completion of a command in a new shell never has to wait for its tool. Sourcing a
  # stub while warming runs only its generator, and each one skips the work if its cache is
  # already current, which is why this is not repeated on every startup.
  _zsh_completion_warm=1
  # `-` so the file test follows symlinks: these are symlinked in from the dotfiles repo.
  for _zsh_completion_stub in $ZDOTDIR/completions/_*(N-.); do
    source $_zsh_completion_stub
  done
  unset _zsh_completion_warm _zsh_completion_stub

  # generate the init script from plugins above
  zgenom save
fi

unset _zsh_integrations
