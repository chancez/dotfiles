#!/bin/bash

autoload -U add-zsh-hook
add-zsh-hook chpwd auto_source_virtualenv

function auto_source_virtualenv() {
    if [[ -e $PWD/bin/activate ]]; then
        source $PWD/bin/activate
    fi
}
