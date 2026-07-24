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

# Mason cannot install clangd on Linux aarch64
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

# Put mise + its shims on PATH (matching how the real machine uses shims, not `mise activate`),
# and point mise at the in-repo config for the whole build. On a fresh machine ~/.config/mise
# does not exist yet; the dotfiles step below symlinks it into place, but until then mise needs
# to be told where the config lives.
ENV PATH="/home/chance/.local/bin:/home/chance/.local/share/mise/shims:${PATH}"
ENV MISE_GLOBAL_CONFIG_FILE="/home/chance/.dotfiles/mise/.config/mise/config.toml"

# Hack to make nvim mason use local clangd
# https://github.com/mason-org/mason.nvim/issues/1578
RUN \
    mkdir -p ~/.local/share/nvim/mason/packages/clangd/mason-schemas && \
    curl https://raw.githubusercontent.com/clangd/vscode-clangd/master/package.json \
        | jq .contributes.configuration > ~/.local/share/nvim/mason/packages/clangd/mason-schemas/lsp.json && \
    echo '{"schema_version":"1.1","primary_source":{"type":"local"},"name":"clangd","links":{"share":{"mason-schemas/lsp/clangd.json":"mason-schemas/lsp.json"}}}' \
        > ~/.local/share/nvim/mason/packages/clangd/mason-receipt.json

# Trust github.com SSH host key
RUN mkdir -p -m 0700 ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts

# Cache warmer: copy only the mise config first and pre-install [tools]. This is purely a
# build-cache optimization -- it keeps the expensive tool install in its own layer so editing
# an unrelated dotfile doesn't trigger a full reinstall. `mise bootstrap` below is still the
# real driver; its tools step just converges to a no-op since these are already installed.
RUN mkdir -p /home/chance/.dotfiles
COPY --chown=chance:chance ./mise /home/chance/.dotfiles/mise
RUN \
  # SSH auth for cloning from github (private go modules)
  --mount=type=ssh,required=true,uid=999,gid=999 \
  # https://mise.jdx.dev/getting-started.html#github-api-rate-limiting
  --mount=type=secret,id=MISE_GITHUB_TOKEN,env=MISE_GITHUB_TOKEN \
  mise trust "$MISE_GLOBAL_CONFIG_FILE" && mise install

# Copy the full repo and run the whole bootstrap. This is the real machine-setup entrypoint:
# it applies dotfiles (the GNU Stow / setup.sh replacement), system packages, macOS defaults,
# and installs [tools] -- all in mise's defined order. Tools are already warmed above, so that
# step is a fast no-op. On Linux, config.macos.toml is not loaded (see .miserc.toml auto_env),
# so no brew/system packages are installed -- matching the pre-mise behavior.
COPY --chown=chance:chance . /home/chance/.dotfiles
RUN \
  --mount=type=ssh,required=true,uid=999,gid=999 \
  --mount=type=secret,id=MISE_GITHUB_TOKEN,env=MISE_GITHUB_TOKEN \
  mise trust "$MISE_GLOBAL_CONFIG_FILE" && \
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

# Install LSP servers
RUN --mount=type=ssh,required=true,uid=999,gid=999 \
  # Mason LSP installation
  nvim --headless -c "MasonInstallAll" -c qall

ENV DEVCONTAINER=devctr
ENTRYPOINT ["/bin/zsh", "--login", "--interactive"]
