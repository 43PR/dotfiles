#!/usr/bin/env bash
# Replace "random" with: fade, wipe, grow, outer, wave, center, any, random

img="$1"
[[ -f "$img" ]] || { echo "commands.sh: not a file: $img" >&2; exit 1; }

# awww handles GIFs natively and keeps them animated
awww img "$img" -t random --transition-duration 1

mkdir -p "$HOME/.cache/43pr"

# theme.py wants a still image, so use the first frame for animated formats
theme_img="$img"
case "${img,,}" in
    *.gif)
        frames="$HOME/.cache/43pr/gif-frames"
        mkdir -p "$frames"
        theme_img="$frames/$(basename "${img%.*}").png"
        if [[ ! -f "$theme_img" ]]; then
            convert "${img}[0]" "$theme_img" 2>>"$HOME/.cache/43pr/theme.log" \
                || theme_img="$img"   # fall back to the original on failure
        fi
        ;;
esac

setsid -f python3 "$HOME/.config/43pr/bin/theme.py" wallpaper "$theme_img" \
    >>"$HOME/.cache/43pr/theme.log" 2>&1