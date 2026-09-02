#!/usr/bin/env bash

MAX_CHARS=60       # Maximum length of title/artist
DISPLAY_CHARS=20   # Visible marquee width
SLEEP=0.15

last_text="No music"

while true; do
    STATUS=$(playerctl status 2>/dev/null)

    if [[ "$STATUS" == "Playing" ]]; then
        title="$(playerctl metadata --format '{{ title }}' 2>/dev/null)"
        artist="$(playerctl metadata --format '{{ artist }}' 2>/dev/null)"

        text="$title - $artist"

        # Limit the actual text length
        if [ "${#text}" -gt "$MAX_CHARS" ]; then
            text="${text:0:$((MAX_CHARS - 1))}…"
        fi

        last_text="$text"

        # Add enough spaces for the marquee window
        marquee="$text     "

        # Make sure the scrolling area is DISPLAY_CHARS wide
        while [ "${#marquee}" -lt "$DISPLAY_CHARS" ]; do
            marquee="$marquee "
        done

        len=${#marquee}

        pos=$(( $(date +%s%3N) / 150 % len ))
        output="${marquee:$pos}${marquee:0:$pos}"

        # Only show DISPLAY_CHARS characters
        output="${output:0:$DISPLAY_CHARS}"

        output=$(printf '%s' "$output" | sed 's/\\/\\\\/g; s/"/\\"/g')

        echo "{\"text\":\"♪  $output\",\"class\":\"playing\",\"tooltip\":false}"

    elif [[ "$STATUS" == "Paused" ]]; then
        output=$(printf '%s' "$last_text" | sed 's/\\/\\\\/g; s/"/\\"/g')

        echo "{\"text\":\"♪  $output\",\"class\":\"paused\",\"tooltip\":false}"

    else
        output=$(printf '%s' "$last_text" | sed 's/\\/\\\\/g; s/"/\\"/g')

        echo "{\"text\":\"♪  $output\",\"class\":\"stopped\",\"tooltip\":false}"
    fi

    sleep "$SLEEP"
done
