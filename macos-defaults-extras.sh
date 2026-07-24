#!/bin/zsh
# Imperative macOS setup that doesn't fit mise's declarative [bootstrap.macos.defaults].
# Run by the [bootstrap.hooks.post-defaults] hook in mise/.config/mise/config.toml, right
# after mise writes the `defaults` entries. The bulk of the old macos-defaults.sh now lives
# there; only the pieces below need real commands.
set -e

# No-op on non-macOS (the hook also runs in the Linux container).
[[ "$OSTYPE" == darwin* ]] || exit 0

set -x

# Show the ~/Library folder (not a `defaults write`).
chflags nohidden ~/Library

# Screenshots go to ~/screenshots; the dir must exist and the path needs $HOME expansion.
mkdir -p "$HOME/screenshots"
defaults write com.apple.screencapture location -string "$HOME/screenshots"

# Apply the defaults written this run by restarting the affected apps.
killall Finder Dock SystemUIServer 2>/dev/null || true
