# syntax=docker/dockerfile:1
FROM ubuntu:22.04

# ARG is only set at build time, ENV persists to runtime
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Los_Angeles

RUN apt update -y

# Utilities to always install
RUN apt install -y gpg wget curl tcpdump jq git unzip net-tools sudo coreutils file

# Utilities and tools for development (stow is gone: dotfiles are managed by mise now)
RUN apt install -y zsh

# clangd publishes no linux-arm64 release, and llvm/llvm-project only offers it inside the
# full 1.8G toolchain tarball, so arm64 builds take clangd from apt and tell mise to skip its
# own clangd. On amd64 the mise shim shadows this one, which is why it is unconditional.
RUN apt install -y clangd

# For python to be built via mise pyenv
# https://github.com/pyenv/pyenv/wiki#suggested-build-environment
RUN apt install -y make build-essential libssl-dev zlib1g-dev \
      libbz2-dev libreadline-dev libsqlite3-dev curl git \
      libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

# Configure locales
RUN apt install -y locales && locale-gen en_US.UTF-8 && dpkg-reconfigure locales

# Setup my user
RUN useradd -r -s /bin/zsh chance --create-home --uid 999

# Add user to sudoers with no password prompt
RUN echo "chance ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER chance

WORKDIR /home/chance

# Install mise
RUN curl https://mise.run | sh && ~/.local/bin/mise --version

# Put mise + its shims on PATH (matching how the real machine uses shims, not `mise activate`).
ENV PATH="/home/chance/.local/bin:/home/chance/.local/share/mise/shims:${PATH}"

# Let mise skip its own clangd on arm64, where the apt clangd above is the only one available.
# Without this, `mise install` fails: there is no matching release asset. conf.d is untouched
# by `mise dotfiles apply`, which links config.toml and its siblings only, so this survives
# bootstrap and keeps applying to mise inside the running container.
RUN if [ "$(uname -m)" = "aarch64" ]; then \
      mkdir -p ~/.config/mise/conf.d && \
      printf '[settings]\ndisable_tools = ["github:clangd/clangd"]\n' \
        > ~/.config/mise/conf.d/no-clangd.toml; \
    fi

# Trust github.com SSH host key
RUN mkdir -p -m 0700 ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts

# Cache warmer: copy only the mise config first and pre-install [tools]. This is purely a
# build-cache optimization -- it keeps the expensive tool install in its own layer so editing
# an unrelated dotfile doesn't trigger a full reinstall. `mise bootstrap` below is still the
# real driver; its tools step just converges to a no-op since these are already installed.
RUN mkdir -p /home/chance/.dotfiles
COPY --chown=chance:chance ./mise /home/chance/.dotfiles/mise

# Link the config into mise's standard global location. Do NOT use MISE_GLOBAL_CONFIG_FILE:
# pointing at the config directly disables discovery of its platform siblings, so
# config.macos.toml / config.linux.toml (see .miserc.toml auto_env) would never load. The
# dotfiles step below converges these same links, so this is idempotent.
RUN mkdir -p ~/.config/mise && \
    ln -sf ~/.dotfiles/mise/.config/mise/config.toml       ~/.config/mise/config.toml && \
    ln -sf ~/.dotfiles/mise/.config/mise/config.linux.toml ~/.config/mise/config.linux.toml && \
    ln -sf ~/.dotfiles/mise/.config/mise/config.macos.toml ~/.config/mise/config.macos.toml && \
    mise trust ~/.config/mise/config.toml

RUN \
  # SSH auth for cloning from github (private go modules)
  --mount=type=ssh,required=true,uid=999,gid=999 \
  # https://mise.jdx.dev/getting-started.html#github-api-rate-limiting
  --mount=type=secret,id=MISE_GITHUB_TOKEN,env=MISE_GITHUB_TOKEN \
  mise install

# Copy the full repo and run the whole bootstrap. This is the real machine-setup entrypoint:
# it applies dotfiles (the GNU Stow / setup.sh replacement), system packages, macOS defaults,
# and installs [tools] -- all in mise's defined order. Tools are already warmed above, so that
# step is a fast no-op. On Linux, config.macos.toml is not loaded (see .miserc.toml auto_env),
# so no brew/system packages are installed -- matching the pre-mise behavior.
COPY --chown=chance:chance . /home/chance/.dotfiles
RUN \
  --mount=type=ssh,required=true,uid=999,gid=999 \
  --mount=type=secret,id=MISE_GITHUB_TOKEN,env=MISE_GITHUB_TOKEN \
  cd ~/.dotfiles && mise trust && \
    # Dry-run first for visibility into what bootstrap will do.
    mise bootstrap --dry-run && \
    mise bootstrap --yes && \
    # Fail the build if any dotfile is out of sync.
    mise dotfiles status --missing

# Start an interactive zsh login shell to bootstrap the zsh environment (which causes zgenom to install plugins/etc)
RUN --mount=type=ssh,required=true,uid=999 \
      zsh --login --interactive

# Use zsh for the rest of the commands
SHELL ["/bin/zsh", "--login", "--interactive", "-c"]

# Install nvim plugins
RUN --mount=type=ssh,required=true,uid=999,gid=999 \
  # Install nvim plugins
  nvim --headless "+Lazy! sync" +qa

# No separate LSP install step: the language servers are mise [tools], installed above.

ENV DEVCONTAINER=devctr
ENTRYPOINT ["/bin/zsh", "--login", "--interactive"]
