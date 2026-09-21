> [!note]
> Work in progress 
> 
> Monitors page still needs some work 

Download and unzip this repository to your downloads

## Settings menu

### Dependencies

```bash
sudo pacman -S quickshell qt6-declarative pipewire wireplumber \
    jq networkmanager bluez bluez-utils dmidecode brightnessctl gammastep \
    procps-ng ttf-nerd-fonts-symbols-mono ttf-jetbrains-mono
```

Copy paste the quickshell folder to .config

Replace/add keybinds (.config/hypr/keybinds.lua):

```bash
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("qs ipc call settings toggle"))

hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("qs -n -p ~/.config/quickshell/hyprquickpaper"))
```

Replace/add (.config/hypr/hyprland.lua):

---- AUTOSTART ----

```bash
hl.exec_cmd("sleep 2 && qs")
```

RAM SPEED

Open terminal and run:

```bash
sudo EDITOR=nano visudo -f /etc/sudoers.d/quickshell-dmidecode
```

Paste:

```bash
rp34 ALL=(root) NOPASSWD: /usr/bin/dmidecode
```

Save with Ctrl + O then Enter

## Wallpaper picker

> **To update**

Copy paste the quickshell folder to .config

Replace/add keybind (.config/hypr/hyprland.lua):

```bash
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("qs -n -p ~/.config/quickshell/hyprquickpaper"))
```

Replace/add (.config/hypr/hyprland.lua):

---- AUTOSTART ----

```bash
hl.exec_cmd("sleep 2 && qs")
```

### Dependiencies

```bash
sudo pacman -S quickshell jq imagemagick awww
```

## Terminal

### Dependencies

```bash
sudo pacman -S ttf-jetbrains-mono-nerd zsh starship eza zsh-autosuggestions zsh-syntax-highlighting
```

chsh -s /bin/zsh
