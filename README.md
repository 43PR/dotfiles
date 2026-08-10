## Simple Hyprland Rice

A simple and minimal **Hyprland rice** for Arch Linux, focused on a clean desktop and useful shortcuts.

**Full showcase: https://www.youtube.com/watch?v=kYZ5mkGuQEg**

Feel free to use as inspiration or as a starting point for your own setup.

![](x.png)
![](lock.png)
![](z.png)
![](ww.png)

## Features

* Hyprland window manager
* Waybar
* Rofi
* Hyprlock
* Wlogout
* Custom wallpaper selector
* Custom scripts
* Spotify + Spicetify

## Useful Links

### Spotify

[My Spotify profile](https://open.spotify.com/user/22ijtohiijms6hd555vqgmrpi)

### Wallpaper Selector

[hyprquickpaper](https://github.com/iamsurjog/hyprquickpaper)

> I use **hyprquickpaper** as the wallpaper selector and made some changes to the original project.

Please check out the original source and give the project some love.

### SDDM Theme

[samaritan-sddm-theme](https://github.com/omerwk/samaritan-sddm-theme)

A cool SDDM theme used with this setup.

---

## [Hyprland] Keybinds

> **$mod = Super / Windows key**

## Applications

| Keybind     | Action                    |
| ----------- | ------------------------- |
| `Super + T` | Open terminal             |
| `Super + D` | Open application launcher |
| `Super + E` | Open file manager         |
| `Super + B` | Open browser              |
| `Super + W` | Open wallpaper selector   |

## Window Management

| Keybind         | Action              |
| --------------- | ------------------- |
| `Super + Q`     | Close active window |
| `Super + F`     | Toggle fullscreen   |
| `Super + Space` | Toggle floating     |
| `Super + Tab`   | Lock screen         |
| `Super + Esc`   | Open logout menu    |

## Waybar

| Keybind             | Action        |
| ------------------- | ------------- |
| `Super + Shift + W` | Toggle Waybar |

Waybar is completely stopped when hidden and started again when enabled.

```ini
bind = $mod SHIFT, W, exec, sh -c 'pgrep -x waybar >/dev/null && pkill waybar || nohup waybar >/dev/null 2>&1 &'
```

## Screenshots

| Keybind          | Action                               |
| ---------------- | ------------------------------------ |
| `Super + Delete` | Screenshot entire screen             |
| `Delete`         | Select an area and take a screenshot |

Screenshots are saved to:

```text
~/Pictures/
```

## Clipboard

| Keybind     | Action                 |
| ----------- | ---------------------- |
| `Super + V` | Open clipboard history |

Uses `cliphist`, `rofi`, and `wl-copy`.

```ini
bind = $mod, V, exec, cliphist list | rofi -dmenu | cliphist decode | wl-copy
```

## Keyboard Layout

| Keybind     | Action                             |
| ----------- | ---------------------------------- |
| `Super + Z` | Switch to the next keyboard layout |

```ini
bind = $mod, Z, exec, hyprctl switchxkblayout current next
```

---

# Dependencies

This setup uses some external programs. You may need to install them depending on your existing Arch Linux setup:

```text
Hyprland
Waybar
Rofi
Hyprlock
Wlogout
Quickshell
Grim
Slurp
Cliphist
wl-clipboard
```

You will also need the required fonts, icons, scripts, and configuration files included in this repository.

---

# Installation

Clone the repository:

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPOSITORY.git
cd YOUR_REPOSITORY
```

Copy the configuration files to your `.config` directory:

```bash
cp -r .config/* ~/.config/
```

Restart Hyprland or log out and back in.

> **Note:** Some paths and applications are specific to my setup. You may need to modify the configuration files to match your system.

---

# Credits

* [Hyprland](https://hyprland.org/)
* [hyprquickpaper](https://github.com/iamsurjog/hyprquickpaper)
* [samaritan-sddm-theme](https://github.com/omerwk/samaritan-sddm-theme)

Thanks to the original developers for their work.

Feel free to use, modify, and build upon this configuration for your own setup.

