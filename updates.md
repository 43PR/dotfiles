> [!note]
> Work in progress 
> 
> Monitors page still needs some work 
> 
> All programs: [packages.txt](packages.txt)

```text
Latest updates: Settings Storage (dependencies: ncdu) 
```

**[Keybinds](#add-keybinds) - [Autostart](#autostart) - [Wlogout](#wlogout) - [Spicetify](#spicetify)* - [Allow Quickshell to read RAM speed](#allow-quickshell-to-read-ram-speed) - [Change your default shell to Zsh](#change-your-default-shell-to-zsh)*


## Update quickshell settings menu & wallpaper picker

**Download and unzip this repository to your downloads**

### Dependencies

```bash
sudo pacman -S quickshell qt6-declarative pipewire wireplumber \
    jq networkmanager bluez bluez-utils dmidecode brightnessctl gammastep \
    procps-ng ttf-nerd-fonts-symbols-mono ttf-jetbrains-mono \
    ttf-jetbrains-mono-nerd zsh starship eza \
    zsh-autosuggestions zsh-syntax-highlighting \
    imagemagick awww ncdu
```

### Dependencies by feature

Quickshell / Settings menu
```bash
sudo pacman -S quickshell qt6-declarative pipewire wireplumber \
    jq networkmanager bluez bluez-utils dmidecode brightnessctl gammastep \
    procps-ng ttf-nerd-fonts-symbols-mono ttf-jetbrains-mono
```

Terminal
```bash
sudo pacman -S ttf-jetbrains-mono-nerd zsh starship eza \
    zsh-autosuggestions zsh-syntax-highlighting
```

Wallpaper picker
```bash
sudo pacman -S quickshell jq imagemagick awww
```

Make sure all dependencies are installed

Copy paste the quickshell folder to: .config

### Add keybinds

Replace/add keybinds: .config/hypr/keybinds.lua

```bash
-- Settings menu (Close with the same bind or click outside)
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("qs ipc call settings toggle"))
-- Wallpaper picker (Close with "W" key)
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("qs -n -p ~/.config/quickshell/hyprquickpaper"))
```

### Autostart

Replace/add to autostart section: .config/hypr/hyprland.lua

```bash
hl.exec_cmd("sleep 2 && qs")
```

### Allow Quickshell to read RAM speed

Run:

```bash
sudo EDITOR=nano visudo -f /etc/sudoers.d/quickshell-dmidecode
```

Paste:

```bash
user ALL=(root) NOPASSWD: /usr/bin/dmidecode
```

Replace "user" with your username 

Save with Ctrl + O then Enter

### Change your default shell to Zsh

Run:

```bash
chsh -s /bin/zsh
```

Log out and back in for the change to take effect.

## Spicetify 

https://youtu.be/Y3i96F1-E_Q

Copy paste the spicetify folder to: (.config)

```bash
nano ~/.config/wlogout/style.css
```

Edit the file and replace rp34 with your username:  /home/rp34/.config/spotify/prefs

### Wlogout

Run:

```bash
nano ~/.config/wlogout/style.css
```

Replace each sutdown, reboot, logout background-image: url with YOUR username

#shutdown {
    background-image: url("/home/user/.config/wlogout/icons/shutdown.png");
}

Make sure the keybind is the same as this repository

