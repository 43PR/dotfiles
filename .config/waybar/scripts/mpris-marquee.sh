#!/usr/bin/env bash

MAX_CHARS=60
DISPLAY_CHARS=20
SLEEP=0.5

last_text=""
last_player=""

while true; do

    # Find the currently playing player
    PLAYER=""

    while read -r p; do
        if [[ "$(playerctl --player="$p" status 2>/dev/null)" == "Playing" ]]; then
            PLAYER="$p"
            break
        fi
    done < <(playerctl -l 2>/dev/null)

    # If something is playing, use that player
    if [[ -n "$PLAYER" ]]; then

        title="$(playerctl --player="$PLAYER" metadata --format '{{ title }}' 2>/dev/null)"
        artist="$(playerctl --player="$PLAYER" metadata --format '{{ artist }}' 2>/dev/null)"

        text="$title - $artist"

        # Limit actual text length
        if [[ ${#text} -gt $MAX_CHARS ]]; then
            text="${text:0:$((MAX_CHARS - 1))}…"
        fi

        last_text="$text"
        last_player="$PLAYER"

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

    else

        # Nothing is currently playing.
        # If we have a previously detected player, check its state.
        if [[ -n "$last_player" ]]; then

            STATUS=$(playerctl --player="$last_player" status 2>/dev/null)

            if [[ "$STATUS" == "Paused" ]]; then

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

        else

            # No player has ever been detected
            jq -cn \
                '{text:"", class:"empty", tooltip:""}'
        fi
    fi

    sleep "$SLEEP"
done
