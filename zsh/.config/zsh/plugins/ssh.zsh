# Provides an ssh-agent to every shell.
#
# An inherited agent that answers is used as is: launchd's on macOS, or a forwarded one in an ssh
# session. A forwarded agent stays tied to its own connection, so two machines connected to the same
# host never fight over one. Otherwise every shell shares one agent on a fixed socket.

# Apple's ssh-add stores passphrases in the Keychain only when asked to. ssh and git do it through
# UseKeychain in ~/.ssh/config, which ssh-add does not read.
if [[ $OSTYPE == darwin* && $commands[ssh-add] == /usr/bin/ssh-add ]]; then
  ssh-add() { command ssh-add --apple-use-keychain "$@" }
fi

if (( ! $+commands[ssh-agent] )); then
  return 1
fi

# Probe rather than stat: a socket file outlives the agent that bound it. `ssh-add -l` exits 2 only
# when it cannot reach an agent.
_ssh_agent_alive() {
  [[ -S "$1" ]] || return 1
  SSH_AUTH_SOCK="$1" ssh-add -l > /dev/null 2>&1
  (( $? != 2 ))
}

if ! _ssh_agent_alive "$SSH_AUTH_SOCK"; then
  _ssh_agent_sock="${XDG_CACHE_HOME:-$HOME/.cache}/ssh/agent.sock"

  if ! _ssh_agent_alive "$_ssh_agent_sock"; then
    mkdir -p -m 700 "$_ssh_agent_sock:h"

    # Shells starting at once all get here. Only one process can bind the socket, so they end up
    # sharing one agent. A socket left by a dead agent, as after a reboot, blocks the bind and must be
    # removed first. The lock covers that: unlocked, one shell could remove the socket another just
    # bound, orphaning its agent.
    #
    # `zsystem flock` does not create the lock file, and a wedged holder only delays startup by 5s.
    (
      if zmodload zsh/system 2> /dev/null && zsystem supports flock 2> /dev/null; then
        : >> "$_ssh_agent_sock.lock"
        zsystem flock -t 5 "$_ssh_agent_sock.lock" 2> /dev/null
      fi
      _ssh_agent_alive "$_ssh_agent_sock" && exit 0
      rm -f "$_ssh_agent_sock"
      ssh-agent -a "$_ssh_agent_sock" > /dev/null
    )
  fi

  export SSH_AUTH_SOCK="$_ssh_agent_sock"
  unset SSH_AGENT_PID
fi

unfunction _ssh_agent_alive
unset _ssh_agent_sock
