#!/bin/bash

choice=$(printf "100%%\n90%%\n80%%\n70%%\n60%%\n50%%\n40%%" | rofi -dmenu -p "")

case "$choice" in
    "100%") opacity=1.0 ;;
    "90%")  opacity=0.9 ;;
    "80%")  opacity=0.8 ;;
    "70%")  opacity=0.7 ;;
    "60%")  opacity=0.6 ;;
    "50%")  opacity=0.5 ;;
    "40%")  opacity=0.4 ;;
    *) exit 0 ;;
esac

sed -i "s/^local window_opacity = .*/local window_opacity = $opacity/" ~/.config/hypr/rules.lua

hyprctl reload
