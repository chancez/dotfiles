# useful for path editing -- backward-delete-word, but with / as additional delimiter
backward-delete-to-slash () {
  local WORDCHARS=${WORDCHARS//\//}
    zle .backward-delete-word
    }
    zle -N backward-delete-to-slash

