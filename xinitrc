#!/bin/sh

xrdb -merge ~/.Xresources

xcompmgr -C &
xrandr --output VGA1 --off
xrandr --output VGA1 --auto --right-of LVDS1

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
