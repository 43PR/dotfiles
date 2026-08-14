## Simple Hyprland Rice

**Full showcase: https://www.youtube.com/watch?v=kYZ5mkGuQEg**

Simple Hyprland setup focused on practical keybinds, productivity, and a smooth workflow easy to customize

Feel free to use as inspiration or as a starting point for building your own setup.

![](x.png)
![](lock.png)
![](z.png)
![](ww.png)

Wallpapers: https://wallhaven.cc/user/43pr

## Features

* Waybar
> Change volume with mouse wheel, play/pause and next media
* Rofi
> App search, clipboard history and switch opacity
* Hyprlock
* Wlogout
* Custom wallpaper selector
* Custom scripts
* Spotify + Spicetify. Theme: text darkthemer but I changed the colors

### Wallpaper Selector

[hyprquickpaper](https://github.com/iamsurjog/hyprquickpaper)

> check out the original source it explains how to setup I just made changes to it 

### Most used keybinds

> **$mod = Super / Windows key**

| Keybind     | Action                    |
| ----------- | ------------------------- |
| `Super + T` | Open terminal             |
| `Super + D` | Open application launcher |
| `Super + E` | Open file manager         |
| `Super + B` | Open browser              |
| `Super + W` | Open wallpaper selector   |
| `Super + O` | Switch opacity            |
| `Super + V` | Open clipboard history    |
```ini
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("quickshell -c hyprquickpaper"))
```
```ini
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd(home .. "/.config/hypr/scripts/opacity.sh"))
```
```ini
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("cliphist list | rofi -dmenu | cliphist decode | wl-copy"))
```
**Window Management and more**
| Keybind         | Action              |
| --------------- | ------------------- |
| `Super + Q`     | Close active window |
| `Super + F`     | Toggle fullscreen   |
| `Super + Space` | Toggle floating     |
| `Super + Tab`   | Lock screen         |
| `Super + Esc`   | Open logout menu    |
```ini
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("wlogout -b 1 -c 20 -r 20 -L 1700 -R 1700 -T 325 -B 325"))
```
**Move/resize window with mouse**
```ini
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
```
```ini
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
```
**Toggle Waybar**
```ini
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("sh -c 'pgrep -x waybar >/dev/null && pkill waybar || nohup waybar >/dev/null 2>&1 &'"))
```

---

### Installed Programs:

```text
Hyprland
Waybar
Rofi
Hyprlock
Wlogout
Quickshell
awww
Grim
Slurp
Cliphist
wl-clipboard
```

---
## Installation
> **Note:** Some paths and applications are specific to my setup. You may need to modify the configuration files to match your system.

**Clone the repository and run the installer:**

```bash
git clone https://github.com/43PR/dotfiles.git
cd dotfiles
chmod +x install.sh
./install.sh
```

### What it does:

The installer will modify your ~/.config directory. 

Existing configuration files that are being replaced will be backed up automatically.

Install the required Arch Linux packages from packages.txt

Back up existing configuration files before replacing them

Copy the dotfiles into ~/.config

Set the required script permissions

Enable the required user services

After the installation finishes, restart Hyprland or log out and back in.

```bash
hyprctl reload
```

If you encounter any issues, check the relevant configuration files under: ~/.config/

---

* [hyprquickpaper](https://github.com/iamsurjog/hyprquickpaper)
* [samaritan-sddm-theme](https://github.com/omerwk/samaritan-sddm-theme)


