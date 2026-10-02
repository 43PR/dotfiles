#!/bin/sh

if [ $(( $(date +%s) % 2 )) -eq 0 ]; then
    echo "|"
else
    echo ""
fi
