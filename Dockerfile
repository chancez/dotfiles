FROM ubuntu:22.04

# ARG is only set at build time, ENV persists to runtime
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Los_Angeles

RUN apt update -y

# Utilities to always install
RUN apt install -y gpg wget curl tcpdump jq git unzip net-tools sudo coreutils file

# Utilities and tools for development
RUN apt install -y zsh stow

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

COPY --chown=chance:chance . /home/chance/.dotfiles

# Configure dotfiles
RUN cd ~/.dotfiles && ./setup.sh

# Install tools
RUN \
  # SSH auth for cloning from github
  --mount=type=ssh,required=true,uid=999,gid=999 \
  # https://mise.jdx.dev/getting-started.html#github-api-rate-limiting
  --mount=type=secret,id=MISE_GITHUB_TOKEN,env=MISE_GITHUB_TOKEN \
  # Add mise to PATH for this command, as mise calls mise during install (eg: npm)
  PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH" \
  # Install all other tools
  ~/.local/bin/mise install

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
