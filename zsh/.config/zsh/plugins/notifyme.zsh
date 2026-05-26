# Based on https://frantic.im/notify-on-completion/

# Script is only setup for MacOS
if [[ "$OSTYPE" != darwin* ]]; then
  return 1
fi

_notify_script="${_notify_script:-notify_cmd.applescript}"
_last_command_start_time=
_notification_threshold="${_notification_threshold:-10}" # seconds

_notifyme_preexec_hook() {
  _last_command_start_time=$(date +%s)
}

_notifyme_save_exit_code() {
  _last_exit_code=$?
}

_notifyme_postcmd_hook() {
  if [[ -z "$_last_command_start_time" ]]; then
    return
  fi

  local exit_code=$_last_exit_code
  local last_cmd=$(fc -ln -1)

  # Only notify if the command took longer than the threshold
  local current_time=$(date +%s)
  local elapsed_time=$((current_time - _last_command_start_time))

  if (( elapsed_time < _notification_threshold )); then
    return
  fi

  # Run the notification in the background to avoid blocking the shell
  # Send script output to dev null and run it in the background to avoid
  # blocking the shell.
  # Wrap in a subshell to avoid printing the job info to the terminal.
  ("${_notify_script}" "$last_cmd" "$exit_code" >/dev/null 2>&1 &)
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _notifyme_preexec_hook
# Insert at the beginning of precmd_functions so it runs before any other
# precmd hooks and captures $? before they can clobber it.
precmd_functions=(_notifyme_save_exit_code $precmd_functions)
add-zsh-hook precmd _notifyme_postcmd_hook
