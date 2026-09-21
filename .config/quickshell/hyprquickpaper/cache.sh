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
    -iname "*.png" \
\) | while read -r img; do

    filename=$(basename "$img")
    out="$cache_path/$filename"

    if [[ -f "$out" ]]; then
        continue
    fi

    echo "Generating thumbnail for $filename"
    convert "$img" -thumbnail x500 -strip -quality 85 "$out" &

    if (( cache_batch_size > 0 )); then
        while (( $(jobs -rp | wc -l) >= cache_batch_size )); do
            wait -n
        done
    fi
done

wait
echo "Thumbnail generation complete."
