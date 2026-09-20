## Settings menu

### Dependencies

```bash
sudo pacman -S jq networkmanager bluez bluez-utils dmidecode brightnessctl
```

OPEN TERMINAL AND RUN:

```bash
sudo EDITOR=nano visudo -f /etc/sudoers.d/quickshell-dmidecode
```

PASTE 

```bash
rp34 ALL=(root) NOPASSWD: /usr/bin/dmidecode
```

SAVE WITH CTRL + O
