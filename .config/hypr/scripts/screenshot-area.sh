#!/usr/bin/env bash
# ~/.config/hypr/scripts/screenshot-area.sh
# Save / clipboard options come from Settings > Keybinds > Screenshots
# (state/screenshot.conf). Missing file or keys default to on.
conf="$HOME/.config/quickshell/state/screenshot.conf"
[[ -r $conf ]] && . "$conf"

stamp="$(date +%F_%H-%M-%S).png"
if [[ ${shot_area_save:-1} == 1 ]]; then
    dir="$HOME/Pictures/Screenshots"
    mkdir -p "$dir"
    file="$dir/$stamp"
else
    file="/tmp/shot-$stamp"
fi

geom=$(slurp 2>/dev/null)
re='^-?[0-9]+,-?[0-9]+ [1-9][0-9]*x[1-9][0-9]*$'

# Esc gives empty output; a bare click gives a zero-size region
if [[ ! $geom =~ $re ]]; then
    qs ipc call screenshot cancelled
    exit 0
fi

if grim -g "$geom" "$file"; then
    [[ ${shot_area_clip:-1} == 1 ]] && wl-copy --type image/png < "$file"
    qs ipc call screenshot notify "$file"
else
    qs ipc call screenshot cancelled
fi
