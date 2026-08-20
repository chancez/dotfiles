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

`paths.zsh` is sourced once, from `.zshenv`, so every shell gets the same `$PATH`, including
non-interactive ones (`zsh -c ...`, git hooks, editor and agent subprocesses).

To make that work on macOS, `.zshenv` sets `NO_GLOBAL_RCS`. Otherwise `/etc/zprofile` runs
`path_helper` for login shells only, and only after `.zshenv`, hoisting the system
directories back to the front of `$PATH`. Instead `paths.zsh` reads the same inputs
`path_helper` does, `/etc/paths` plus `/etc/paths.d/*` (and the `manpaths` equivalents), in a
few lines of zsh, so `/etc/paths.d` drop-ins keep working with no subprocess. Login and
non-interactive shells then end up with an identical `$PATH`.

Skipping the global rc files also skips `/etc/zshrc`, so what it contributed lives here now:
`disable log` in `.zshenv`, since zsh's `log` builtin shadows `/usr/bin/log` in scripts too,
and `COMBINING_CHARS` in `options.zsh`, since it only affects line editing.

## Setup

```sh
git clone git@github.com:chancez/dotfiles.git ~/.dotfiles

# On a fresh machine ~/.config/mise/ doesn't exist yet. Link the config into mise's standard
# global location so it (and its platform siblings) are found. The dotfiles step converges
# these same links later, so this is idempotent.
#
# Don't use MISE_GLOBAL_CONFIG_FILE here: pointing mise at the config file directly disables
# discovery of config.macos.toml / config.linux.toml, so the platform split would be skipped.
mkdir -p ~/.config/mise
ln -sf ~/.dotfiles/mise/.config/mise/config.toml       ~/.config/mise/config.toml
ln -sf ~/.dotfiles/mise/.config/mise/config.macos.toml ~/.config/mise/config.macos.toml
ln -sf ~/.dotfiles/mise/.config/mise/config.linux.toml ~/.config/mise/config.linux.toml

cd ~/.dotfiles
mise trust
mise bootstrap --yes   # packages -> dotfiles -> macOS defaults -> installs [tools]
```

Preview first with `mise bootstrap plan`. Individual steps:

```sh
mise bootstrap dotfiles status          # verify everything is linked
mise bootstrap dotfiles apply           # symlink dotfiles (the old `stow` step)
mise bootstrap packages apply           # install brew/cask/mas system packages (macOS)
mise install                            # install [tools]
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
