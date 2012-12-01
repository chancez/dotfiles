#!/bin/sh

xrdb -merge ~/.Xresources

export DE=herbstluftwm
export EDITOR="vim"
export TERM="terminator"
#export TERMINAL="urxvt"
#export TERMINAL="terminator"
xcompmgr -C &

$DEFAULT_SESSION=herbstluftwm

case $1 in
xfce4-xmonad)
    exec startxfce4
    ;;
herbstluftwm)
    exec herbstluftwm
    ;;
*)
    exec $DEFAULT_SESSION
    ;;
esac

/usr/bin/xscreensaver -no-splash &
