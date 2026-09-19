#!/usr/bin/env zsh

# Load kitty's shell integration by hand.
#
# kitty normally injects this by rewriting ZDOTDIR for the process it spawns, but
# our windows run `cm attach`, so the rewrite lands on the client rather than a
# shell. The shell that ends up on screen is started later by the cm server,
# which kitty never touched, so the automatic path never reaches it.
#
# KITTY_INSTALLATION_DIR is a static path to the app bundle, so unlike
# KITTY_LISTEN_ON or KITTY_WINDOW_ID it stays correct across kitty restarts and
# is safe to rely on from a session that outlives the kitty that created it.
# `cm get-env` refreshes the ones that do go stale.
#
# no-title because title.zsh sets the title itself, matching the option already
# passed to shell_integration in kitty.conf.
#
# This is load-bearing for more than completions. cm reads two things out of what
# the integration emits: OSC 7, so `cm list` reports where a session actually is
# and a new split opens in the right place; and OSC 133, so cm knows whether a
# command is running, which is what makes the close confirmation meaningful.
# Without this block both silently degrade rather than fail.
if [[ -n $KITTY_INSTALLATION_DIR ]]; then
  export KITTY_SHELL_INTEGRATION="enabled no-title"
  autoload -Uz -- "$KITTY_INSTALLATION_DIR"/shell-integration/zsh/kitty-integration
  kitty-integration
  unfunction kitty-integration
fi

# Apply the refresh the comment above describes, rather than only naming it.
#
# A session outlives the kitty that created it, and the variables describing that kitty were captured in
# this shell's environment once. After a kitty restart a resumed session still holds the dead kitty's
# KITTY_PID, KITTY_WINDOW_ID and KITTY_LISTEN_ON, so anything that talks to kitty from inside the session
# fails. The sharp case, whose error names neither cm nor kitty and so reads as an ssh problem:
#
#   $ kitten ssh white
#   Incorrect request id: 4698-132, expecting the KITTY_PID-KITTY_WINDOW_ID for the current kitty window
#   Shared connection to white.chancez.xyz closed.
#
# Nothing outside a process can change its environment, so the shell has to ask: cm records what the most
# recent client had and `cm get-env` prints it.
#
# Gated on the recorded kitty being gone, which is what makes this affordable. kill is a zsh builtin, so
# the common case costs no fork and no subshell, while `cm get-env` costs about 23ms and would be wasted
# on every prompt of every session otherwise.
#
# _cm_kitty_checked prevents a retry on every command when cm has nothing newer to give, which is the
# state of a session whose most recent client really was the kitty that died. The pid then stays dead and
# equal to the one already tried, so this does nothing until it changes.
#
# preexec rather than precmd, which matters for the case that motivated it. Reattaching does not draw a new
# prompt -- cm restores the screen instead -- so precmd would not have run by the time the first command is
# typed, and `kitten ssh` straight after a kitty restart would still fail. preexec runs after Enter and
# before the command is spawned, so the child inherits the refreshed values.
#
# Not hooked to the resize signal, which is the other moment a reattach is visible: TRAPWINCH belongs to
# title.zsh, whose comment records that a nonzero return from it silently empties whatever command
# substitution it interrupted. Extending it to save a keystroke is not worth reopening that.
autoload -Uz add-zsh-hook
_cm_kitty_env_refresh() {
  [[ -n $CM_SESSION && -n $KITTY_PID ]] || return 0
  kill -0 $KITTY_PID 2>/dev/null && return 0
  [[ $KITTY_PID == ${_cm_kitty_checked-} ]] && return 0
  typeset -g _cm_kitty_checked=$KITTY_PID
  eval "$(command cm get-env "$CM_SESSION" --format=posix 2>/dev/null)"
  return 0
}
add-zsh-hook preexec _cm_kitty_env_refresh
