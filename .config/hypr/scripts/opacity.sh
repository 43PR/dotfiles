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
sed -i -E "s/(bg:[[:space:]]*#[0-9A-Fa-f]{6})([0-9A-Fa-f]{2})?;/\1$alpha;/" ~/.config/rofi/colors.rasi

hyprctl reload

# Quickshell: change the running instance live (no restart, no Theme.qml edit).
# Theme saves the value to hub.json itself.
if ! qs ipc call theme setBgAlpha "$opacity" >/dev/null 2>&1; then
    # Quickshell isn't running (or doesn't have the handler yet): save the value for the
    # next start, then start it.
    state="$HOME/.config/quickshell/state/hub.json"
    mkdir -p "$(dirname "$state")"
    if command -v jq >/dev/null 2>&1; then
        tmp=$(mktemp)
        if [ -s "$state" ]; then
            jq --argjson a "$opacity" '.bgAlpha = $a' "$state" > "$tmp"
        else
            jq -n --argjson a "$opacity" '{bgAlpha: $a}' > "$tmp"
        fi && mv "$tmp" "$state" || rm -f "$tmp"
    else
        # no jq: this overwrites the other Hub settings in the file
        printf '{"bgAlpha": %s}\n' "$opacity" > "$state"
    fi
    setsid qs >/dev/null 2>&1 &
fi
