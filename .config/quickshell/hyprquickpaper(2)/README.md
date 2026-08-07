# HyprQuickPaper

Wallpaper selector made using quickshell. Inspired by : [ilyamiro's dots](https://github.com/ilyamiro/nixos-configuration)
PRs and contributions are appreciated.

> [!IMPORTANT]
> Make sure to read the entire config and usage section before using

## Demo

https://github.com/user-attachments/assets/375e3696-e62d-48bf-8af6-18d2be86b224


## Dependencies

- [quickshell](https://git.outfoxxed.me/quickshell/quickshell)

## Installation

### Arch

Get Quickshell with yay (or your AUR helper of choice)

```bash
yay -S quickshell
```

Now just clone this repo into Quickshell's config folder

```bash
git clone https://github.com/iamsurjog/hyprquickpaper ~/.config/quickshell/hyprquickpaper
```

## config

go to the `config.json` file and change the `"wallpaper_path"` and the `"cache_path"` variables

> [!IMPORTANT]
> Make sure to use absolute path (/home/...) for the path and put the trailing "/" at the end of the path

Example config.json
```{json}
{
    "wallpaper_path": "/home/<usrname>/Pictures/Wallpapers/",
    "cache_path": "/home/<usrname>/.cache/quickshell/thumbs/",
    "number_of_pictures": 7,
    "border_color": "#A98881",
    "cache_batch_size": 20
}
```

Also add your wallpaper changing commands to the `commands.sh` file. Selecting a wallpaper runs the command with the path to the wallpaper passed as a parameter. An example on how to use it with swww is given.

```{bash}
swww img $1 -t grow --transition-duration 1
```

You can change the number of pictures cached async at the same time by changing `cache_batch_size`. Making it zero or less will try to cache all the images at the same time

> [!WARNING]
> Trying to cache all the images at the same time could severly affect your performance. Do it only when the number of wallpapers is a managable amount

`number_of_pictures` changes the number of pictures that are shown on the screen at a time

## Usage

Now you're ready to launch HyprQuickPaper from your terminal, or add it to your Hyprland config.

```bash
quickshell -c hyprquickpaper
```

Add this line to your `hyprland.conf` to bind HyprQuickPaper to Super + W.

```hypr
bind = $mainMod, w, exec, quickshell -c hyprquickshot
```

On using it for the first time it will not load anything. Press escape and then restart it and it should load the wallpapers.

### Keybinds:

- J/K to scroll to 1 left/right respectively
- D/U to scroll 1 screen worth left/right respectively
- Esc to quit out
- Space/Enter(or return) to select wallpaper
- Scrolling/click and dragging also works for scrolling
- Clicking also allows selection of a wallpaper

## Common fixes
- remove everything from the cache folder
- Make sure to use absolute path (/home/...) for the path and put the trailing "/" at the end of the path
