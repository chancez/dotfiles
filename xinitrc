#!/bin/sh

/usr/bin/xscreensaver -no-splash &
xrdb -merge ~/.Xresources

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

