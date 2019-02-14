copy-to-pbcopy() {
    zle kill-buffer
    print -rn -- $CUTBUFFER | pbcopy
}; zle -N copy-to-pbcopy

bindkey -M viins "^]" copy-to-pbcopy
