# Mostly copied from
# https://github.com/sorin-ionescu/prezto/blob/7b3b798eb5038eb05938399f245fa643c630a7f1/modules/ssh/init.zsh
# and adapted slightly with some logic also borrowed from
# https://github.com/ohmyzsh/ohmyzsh/blob/beadd56dd75e8a40fe0a7d4a5d63ed5bf9efcd48/plugins/ssh-agent/ssh-agent.plugin.zsh
#
# changes:
# - Automatically load default keys if no identities were set via zstyle
# - Change the zstyle namespace to my own
#
# Provides for an easier use of SSH by setting up ssh-agent.
# Copyright (c) 2009-2011 Robby Russell and contributors
# Copyright (c) 2011-2017 Sorin Ionescu and contributors

# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do
# so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE

# Return if requirements are not found.
if (( ! $+commands[ssh-agent] )); then
  return 1
fi

# Set the path to the SSH directory.
_ssh_dir="$HOME/.ssh"

# Set the path to the environment file if not set by another module.
_ssh_agent_env="${_ssh_agent_env:-${XDG_CACHE_HOME:-$HOME/.cache}/ssh/ssh-agent.env}"

# Set the path to the persistent authentication socket if not set by another module.
_ssh_agent_sock="${_ssh_agent_sock:-${XDG_CACHE_HOME:-$HOME/.cache}/ssh/ssh-agent.sock}"

# Start ssh-agent if not started.
if [[ ! -S "$SSH_AUTH_SOCK" ]]; then
  # Export environment variables.
  source "$_ssh_agent_env" 2> /dev/null

  # Start ssh-agent if not started.
  if ! ps -U "$LOGNAME" -o pid,ucomm | grep -q -- "${SSH_AGENT_PID:--1} ssh-agent"; then
    mkdir -p "$_ssh_agent_env:h"
    eval "$(ssh-agent | sed '/^echo /d' | tee "$_ssh_agent_env")"
  fi
fi

# Create a persistent SSH authentication socket.
if [[ -S "$SSH_AUTH_SOCK" && "$SSH_AUTH_SOCK" != "$_ssh_agent_sock" ]]; then
  mkdir -p "$_ssh_agent_sock:h"
  ln -sf "$SSH_AUTH_SOCK" "$_ssh_agent_sock"
  export SSH_AUTH_SOCK="$_ssh_agent_sock"
fi

# Clean up.
unset _ssh_{dir,identities} _ssh_agent_{env,sock}
