#!/bin/sh

/usr/bin/xscreensaver -no-splash &
xrdb -merge ~/.Xresources

xcompmgr -C &
xrandr --output VGA1 --off
xrandr --output VGA1 --auto --right-of LVDS1

export PATH=$PATH:~/bin

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

