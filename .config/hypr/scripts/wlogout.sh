#!/usr/bin/env bash
#
# Dynamic wlogout launcher (43PR setup).
#
# Replicates the author's look — one button per row, 20px spacing,
# right-anchored column — but computes the L/R/T/B margins from the
# focused monitor at launch time, so the menu auto-arranges on any
# display size instead of using hardcoded ultrawide margins.
#
# Button geometry must match ~/.config/wlogout/style.css
# (min-width / min-height).

set -uo pipefail

LAYOUT="$HOME/.config/wlogout/layout"
CSS="$HOME/.config/wlogout/style.css"

# ANCHOR: left | center | right (author's menu sits on the right side).
# EDGE_GAP_FRAC: side margin as a fraction of monitor width when anchored
# left/right. Vertical position stays centered like the author's T=B.
ANCHOR="right"
EDGE_GAP_FRAC="0.06"

BTN=100          # button width/height in px (style.css)
PER_ROW=1        # -b: author's vertical column
COL_SPACING=20   # -c
ROW_SPACING=20   # -r

# Count buttons from the layout file so added entries stay arranged.
N="$(grep -c '"label"' "$LAYOUT" 2>/dev/null || true)"
if ! [[ "$N" =~ ^[0-9]+$ ]] || [[ "$N" -lt 1 ]]; then
    N=3
fi

ROWS=$(( (N + PER_ROW - 1) / PER_ROW ))
COLS=$(( N < PER_ROW ? N : PER_ROW ))

GRID_W=$(( COLS * BTN + (COLS - 1) * COL_SPACING ))
GRID_H=$(( ROWS * BTN + (ROWS - 1) * ROW_SPACING ))

# Focused monitor size in logical pixels.
MON="$(hyprctl monitors -j 2>/dev/null | jq -r '[.[] | select(.focused == true)][0] | "\(.width) \(.height) \(.scale)"')"
read -r MW MH SCALE <<< "$MON"
if ! [[ "$MW" =~ ^[0-9]+$ && "$MH" =~ ^[0-9]+$ ]]; then
    MW=1366 MH=768 SCALE=1
fi
[[ "$SCALE" =~ ^[0-9]+(\.[0-9]+)?$ ]] || SCALE=1
W="$(awk -v w="$MW" -v s="$SCALE" 'BEGIN { printf "%d", w / s }')"
H="$(awk -v h="$MH" -v s="$SCALE" 'BEGIN { printf "%d", h / s }')"

# Test hook: WLOGOUT_TEST_W/H override the detected resolution,
# --print-margins prints the math without launching.
if [[ "${WLOGOUT_TEST_W:-}" =~ ^[0-9]+$ ]]; then W="$WLOGOUT_TEST_W"; fi
if [[ "${WLOGOUT_TEST_H:-}" =~ ^[0-9]+$ ]]; then WLOGOUT_TEST_H="$WLOGOUT_TEST_H"; H="$WLOGOUT_TEST_H"; fi

L=$(( (W - GRID_W) / 2 )); [[ "$L" -lt 0 ]] && L=0
R=$(( W - GRID_W - L ));   [[ "$R" -lt 0 ]] && R=0
T=$(( (H - GRID_H) / 2 )); [[ "$T" -lt 0 ]] && T=0
B=$(( H - GRID_H - T ));   [[ "$B" -lt 0 ]] && B=0

# Side anchor: pin the column left/right with a proportional edge gap,
# keeping the author's vertical centering (T=B).
if [[ "$ANCHOR" == "right" || "$ANCHOR" == "left" ]]; then
    EDGE="$(awk -v w="$W" -v f="$EDGE_GAP_FRAC" 'BEGIN { printf "%d", w * f }')"
    [[ "$EDGE" -lt 0 ]] && EDGE=0
    if [[ "$ANCHOR" == "right" ]]; then
        R="$EDGE"
        L=$(( W - GRID_W - R )); [[ "$L" -lt 0 ]] && L=0
    else
        L="$EDGE"
        R=$(( W - GRID_W - L )); [[ "$R" -lt 0 ]] && R=0
    fi
fi

if [[ "${1:-}" == "--print-margins" ]]; then
    printf 'monitor=%sx%s buttons=%s grid=%sx%s margins L=%s R=%s T=%s B=%s\n' \
        "$W" "$H" "$N" "$GRID_W" "$GRID_H" "$L" "$R" "$T" "$B"
    exit 0
fi

pgrep -x wlogout >/dev/null && exit 0
exec wlogout -b "$PER_ROW" -c "$COL_SPACING" -r "$ROW_SPACING" \
    -L "$L" -R "$R" -T "$T" -B "$B" \
    -l "$LAYOUT" -C "$CSS"

