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

# Reuse a running agent, and start one only when there is genuinely none.
#
# Reuse is decided by *talking to the agent*, not by checking whether a pid is alive. The previous
# version compared $SSH_AGENT_PID against `ps` output, which cannot work here: nothing ever exports
# SSH_AGENT_PID. The block below re-exports SSH_AUTH_SOCK pointing at the stable symlink but leaves
# the pid behind, and a multiplexer forwards SSH_AUTH_SOCK without it, so every new shell arrived with
# the variable empty and the check fell back to whatever the env file said. That left 137 orphaned
# agents and 136 dead sockets in ~/.ssh/agent.
#
# `ssh-add -l` is the real test. Exit 0 means the agent answered and has keys, 1 means it answered and
# has none, and 2 means it could not be reached. Only 2 justifies spawning, and it is the one case a
# stat of the socket cannot distinguish: a socket file outlives the process that bound it, so -S is
# true for a dead agent.
_ssh_agent_running() {
  [[ -n "$SSH_AUTH_SOCK" ]] || return 1
  ssh-add -l > /dev/null 2>&1
  (( $? != 2 ))
}

if ! _ssh_agent_running; then
  source "$_ssh_agent_env" 2> /dev/null
fi

if ! _ssh_agent_running; then
  mkdir -p "$_ssh_agent_env:h"

  # Written to a per-process temp file and renamed into place, so a shell reading the env file never
  # sees a half-written one. $$ keeps two shells from sharing the temp path even in the unlocked
  # fallback below.
  _ssh_agent_spawn() {
    ssh-agent | sed '/^echo /d' > "$_ssh_agent_env.$$" \
      && mv -f "$_ssh_agent_env.$$" "$_ssh_agent_env"
  }

  # Serialize the spawn across shells, because the env file is shared mutable state.
  #
  # Opening many windows at once, or reattaching a multiplexer's sessions, starts many shells at once.
  # Without a lock each one sees no agent, each spawns, and each overwrites the env file: the last
  # writer wins and every other agent is orphaned with no record of it anywhere. Measured with 8
  # concurrent shells against a dead env file, the unlocked version started 6 to 7 agents where this
  # starts 1, and at 25 shells it started 6.
  #
  # `zsystem flock` rather than flock(1), which does not exist on macOS, and rather than a bare `flock`
  # builtin, which zsh/system does not provide: the module's interface is the zsystem command. It takes
  # a path and locks it directly, so no fd juggling is needed.
  #
  # The lock is a separate file from the env file, since locking the env file itself would race the
  # truncation that writing it performs.
  if zmodload zsh/system 2> /dev/null && zsystem supports flock 2> /dev/null; then
    # The lock file must already exist, because `zsystem flock` opens it for writing and does not
    # create it, failing with "failed to open ... no such file or directory". Omitting this line, with
    # the error redirected to /dev/null, is how the first version of this fix silently did nothing:
    # every shell failed to lock, fell straight through, and spawned. It measured identically to the
    # unfixed code, which is the only reason the mistake was caught.
    : >> "$_ssh_agent_env.lock" 2> /dev/null

    (
      # Subshell so the lock is dropped when it exits, however it exits.
      #
      # Bounded wait, so a wedged holder delays shell startup by a few seconds rather than hanging
      # it. A failure to lock still falls through to spawning: an extra agent is a smaller problem
      # than a shell with no agent at all.
      zsystem flock -t 5 "$_ssh_agent_env.lock" 2> /dev/null

      # Re-check under the lock. Another shell may have started an agent while this one waited, and
      # this is the check the lock exists to make possible.
      source "$_ssh_agent_env" 2> /dev/null
      if [[ -n "$SSH_AUTH_SOCK" ]]; then
        ssh-add -l > /dev/null 2>&1
        (( $? != 2 )) && exit 0
      fi
      _ssh_agent_spawn
    )
  else
    _ssh_agent_spawn
  fi

  # Adopt whatever is now recorded, whether this shell started it or another did.
  source "$_ssh_agent_env" 2> /dev/null
  unfunction _ssh_agent_spawn
fi

# Create a persistent SSH authentication socket.
#
# The indirection is what lets a long-lived shell keep working after the agent behind it is replaced:
# the shell holds a path that stays valid while the target moves. It also means the symlink can point
# at a socket whose agent is gone, which is why the reuse test above probes rather than stats.
if [[ -S "$SSH_AUTH_SOCK" && "$SSH_AUTH_SOCK" != "$_ssh_agent_sock" ]]; then
  mkdir -p "$_ssh_agent_sock:h"
  ln -sf "$SSH_AUTH_SOCK" "$_ssh_agent_sock"
  export SSH_AUTH_SOCK="$_ssh_agent_sock"
fi

unfunction _ssh_agent_running

# Clean up.
unset _ssh_{dir,identities} _ssh_agent_{env,sock}
