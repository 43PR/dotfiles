## Settings menu

### Dependencies

```bash
sudo pacman -S jq networkmanager bluez bluez-utils dmidecode brightnessctl
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
