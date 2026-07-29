**Simple Hyprland Rice**

![](2.png)
![](3.png)
![](4.png)

Feel free to use as inspiration or a starting point for your own setup. [Spotify](https://open.spotify.com/user/22ijtohiijms6hd555vqgmrpi?si=3e55ad117c5f403c)

**KEYBINDS**

bind = $mod, T, exec, $terminal

bind = $mod, D, exec, $menu

bind = $mod, E, exec, $fileManager

bind = $mod, B, exec, $browser

bind = $mod, F, fullscreen

bind = $mod, Q, killactive

bind = $mod, Tab, exec, swaylock

bind = $mod, Escape, exec, wlogout -b 5 -m 470 -c 15

**Toggle waybar**

bind = $mod SHIFT, W, exec, sh -c 'pgrep -x waybar >/dev/null && pkill waybar || nohup waybar >/dev/null 2>&1 &'

**Floating**

bind = $mod, Space, exec, hyprctl dispatch togglefloating && hyprctl dispatch resizeactive exact 50% 50% && hyprctl dispatch centerwindow

**Change wallpaper**

bind = SUPER, right, exec, ~/.config/hypr/scripts/wallpaper-cycle.sh next

bind = SUPER, left, exec, ~/.config/hypr/scripts/wallpaper-cycle.sh prev

**Screenshots**

bind = $mod, Delete, exec, grim ~/Pictures/$(date +%s).png

bind = , Delete, exec, grim -g "$(slurp)" ~/Pictures/$(date +%s).png

**Clipboard**

bind = $mod, V, exec, cliphist list | rofi -dmenu | cliphist decode | wl-copy


