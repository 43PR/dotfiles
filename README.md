<div align="center">

## 43PR Desktop

A simple, lightweight Hyprland setup focused on productivity, practical keybinds, and easy to customize.

![Hyprland](https://img.shields.io/badge/Hyprland-0.56.2-8b9aaf?style=for-the-badge&labelColor=101418)
[![Discord](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fdiscord.com%2Fapi%2Finvites%2FHQwU9SzHj%3Fwith_counts%3Dtrue&query=%24.approximate_member_count&style=for-the-badge&logo=discord&logoColor=ffffff&label=discord&labelColor=101418&color=7289a8)](https://discord.gg/HQwU9SzHj)
[![YouTube](https://img.shields.io/badge/youtube-subscribe-b05a63?style=for-the-badge&logo=youtube&logoColor=ffffff&labelColor=101418)](https://www.youtube.com/@43PR2)
[![Ko-Fi donate](https://img.shields.io/badge/donate-kofi?style=for-the-badge&logo=ko-fi&logoColor=ffffff&label=ko-fi&labelColor=101418&color=9a6570)](https://ko-fi.com/43pr)

### **[Features](#features)  -  [Keybinds](#keybinds)  -  [Installation](#installation) -  [Updating](#updating)**

<p align="center">
  <sub>
    <b>English</b> · <a href="docs/README.es.md">Español</a> · <a href="docs/README.ru.md">Русский</a> · <a href="docs/README.zh-CN.md">中文</a> · <a href="docs/README.ja.md">日本語</a> · <a href="docs/README.pt.md">Português</a> · <a href="docs/README.fr.md">Français</a> · <a href="docs/README.de.md">Deutsch</a>
  </sub>
</p>

</div>

<img width="1920" height="1080" alt="1792462138" src="https://github.com/user-attachments/assets/10324a99-1038-431f-9f64-0183e2e04276" />

<details>
<summary><b>What is this? Beginner?</b></summary>

### What is this?

This is a full customizable desktop setup for Linux. (bar, app launcher, settings, wallpaper picker, lock screen, power menu, etc). It's built on **Hyprland** (window manager) and **Quickshell** (what the bar and menus are made with). 

### What do I need to run it?

- An **Arch-based Linux distro**: Arch, CachyOS, EndeavourOS, Manjaro, etc.
- A mostly **clean installation**. Existing configs that get replaced are backed up automatically.

I'd recommend CachyOS for beginners: https://youtu.be/eo9MejbzWto

You can skip the configuration section of the video, now it's automated. Just run the installation command.

### Is it hard to use?

Not really. Almost everything is a keyboard shortcut, with mouse alternatives:

- `Super + I` opens settings - middle-click the clock 

The full list is in [Keybinds](#keybinds). You can also hover over bar elements to see what they do, and right-click the clock for bar settings.

### What should I know before installing?

- Log out and back in once the installer finishes.
- Wallpapers aren't included in the install. Download some and put them in `Pictures/Wallpapers`.

### Something broke, where do I ask?

Join the [Discord](https://discord.gg/HQwU9SzHj).

</details>

## Features

- **Fast & Lightweight Quickshell** — Optimized desktop components designed to be fast, and easy to customize.
- **Top bar** - Customizable bar with settings menu, and quick shortcuts.
- **Settings** — System, network, bluetooth, display, audio, storage, themes, and more.
- **Wallpaper picker & Dynamic Colors** — Custom wallpaper selector with automatic wallpaper-based color generation.
- **Preset Themes** — Monochrome, Nord, Tokyo Night and other popular ones, with support for creating your own.
- **App Launcher** — **Rofi** App search, clipboard history, and opacity controls.
- **Zsh + Starship** — Customizable shell with autosuggestions and history.
- **Notes & Reminders** —  Quick notes, tasks, and reminders.
- **Power Menu** — Customizable power menu.
- **Hyprlock** — Custom lock screen.
- **Spotify + Spicetify** — Custom theme based on **text - darkthemer**, (modified).

> All programs: [packages.txt](packages.txt)

### Wallpaper Selector

Just made some tweaks to it. Give it some love: [hyprquickpaper](https://github.com/iamsurjog/hyprquickpaper)

## Keybinds

Right-click the clock to open bar settings. Hover over elements to see actions. To close components use Esc key or use the same keybind. 

| Keybind                 | Action                    |
| -----------             | ------------------------- |
| `Super + T`             | Terminal                  |
| `Super + Q`             | Close active window       |
| `Super + D`             | Application launcher      |
| `Super + Space`         | Toggle floating window    |
| `Super + F`             | Toggle fullscreen         |
| `Super + 1, 2, 3..`     | Change workspaces         |
| `Super + Shift + 1, 2..`| Move window to workspace  |
| `Super + E`             | File manager              |
| `Super + B`             | Browser                   |
| `Super + V`             | Clipboard history         |
| `Super + I`             | Settings menu             |
| `Super + S`             | Quick actions             |
| `Super + O`             | Switch opacity            |
| `Super + C`             | Notes & Reminders         |
| `Super + W`             | Wallpaper selector        |
| `Super + Shift + C`     | Color picker tool         |
| `Super + Mouse wheel`   | Zoom in/out               |
| `Super + Shift + W`     | Toggle bar                |
| `Super + Grave`         | Logout menu               |
| `Super + Tab`           | Lock screen               |
| `Super + N`             | Notifications             |
| `Super + R`             | Toggle screen recorder    |
| `Delete`                | Screenshot fullscreen     |
| `SHIFT + Delete`        | Screenshot area select    |

> [!note]
>
> Move and resize windows with Super + left/right mouse drag.
>
> All keybinds: [.config/hypr/keybinds.lua](.config/hypr/keybinds.lua)

---
## Installation 

**READ ALL**

Works for Arch, CachyOS, EndeavourOS, Manjaro, etc. 

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

Dowload and move wallpapers to Pictures/Wallpapers. Wallpaper picker: Super + W.

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

If you didn't move the repository/dotfiles folder then run:

```bash
cd dotfiles
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
