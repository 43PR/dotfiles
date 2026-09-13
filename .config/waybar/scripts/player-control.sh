#!/usr/bin/env bash

STATE_FILE="/tmp/waybar-player"

get_playing_player() {
    while read -r player; do
        if [[ "$(playerctl --player="$player" status 2>/dev/null)" == "Playing" ]]; then
            echo "$player"
            return 0
        fi
    done < <(playerctl -l 2>/dev/null)

    return 1
}

# If we already know which player Waybar was controlling,
# use that player first.
if [[ -f "$STATE_FILE" ]]; then
    PLAYER="$(cat "$STATE_FILE")"

    # Make sure it still exists
    if ! playerctl --player="$PLAYER" status >/dev/null 2>&1; then
        PLAYER=""
    fi
else
    PLAYER=""
fi

# If we don't have a remembered player, find the currently playing one.
if [[ -z "$PLAYER" ]]; then
    PLAYER="$(get_playing_player)"
fi

# Nothing usable
[[ -z "$PLAYER" ]] && exit 0

# Remember this player for the next click
echo "$PLAYER" > "$STATE_FILE"

case "$1" in
    play-pause)
        playerctl --player="$PLAYER" play-pause
        ;;
    previous)
        playerctl --player="$PLAYER" previous
        ;;
    next)
        playerctl --player="$PLAYER" next
        ;;
esac
