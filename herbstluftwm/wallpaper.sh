#!/bin/sh
killall wallpaper.sh
while true; do
    find -L ~/Pictures/wallpapers/ -type f \( -name '*.jpg' -o -name '*.png' \) -print0 |
        shuf -n1 -z | xargs -0 feh --bg-max
    sleep 5m
done
