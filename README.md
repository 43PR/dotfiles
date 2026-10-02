<div align="center">

## Hyprland Setup by 43pr メ

A clean and simple Hyprland configuration focused on practical workflows, productivity, and easy customization.

![Hyprland](https://img.shields.io/badge/Hyprland-0.56.2-8b9aaf?style=for-the-badge&labelColor=101418)
![GitHub last commit](https://img.shields.io/github/last-commit/43PR/dotfiles?style=for-the-badge&labelColor=101418&color=8b9aaf)
![GitHub repo size](https://img.shields.io/github/repo-size/43PR/dotfiles?style=for-the-badge&labelColor=101418&color=8b9aaf)
[![Discord](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fdiscord.com%2Fapi%2Finvites%2FHQwU9SzHj%3Fwith_counts%3Dtrue&query=%24.approximate_member_count&style=for-the-badge&logo=discord&logoColor=ffffff&label=discord&labelColor=101418&color=7289a8)](https://discord.gg/HQwU9SzHj)
[![YouTube](https://img.shields.io/badge/youtube-subscribe-b05a63?style=for-the-badge&logo=youtube&logoColor=ffffff&labelColor=101418)](https://www.youtube.com/@43PR2)
[![Ko-Fi donate](https://img.shields.io/badge/donate-kofi?style=for-the-badge&logo=ko-fi&logoColor=ffffff&label=ko-fi&labelColor=101418&color=9a6570)](https://ko-fi.com/43pr)

### **[Features](#features)  -  [Keybinds](#most-used-keybinds)  -  [Installation](#installation) -  [Updating](#updating)**

</div>

https://github.com/user-attachments/assets/f56103b4-534c-4148-89ec-201d75acf7aa

<img width="1920" height="1080" alt="1790717154" src="https://github.com/user-attachments/assets/53a7a2ff-4050-450b-8218-b3e42ac2e0f2" />

<img width="1920" height="1080" alt="9" src="https://github.com/user-attachments/assets/0a1fc782-8111-4efd-bc8c-684b3556ebd1" />

Wallpapers: https://wallhaven.cc/user/43pr

## Features

- **Waybar** — Volume control, mute, and media playback controls.
- **Settings menu** — System, network, bluetooth, display, audio, storage, and more.
- **Dynamic Colors** — Wallpaper-based color generation with **Matugen**.
- **Wallpaper Selector** — Custom wallpaper picker **(Awww + Quickshell)**.
- **App Launcher** — **Rofi** for application search, clipboard history, and opacity control.
- **Zsh + Starship** — Customizable shell with autosuggestions, history, and a polished prompt.
- **Custom power menu** — Toggle controls and drag **(Quickshell)**.
- **Spotify + Spicetify** — Custom theme based on **text - darkthemer**, with personal modifications.
- **Monochrome Theme** — A default monochrome styling across the desktop.
- **Custom Scripts** — Scripts for workflow and system management.
- **Hyprlock** — Custom lock screen.
- **Terminal** — Kitty.
- **File Manager** — Thunar.
- **Text Editor** — Xed.

> All programs: [packages.txt](packages.txt)

### Wallpaper Selector

Just made some tweaks to it. Give it some love: [hyprquickpaper](https://github.com/iamsurjog/hyprquickpaper)

## Most used keybinds

> **You can modify keybinds using HyprMod**

> **Move and resize windows with Super + left/right mouse drag.**

| Keybind                 | Action                    |
| -----------             | ------------------------- |
| `Super + T`             | Terminal                  |
| `Super + Q`             | Close active window       |
| `Super + 1, 2, 3..`     | Change workspaces         |
| `Super + Shift + 1, 2..`| Move window to workspace  |
| `Super + D`             | Application launcher      |
| `Super + E`             | File manager              |
| `Super + F`             | Toggle fullscreen         |
| `Super + Space`         | Toggle floating window    |
| `Super + B`             | Browser                   |
| `Super + W`             | Wallpaper selector        |
| `Super + I`             | Settings menu             |
| `Super + O`             | Switch opacity            |
| `Super + V`             | Clipboard history         |
| `Super + Shift + W`     | Toggle waybar             |
| `Super + Tab`           | Lock screen               |
| `Super + Grave`         | Logout menu               |
| `Super + Mouse wheel`   | Zoom in/out               |
| `Delete`                | Screenshot fullscreen     |
| `SHIFT + Delete`        | Screenshot area select    |
| `Super + L`             | Toggle dark/light mode    |

> To close most quickshell apps just click outside or Esc key.

> All keybinds: [.config/hypr/keybinds.lua](.config/hypr/keybinds.lua)

> Quickshell SettingsCornerTrigger.qml to controls hover actions

---
## Installation 

**READ ALL**

Should work for Arch, Manjaro, EndeavourOS, CachyOS, etc. 

This is mainly intended for a clean installation (existing configuration files that are being replaced will be backed up automatically).

**First install git then use the next command and continue the installation until it's finished**

```bash

sudo pacman -S git   
```
```bash

git clone https://github.com/43PR/dotfiles.git
cd dotfiles
chmod +x install.sh
./install.sh
```

After the installation finishes log out and back in.

> [!important]
> **Do not move or delete the dotfiles repository after installation.**
>
> This setup uses **symbolic links (symlinks)** that point to files inside the cloned repository. If you move or delete the repository, those symlinks will break.
>
> If you relocate the repository, simply run:
>
> ```bash
> ./install.sh
> ```
>
> The installer will automatically update the existing symlinks to point to the new location.

---
## Updating

Pull the latest changes, then run the updater from inside the repository:

```bash
git pull
./update.sh
```

Other options: `--dry-run` (preview changes), `--skip-packages`, `--skip-theme`.

Dotfiles are symlinked so, `git pull` updates your live configs directly.

You can check the reminders printed at the end of the run.

> [!tip]
> If any Quickshell (`.qml`) files changed in the pull, run:
>
> ```bash
> ./update.sh --restart-shell
> ```
>
> to restart Quickshell automatically.

> [!note]
> 
> Custom-gpu parts are specific to my hardware.
>
> For issues with the wallpaper picker, you can clear the cache from the Storage page in Settings.

