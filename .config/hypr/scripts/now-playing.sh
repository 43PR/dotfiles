#!/bin/bash
# now-playing.sh

MAX_CHARS=40

if playerctl status 2>/dev/null | grep -q Playing; then
    title="$(playerctl metadata --format '{{ title }}')"
    artist="$(playerctl metadata --format '{{ artist }}')"

    text="$title - $artist"

    # Truncate long titles/artists
    if [ "${#text}" -gt "$MAX_CHARS" ]; then
        text="${text:0:$((MAX_CHARS - 1))}…"
    fi

    # Add spacing for the scrolling effect
    text="$text     "

    len=${#text}
    pos=$(( $(date +%s) % len ))

    echo "♪  ${text:$pos}${text:0:$pos}"
fi
