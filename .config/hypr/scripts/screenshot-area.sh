#!/usr/bin/env bash
dir="$HOME/Pictures/Screenshots"
file="$dir/$(date +%F_%H-%M-%S).png"
mkdir -p "$dir"

geom=$(slurp 2>/dev/null)
re='^-?[0-9]+,-?[0-9]+ [1-9][0-9]*x[1-9][0-9]*$'

# Esc gives empty output; a bare click gives a zero-size region
if [[ ! $geom =~ $re ]]; then
    qs ipc call screenshot cancelled
    exit 0
fi

if grim -g "$geom" "$file"; then
    wl-copy --type image/png < "$file"
    qs ipc call screenshot notify "$file"
else
    qs ipc call screenshot cancelled
fi
