#!/usr/bin/env bash
# Usage: commands.sh <wallpaper-file> [transition] [duration-seconds]
# transition: fade, wipe, grow, outer, wave, center, any, random (default: outer)
# Both optional arguments are passed in by the wallpaper picker's settings menu.

img="$1"
transition="${2:-outer}"
duration="${3:-1}"

case "$transition" in
    fade|wipe|grow|outer|wave|center|any|random) ;;
    *) transition=outer ;;
esac
[[ "$duration" =~ ^[0-9]+([.][0-9]+)?$ ]] || duration=1

[[ -f "$img" ]] || { echo "commands.sh: not a file: $img" >&2; exit 1; }

mkdir -p "$HOME/.cache/43pr"
frames="$HOME/.cache/43pr/gif-frames"
theme_img="$img"

case "${img,,}" in
    *.mp4|*.mkv|*.webm|*.mov)
        # grab the first frame (used for the awww transition and for theme.py)
        mkdir -p "$frames"
        theme_img="$frames/$(basename "${img%.*}").png"
        if [[ ! -f "$theme_img" ]]; then
            ffmpeg -nostdin -loglevel error -y -i "$img" -frames:v 1 "$theme_img" \
                2>>"$HOME/.cache/43pr/theme.log" || theme_img=""
        fi

        # mpvpaper can't do transitions, so stop the old one, let awww animate
        # to the video's first frame, then start mpvpaper on top once it's done
        pkill -x mpvpaper
        if [[ -n "$theme_img" ]]; then
            awww img "$theme_img" -t "$transition" --transition-duration "$duration"
            sleep "$duration"
        fi
        setsid -f mpvpaper -o "no-audio loop hwdec=auto --panscan=1.0" '*' "$img" \
            >>"$HOME/.cache/43pr/mpvpaper.log" 2>&1
        echo "$img" > "$HOME/.cache/43pr/last-live"
        ;;
    *)
        # static/GIF wallpaper: stop any live wallpaper so it doesn't cover awww
        pkill -x mpvpaper
        rm -f "$HOME/.cache/43pr/last-live"

        # awww handles GIFs natively and keeps them animated
        awww img "$img" -t "$transition" --transition-duration "$duration"

        # theme.py wants a still image, so use the first frame for animated formats
        case "${img,,}" in
            *.gif)
                mkdir -p "$frames"
                theme_img="$frames/$(basename "${img%.*}").png"
                if [[ ! -f "$theme_img" ]]; then
                    convert "${img}[0]" "$theme_img" 2>>"$HOME/.cache/43pr/theme.log" \
                        || theme_img="$img"   # fall back to the original on failure
                fi
                ;;
        esac
        ;;
esac

[[ -n "$theme_img" && -f "$theme_img" ]] || exit 0

# run theme.py, then make open GTK apps (Thunar etc.) reload the new colors
setsid -f bash -c '
    python3 "$HOME/.config/43pr/bin/theme.py" wallpaper "$1"
    "$HOME/.config/43pr/bin/reload-gtk.sh"
' _ "$theme_img" >>"$HOME/.cache/43pr/theme.log" 2>&1