#!/bin/bash
# .config/hypr/scripts/now-playing.sh

MAX_CHARS=60
DISPLAY_CHARS=30

if playerctl status 2>/dev/null | grep -q Playing; then

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

    title="$(playerctl metadata --format '{{ title }}')"
    artist="$(playerctl metadata --format '{{ artist }}')"

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
fi
