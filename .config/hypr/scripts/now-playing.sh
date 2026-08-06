#!/bin/sh

if playerctl status 2>/dev/null | grep -q Playing; then
    text="$(playerctl metadata --format '{{ title }} - {{ artist }}')"
    text="$text     "

    len=${#text}
    pos=$(( $(date +%s) % len ))

    echo "♪  ${text:$pos}${text:0:$pos}"
fi
