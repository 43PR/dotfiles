## Settings menu

### Dependencies

```bash
sudo pacman -S quickshell jq networkmanager bluez bluez-utils dmidecode brightnessctl gammastep \
    procps-ng ttf-nerd-fonts-symbols-mono ttf-jetbrains-mono
```

Download and unzip this repository then copy paste the quickshell folder to .config

Replace/add keybinds (.config/hypr/keybinds.lua):

hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("qs ipc call settings toggle"))

hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("qs -n -p ~/.config/quickshell/hyprquickpaper"))

Replace/add (.config/hypr/hyprland.lua):

---- AUTOSTART ----

hl.exec_cmd("sleep 2 && qs")

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
