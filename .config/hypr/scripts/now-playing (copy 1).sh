#!/bin/bash
# .config/hypr/scripts/now-playing.sh

MAX_CHARS=60
DISPLAY_CHARS=30

# Find the currently playing player
PLAYER=""

while read -r p; do
    if [ "$(playerctl --player="$p" status 2>/dev/null)" = "Playing" ]; then
        PLAYER="$p"
        break
    fi
done < <(playerctl -l 2>/dev/null)

# Nothing is playing
[ -z "$PLAYER" ] && exit 0

# Output requested control
case "$1" in
    previous)
        echo "⟨"
        exit
        ;;
    pause)
        echo "⏸️"
        exit
        ;;
    next)
        echo "⟩"
        exit
        ;;
esac

title="$(playerctl --player="$PLAYER" metadata --format '{{ title }}' 2>/dev/null)"
artist="$(playerctl --player="$PLAYER" metadata --format '{{ artist }}' 2>/dev/null)"

text="$title - $artist"

# Truncate full text
if [ "${#text}" -gt "$MAX_CHARS" ]; then
    text="${text:0:$((MAX_CHARS - 1))}…"
fi

# Add spacing for marquee
text="$text     "

len=${#text}

# Don't scroll if text fits
if [ "$len" -le "$DISPLAY_CHARS" ]; then
    echo "♪  $text"
    exit
fi

# Marquee position
pos=$(( $(date +%s) % len ))

# Get visible portion
visible="${text:$pos:$DISPLAY_CHARS}"

# Wrap around to the beginning
if [ "${#visible}" -lt "$DISPLAY_CHARS" ]; then
    visible="$visible${text:0:$((DISPLAY_CHARS - ${#visible}))}"
fi

echo "♪  $visible"
