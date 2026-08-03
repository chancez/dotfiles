#!/usr/bin/env zsh

# Load kitty's shell integration by hand.
#
# kitty normally injects this by rewriting ZDOTDIR for the process it spawns, but
# our windows run `zmx attach`, so the rewrite lands on the client rather than a
# shell. The shell that ends up on screen is started later by the zmx daemon,
# which kitty never touched, so the automatic path never reaches it.
#
# KITTY_INSTALLATION_DIR is a static path to the app bundle, so unlike
# KITTY_LISTEN_ON or KITTY_WINDOW_ID it stays correct across kitty restarts and
# is safe to rely on from a session that outlives the kitty that created it.
#
# no-title because title.zsh sets the title itself, matching the option already
# passed to shell_integration in kitty.conf.
#
# The payoff beyond completions is OSC 7: zmx tracks the session's cwd from it, so
# `zmx list` reports where a session actually is, and kitty resolves --cwd=current
# correctly when opening a new split.
if [[ -n $KITTY_INSTALLATION_DIR ]]; then
  export KITTY_SHELL_INTEGRATION="enabled no-title"
  autoload -Uz -- "$KITTY_INSTALLATION_DIR"/shell-integration/zsh/kitty-integration
  kitty-integration
  unfunction kitty-integration
fi
