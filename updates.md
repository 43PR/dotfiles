## Settings menu

### Dependencies

```bash
sudo pacman -S quickshell jq networkmanager bluez bluez-utils dmidecode brightnessctl gammastep \
    procps-ng ttf-nerd-fonts-symbols-mono ttf-jetbrains-mono
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
