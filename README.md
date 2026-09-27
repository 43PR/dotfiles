<div align="center">

## Hyprland Setup by 43pr メ

Simple setup focused on keyboard and mouse workflows, practical keybinds, productivity, and easy to customize. Feel free to use as inspiration or as a starting point for building your own setup.

![Hyprland](https://img.shields.io/badge/Hyprland-0.56.2-8b9aaf?style=for-the-badge&labelColor=101418)
![GitHub last commit](https://img.shields.io/github/last-commit/43PR/dotfiles?style=for-the-badge&labelColor=101418&color=8b9aaf)
![GitHub repo size](https://img.shields.io/github/repo-size/43PR/dotfiles?style=for-the-badge&labelColor=101418&color=7f8c9a)
[![Discord](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fdiscord.com%2Fapi%2Finvites%2FHQwU9SzHj%3Fwith_counts%3Dtrue&query=%24.approximate_member_count&style=for-the-badge&logo=discord&logoColor=ffffff&label=discord&labelColor=101418&color=7289a8)](https://discord.gg/HQwU9SzHj)
[![YouTube](https://img.shields.io/badge/youtube-subscribe-b05a63?style=for-the-badge&logo=youtube&logoColor=ffffff&labelColor=101418)](https://www.youtube.com/@43PR2)
[![Ko-Fi donate](https://img.shields.io/badge/donate-kofi?style=for-the-badge&logo=ko-fi&logoColor=ffffff&label=ko-fi&labelColor=101418&color=9a6570)](https://ko-fi.com/43pr)

### **[Features](#features)  -  [Keybinds](#most-used-keybinds)  -  [Installation](#installation)**

</div>

https://github.com/user-attachments/assets/f56103b4-534c-4148-89ec-201d75acf7aa

![](Wallpapers/Showcase/9.png)
![](Wallpapers/Showcase/hover-areas.png)
![](Wallpapers/Showcase/4.png)
![](Wallpapers/Showcase/2.png)

Wallpapers: https://wallhaven.cc/user/43pr

## Features

* **Waybar** > Change volume with mouse wheel, mute, play/pause, next and blue light filter
* **Custom settings menu** > System info, Network, Bluetooth, Monitors, Sound: switch output, per app volume
* **Custom wallpaper selector** > (Awww + Quickshell)
* **App launcher (Rofi)** > App search/open, clipboard history and switch opacity
* **Zsh shell + starship** > (Customizable command-line shell)
* **Spotify + Spicetify Theme:** > text by darkthemer (edited)
* **Custom monochrome theme**
* **Custom scripts** 
* **Hyprlock** > (Lock screen)
* **Wlogout** > (Logout menu)
* **Terminal:** Kitty
* **File manager:** Thunar
* **Editor:** Xed, VSCodium
  
> All programs: [packages.txt](packages.txt)

### Wallpaper Selector

Just made some tweaks to it. Give it some love: [hyprquickpaper](https://github.com/iamsurjog/hyprquickpaper)

## Most used keybinds

> **You can modify the keybinds using HyprMod**

| Keybind                 | Action                    |
| -----------             | ------------------------- |
| `Super + T`             | Terminal                  |
| `Super + Q`             | Close active window       |
| `Super + 1, 2, 3..`     | Change workspaces         |
| `Super + Shift + 1, 2..`| Move window to workspace  |
| `Super + D`             | Application launcher      |
| `Super + E`             | File manager              |
| `Super + B`             | Browser                   |
| `Super + W`             | Wallpaper selector        |
| `Super + I`             | Settings menu             |
| `Super + O`             | Switch opacity            |
| `Super + V`             | Clipboard history         |
| `Super + F`             | Toggle fullscreen         |
| `Super + Space`         | Toggle floating window    |
| `Super + Shift + W`     | Toggle waybar             |
| `Super + Tab`           | Lock screen               |
| `Super + Grave`         | Logout menu               |
| `Delete`                | Screenshot fullscreen     |
| `SHIFT + Delete`        | Screenshot area select    |
| `Super + Mouse wheel`   | Zoom in/out               |

> To close wlogout, wallpaper picker, setting menu just click outside or Esc key. Toggle (same keybind to open/close) for app launcher and waybar

> All keybinds: [.config/hypr/keybinds.lua](.config/hypr/keybinds.lua)

---
## Installation 

**READ ALL**

Should work for Arch, Manjaro, EndeavourOS, CachyOS, etc. Let me know if there's any issues

This is mainly intended for a clean installation. If you already have a desktop configuration I recommend to implement manually.

Existing configuration files that are being replaced will be backed up automatically.

**First install git then use the next command and continue the installation until it's finished:**

```bash

sudo pacman -S git   
```
```bash

git clone https://github.com/43PR/dotfiles.git
cd dotfiles
chmod +x install.sh
./install.sh
```

Open GTX Settings and change Color scheme to Prefer dark - Apply.

After the installation finishes log out and back in.

> [!note]
> 
> Waybar custom-gpu is specific to my PC so you can remove it or implement.
>
> If you’re having any issues with the wallpaper picker, you can clear the cache from the Storage page in Settings.

