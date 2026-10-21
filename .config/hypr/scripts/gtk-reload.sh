#!/usr/bin/env bash
# ~/.config/hypr/scripts/gtk-reload.sh
# Forces running GTK apps (Thunar, ...) to re-read gtk.css/colors.css.
# Usage: gtk-reload.sh [target-theme]
# theme.py passes the intended theme so we never read back a half-toggled one.
# (Icons are handled by theme.py, which alternates between two icon-theme names.)
S=org.gnome.desktop.interface

target=${1:-$(gsettings get $S gtk-theme | tr -d "'")}
case "$target" in Adwaita) tmp=HighContrast ;; *) tmp=Adwaita ;; esac

trap 'gsettings set $S gtk-theme "$target"' EXIT   # always restore, even if killed
gsettings set $S gtk-theme "$tmp"
sleep 0.5
gsettings set $S gtk-theme "$target"
trap - EXIT
exit 0
