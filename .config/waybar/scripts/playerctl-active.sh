#!/usr/bin/env bash

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/waybar-active-player"

# Find a currently playing player
while read -r PLAYER; do
    if [[ "$(playerctl --player="$PLAYER" status 2>/dev/null)" == "Playing" ]]; then
        echo "$PLAYER" > "$STATE_FILE"
        echo "$PLAYER"
        exit 0
    fi
done < <(playerctl -l 2>/dev/null)

# Nothing is playing.
# Use the last player we knew about.
if [[ -f "$STATE_FILE" ]]; then
    PLAYER="$(cat "$STATE_FILE")"

    if playerctl --player="$PLAYER" status >/dev/null 2>&1; then
        echo "$PLAYER"
        exit 0
    fi

    rm -f "$STATE_FILE"
fi

exit 1
