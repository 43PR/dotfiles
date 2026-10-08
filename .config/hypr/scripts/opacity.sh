#!/bin/bash

choice=$(printf "100%%\n90%%\n80%%\n70%%\n60%%\n50%%\n40%%" | rofi -dmenu -p "")

case "$choice" in
    "100%") opacity=1.0; alpha=FF ;;
    "90%")  opacity=0.9; alpha=E6 ;;
    "80%")  opacity=0.8; alpha=CC ;;
    "70%")  opacity=0.7; alpha=B3 ;;
    "60%")  opacity=0.6; alpha=99 ;;
    "50%")  opacity=0.5; alpha=80 ;;
    "40%")  opacity=0.4; alpha=66 ;;
    *) exit 0 ;;
esac

sed -i --follow-symlinks "0,/opacity = \".* override\"/s//opacity = \"$opacity override\"/" ~/.config/hypr/rules.lua
sed -i -E "s/(property real bgAlpha: )[0-9.]+/\1$opacity/" ~/.config/quickshell/Theme.qml
sed -i -E "s/(bg:[[:space:]]*#[0-9A-Fa-f]{6})([0-9A-Fa-f]{2})?;/\1$alpha;/" ~/.config/rofi/colors.rasi

hyprctl reload

pkill qs
sleep 0.2
qs &
