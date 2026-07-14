#!/bin/bash

WALL_DIR="$HOME/Pictures/W"
STATE_FILE="$HOME/.cache/current_wallpaper"

# Wallpapers in order
walls=(
    "$WALL_DIR/w1.jpg"
    "$WALL_DIR/w2.jpg"
    "$WALL_DIR/w.png"
    "$WALL_DIR/w4.jpg"
    "$WALL_DIR/w3.jpg"
    "$WALL_DIR/w5.jpg"
    "$WALL_DIR/w6.jpg"
)

# Initialize state if missing
if [ ! -f "$STATE_FILE" ]; then
    echo 5 > "$STATE_FILE"   # start at w6
fi

current=$(cat "$STATE_FILE")

case "$1" in
    next)
        current=$(( (current + 1) % ${#walls[@]} ))
        ;;
    prev)
        current=$(( (current - 1 + ${#walls[@]}) % ${#walls[@]} ))
        ;;
esac

echo "$current" > "$STATE_FILE"

awww img "${walls[$current]}"
