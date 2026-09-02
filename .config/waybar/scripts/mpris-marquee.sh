
#!/usr/bin/env bash

MAX_CHARS=60
DISPLAY_CHARS=20
SLEEP=0.5

last_text=""

while true; do
    STATUS=$(playerctl status 2>/dev/null)

    if [[ "$STATUS" == "Playing" ]]; then
        title="$(playerctl metadata --format '{{ title }}' 2>/dev/null)"
        artist="$(playerctl metadata --format '{{ artist }}' 2>/dev/null)"

        text="$title - $artist"

        # Limit actual text length
        if [[ ${#text} -gt $MAX_CHARS ]]; then
            text="${text:0:$((MAX_CHARS - 1))}…"
        fi

        last_text="$text"

        # Add spacing so the end loops cleanly into the beginning
        marquee="$text     "

        while [[ ${#marquee} -lt $DISPLAY_CHARS ]]; do
            marquee+=" "
        done

        len=${#marquee}

        # Smoothly advance the marquee
        pos=$(( $(date +%s%3N) / 150 % len ))

        output="${marquee:$pos}${marquee:0:$pos}"
        output="${output:0:$DISPLAY_CHARS}"

        jq -cn \
            --arg text "♪  $output" \
            --arg class "playing" \
            --arg tooltip "$text" \
            '{text:$text, class:$class, tooltip:$tooltip}'

    elif [[ "$STATUS" == "Paused" ]]; then

        jq -cn \
            --arg text "♪  $last_text" \
            --arg class "paused" \
            --arg tooltip "$last_text" \
            '{text:$text, class:$class, tooltip:$tooltip}'

    else

        jq -cn \
            --arg text "♪  $last_text" \
            --arg class "stopped" \
            --arg tooltip "$last_text" \
            '{text:$text, class:$class, tooltip:$tooltip}'
    fi

    sleep "$SLEEP"
done

