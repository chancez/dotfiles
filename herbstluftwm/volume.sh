#!/bin/bash

case $1 in
    down)
        amixer -q set Master 2%- unmute
        herbstclient emit_hook volume
        ;;
    up)
        amixer -q set Master 2%+ unmute
        herbstclient emit_hook volume
        ;;
    mute)
        amixer -q set Master toggle
        herbstclient emit_hook volume_toggle
        ;;
esac


