#!/bin/bash

hyprctl dispatch togglefloating

sleep 0.05

floating=$(hyprctl activewindow -j | jq -r '.floating')

if [ "$floating" = "true" ]; then
    hyprctl dispatch resizeactive exact 70% 70%
    hyprctl dispatch centerwindow
fi
