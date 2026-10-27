#!/bin/bash
# ~/.config/hypr/scripts/now-playing.sh

export LC_ALL=C.UTF-8          # make ${var:pos:len} count characters, not bytes

MAX_CHARS=60                   # max title/artist length before truncating
DISPLAY_CHARS=30               # width of the marquee window
STEP_MS=400                    # time per scroll step (lower = faster)
GAP="     "                    # spacing between loops

ICON_PREV="󰒮"
ICON_NEXT="󰒭"
ICON_PLAY="󰐊"
ICON_PAUSE="󰏤"

# One playerctl call for all players: instance, status, title, artist
US=$'\x1f'
fmt="{{playerInstance}}${US}{{status}}${US}{{title}}${US}{{artist}}"

playing=() paused=()
while IFS="$US" read -r inst st ti ar; do
    case "$st" in
        Playing) [ ${#playing[@]} -eq 0 ] && playing=("$inst" "$st" "$ti" "$ar") ;;
        Paused)  [ ${#paused[@]}  -eq 0 ] && paused=("$inst" "$st" "$ti" "$ar") ;;
    esac
done < <(playerctl -a metadata --format "$fmt" 2>/dev/null)

# Prefer a playing player, fall back to a paused one, else show nothing
if   [ ${#playing[@]} -gt 0 ]; then sel=("${playing[@]}")
elif [ ${#paused[@]}  -gt 0 ]; then sel=("${paused[@]}")
else exit 0
fi

inst="${sel[0]}" status="${sel[1]}" title="${sel[2]}" artist="${sel[3]}"

case "$1" in
    previous) echo "$ICON_PREV"; exit ;;
    next)     echo "$ICON_NEXT"; exit ;;
    player)   echo "$inst"; exit ;;
    toggle|pause)
        [ "$status" = "Playing" ] && echo "$ICON_PAUSE" || echo "$ICON_PLAY"
        exit ;;
esac

# Build text (skip the separator if artist is missing)
text="$title"
[ -n "$artist" ] && text="$title - $artist"

# Truncate
if [ "${#text}" -gt "$MAX_CHARS" ]; then
    text="${text:0:$((MAX_CHARS - 1))}…"
fi

# Short text: no scrolling
if [ "${#text}" -le "$DISPLAY_CHARS" ]; then
    echo "$text"
    exit
fi

# Paused: freeze at the start; playing: scroll by wall-clock time
text="$text$GAP"
len=${#text}
pos=0
if [ "$status" = "Playing" ]; then
    now_ms=$(( ${EPOCHREALTIME/./} / 1000 ))
    pos=$(( (now_ms / STEP_MS) % len ))
fi

# Doubling the string handles wrap-around without extra logic
loop="$text$text"
echo "${loop:$pos:$DISPLAY_CHARS}"
