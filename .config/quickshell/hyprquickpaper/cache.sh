#!/usr/bin/env bash

CONFIG="$1/config.json"

expand_home() {
    local path="$1"

    if [[ "$path" == '$HOME' ]]; then
        printf '%s\n' "$HOME"
    elif [[ "$path" == '$HOME/'* ]]; then
        printf '%s/%s\n' "$HOME" "${path#'$HOME/'}"
    else
        printf '%s\n' "$path"
    fi
}

wallpaper_path=$(expand_home "$(jq -r '.wallpaper_path' "$CONFIG")")
cache_path=$(expand_home "$(jq -r '.cache_path' "$CONFIG")")
cache_batch_size=$(jq -r '.cache_batch_size' "$CONFIG")

mkdir -p "$cache_path"

echo "Wallpaper path: $wallpaper_path"
echo "Cache path: $cache_path"

find "$wallpaper_path" -type f \( \
    -iname "*.jpg" -o \
    -iname "*.jpeg" -o \
    -iname "*.png" -o \
    -iname "*.webp" -o \
    -iname "*.gif" -o \
    -iname "*.mp4" -o \
    -iname "*.mkv" -o \
    -iname "*.webm" -o \
    -iname "*.mov" \
\) | while read -r img; do

    filename=$(basename "$img")
    out="$cache_path/$filename"

    case "${filename,,}" in
        *.mp4|*.mkv|*.webm|*.mov)
            prev="$out.preview.gif"
            if [[ ! -f "$prev" ]]; then
                echo "Generating preview for $filename"
                # first 3 s, 12 fps, 300px tall; written to .tmp then renamed so a
                # half-finished file is never picked up by the picker
                ffmpeg -nostdin -loglevel error -y -t 3 -i "$img" \
                    -vf "fps=12,scale=-2:300:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" \
                    -loop 0 -f gif "$prev.tmp" && mv "$prev.tmp" "$prev" &
                if (( cache_batch_size > 0 )); then
                    while (( $(jobs -rp | wc -l) >= cache_batch_size )); do
                        wait -n
                    done
                fi
            fi
            ;;
    esac

    if [[ -f "$out" ]]; then
        continue
    fi

    echo "Generating thumbnail for $filename"
    case "${filename,,}" in
        *.gif)
            # first frame only, kept as a single-frame GIF under the same name
            convert "${img}[0]" -thumbnail x500 -strip "gif:$out" &
            ;;
        *.mp4|*.mkv|*.webm|*.mov)
            # first frame as a JPEG, kept under the same name (Qt sniffs the real format)
            # -nostdin is required or ffmpeg swallows the file list from the pipe
            ffmpeg -nostdin -loglevel error -y -i "$img" -frames:v 1 \
                -vf "scale=-2:500" -f image2 -c:v mjpeg -q:v 4 "$out" &
            ;;
        *)
            convert "$img" -thumbnail x500 -strip -quality 85 "$out" &
            ;;
    esac

    if (( cache_batch_size > 0 )); then
        while (( $(jobs -rp | wc -l) >= cache_batch_size )); do
            wait -n
        done
    fi
done