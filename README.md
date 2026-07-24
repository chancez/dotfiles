# dotfiles
My configs!

Managed entirely by [mise](https://mise.jdx.dev). Tools (`[tools]`), dotfile symlinks
(`[dotfiles]`), and macOS defaults (`[bootstrap.macos.*]`) live in
`mise/.config/mise/config.toml`; system packages (`[bootstrap.packages]`) live in the
platform files alongside it. This replaces the old GNU Stow + Brewfile setup.

System packages are split by platform. `config.macos.toml` holds all brew formulae, casks,
and Mac App Store apps and loads only on macOS. `config.linux.toml` is currently empty:
Linux hosts stay apt-managed as they were before, so this migration introduces no Homebrew
on Linux. The split works because `.miserc.toml` sets `auto_env = true`, which makes mise
auto-load platform config siblings (`config.macos.toml`, `config.linux.toml`, ...). To have
mise manage Linux packages later, populate `config.linux.toml` with `apt:` entries.

## Pre-requisites

- zsh
- [mise](https://mise.jdx.dev/getting-started.html) (`curl https://mise.run | sh`)

Shims are put on `$PATH` directly (via `zsh/.config/zsh/paths.zsh`); `mise activate` is not
used.

## Setup

```sh
git clone git@github.com:chancez/dotfiles.git ~/.dotfiles

# On a fresh machine ~/.config/mise/config.toml doesn't exist yet, so point mise at the
# in-repo config for the first run. The dotfiles step symlinks it into place; later runs
# don't need the env var.
export MISE_GLOBAL_CONFIG_FILE="$HOME/.dotfiles/mise/.config/mise/config.toml"
mise trust
mise bootstrap --yes   # packages -> dotfiles -> macOS defaults -> installs [tools]
```

Preview first with `mise bootstrap --dry-run`. Individual steps:

```sh
mise dotfiles apply                  # symlink dotfiles (the old `stow` step)
mise dotfiles status --missing       # verify everything is linked
mise bootstrap packages apply        # install brew/cask/mas system packages (macOS)
mise install                         # install [tools]
```

## Residual Homebrew

A small `brew/Brewfile` holds the few things mise's built-in Homebrew support can't do
(services, `link: false`, pkg/privileged casks). Apply it with:

```sh
brew bundle --file=~/.dotfiles/brew/Brewfile
```

## macOS defaults

Most `defaults write` settings are declarative under `[bootstrap.macos.*]` and applied by
`mise bootstrap`. The imperative leftovers (and a `killall` to apply them) are in
`macos-defaults-extras.sh`, run by the `post-defaults` bootstrap hook.
