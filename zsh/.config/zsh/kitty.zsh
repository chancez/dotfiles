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
