#!/usr/bin/env bash
# Select a screen region, OCR it, copy the text, report via the Quickshell OSD.
set -uo pipefail

LANGS="${OCR_LANG:-eng}"   # e.g. OCR_LANG=eng+spa
osd() { qs ipc call ocr "$@" >/dev/null 2>&1 || true; }

geom="$(slurp)" || { osd cancelled; exit 0; }

osd working

text="$(grim -t png -l 0 -g "$geom" - \
  | tesseract stdin stdout -l "$LANGS" --psm 6 2>/dev/null \
  | sed -e 's/[[:space:]]*$//')" || text=""

if [ -z "${text//[[:space:]]/}" ]; then
  osd empty
  exit 1
fi

printf '%s' "$text" | wl-copy

# Flatten to one line for the OSD preview (char-aware under a UTF-8 locale)
preview="$(printf '%s' "$text" | tr '\n\t' '  ' | tr -s ' ')"
osd done "${preview:0:120}"
