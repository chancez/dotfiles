autoload promptinit
promptinit

setopt prompt_subst

# Called right before a command runs
preexec_prompt () {
}

add-zsh-hook preexec preexec_prompt

# Called right before drawing a prompt.
precmd_prompt () {
    pspath="%F{green}%~%f"
    pshost="%F{$(hash_color $(hostname))}%m%f"
    psuser="%F{red}%n"

}


add-zsh-hook precmd precmd_prompt 

#TMOUT=1
#TRAPALRM () {
#    precmd_prompt
#    zle && zle reset-prompt
#}

function zle-line-init zle-keymap-select {
    VI_STATUS="${${KEYMAP/vicmd/c}/(main|viins)/i}"
    if [ "$VI_STATUS" = "i" ]; then
        arrow="%F{green}%(!.#.>)%f"
    else
        arrow="%F{red}%(!.#.>)%f"
    fi
    #zle reset-prompt
}
zle -N zle-line-init
zle -N zle-keymap-select

PROMPT='${psuser}%F{2}@%f${pshost}$(git_super_status)${arrow} '
#RPROMPT='${pspath}${psvcs}${keychain}${pstime}'
RPROMPT='${pspath}'

#EOF vim: ft=zsh
