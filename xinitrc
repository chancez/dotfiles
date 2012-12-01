#!/bin/sh
#
# ~/.xinitrc
#
# Executed by startx (run your window manager from here)

#if [ -d /etc/X11/xinit/xinitrc.d ]; then
#  for f in /etc/X11/xinit/xinitrc.d/*; do
#    [ -x "$f" ] && . "$f"
#  done
#  unset f
#fi


#set the cursor
#xsetroot -cursor_name left_ptr
#sh ~/.fehbg &

[[ -f ~/.Xresources ]] && xrdb -merge ~/.Xresources

export DE=xmonad
export EDITOR="vim"
export TERMINAL="urxvt"

$DEFAULT_SESSION=xfce4-xmonad

case $1 in
xfce4-xmonad)
    exec startxfce4
    ;;
herbstluftwm)
    exec herbstluftwm -c $HOME/dotfiles/herbstluftwm/autostart
    ;;
*)
    exec $DEFAULT_SESSION
    ;;
esac

#/usr/bin/xscreensaver -no-splash &
