#!/usr/bin/env bash
# Select a screen region, OCR it, copy the text, report via the Quickshell OSD.
set -uo pipefail

# Languages: OCR_LANG env wins, then state/ocr.conf (written by Settings > Keybinds),
# then English. Format of ocr.conf: ocr_lang=eng+spa
CONF="$HOME/.config/quickshell/state/ocr.conf"
conf_lang=""
[ -r "$CONF" ] && conf_lang="$(sed -n 's/^ocr_lang=//p' "$CONF" | head -n1 | tr -cd 'A-Za-z0-9_+')"
LANGS="${OCR_LANG:-${conf_lang:-eng}}"
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
