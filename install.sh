```bash
#!/usr/bin/env bash

set -euo pipefail

# 43PR/dotfiles installer
# Arch-compatible Linux + Hyprland
#
# Usage:
#   ./install.sh
#
# This script:
#   1. Verifies that the system is Arch-based
#   2. Detects the available package manager
#   3. Installs required packages
#   4. Backs up existing ~/.config
#   5. Installs this repository's configuration
#
# Supported package managers:
#   - pacman       (Arch, Manjaro, EndeavourOS, CachyOS, etc.)
#   - paru         (AUR helper)
#   - yay          (AUR helper)
#
# Designed to be safe to run more than once.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
BACKUP_ROOT="$HOME/.config-backups"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"

# --------------------------------------------------
# Colors / output
# --------------------------------------------------

info() {
    printf '\n\033[1;34m[INFO]\033[0m %s\n' "$1"
}

success() {
    printf '\n\033[1;32m[DONE]\033[0m %s\n' "$1"
}

warning() {
    printf '\n\033[1;33m[WARN]\033[0m %s\n' "$1"
}

error() {
    printf '\n\033[1;31m[ERROR]\033[0m %s\n' "$1" >&2
}

# --------------------------------------------------
# Checks
# --------------------------------------------------

if [[ "${EUID}" -eq 0 ]]; then
    error "Do not run this script as root."
    exit 1
fi

if [[ ! -f /etc/os-release ]]; then
    error "Cannot determine the operating system."
    exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release

# Arch-compatible distributions normally identify themselves
# through ID_LIKE=arch or ID=arch.
if [[ "${ID:-}" != "arch" && "${ID_LIKE:-}" != *arch* ]]; then
    error "This installer is intended for Arch-compatible Linux distributions."
    error "Detected: ${PRETTY_NAME:-unknown}"
    exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
    error "sudo is required."
    exit 1
fi

# --------------------------------------------------
# Package manager detection
# --------------------------------------------------

PACKAGE_FILE="$REPO_DIR/packages.txt"

if [[ ! -f "$PACKAGE_FILE" ]]; then
    error "packages.txt not found."
    exit 1
fi

if command -v paru >/dev/null 2>&1; then
    PACKAGE_MANAGER="paru"
elif command -v yay >/dev/null 2>&1; then
    PACKAGE_MANAGER="yay"
elif command -v pacman >/dev/null 2>&1; then
    PACKAGE_MANAGER="pacman"
else
    error "No supported package manager found."
    error "Install pacman, paru, or yay before running this installer."
    exit 1
fi

info "Detected distribution: ${PRETTY_NAME:-unknown}"
info "Using package manager: $PACKAGE_MANAGER"

# --------------------------------------------------
# Packages
# --------------------------------------------------

mapfile -t PACKAGES < <(
    grep -vE '^[[:space:]]*(#|$)' "$PACKAGE_FILE"
)

if [[ "${#PACKAGES[@]}" -eq 0 ]]; then
    warning "packages.txt does not contain any packages."
else
    info "Installing required packages..."

    case "$PACKAGE_MANAGER" in
        paru|yay)
            "$PACKAGE_MANAGER" -S --needed --noconfirm "${PACKAGES[@]}"
            ;;
        pacman)
            sudo pacman -Syu --needed --noconfirm "${PACKAGES[@]}"
            ;;
    esac

    success "Packages installed."
fi

# --------------------------------------------------
# Backup existing configuration
# --------------------------------------------------

if [[ -d "$CONFIG_DIR" ]]; then
    info "Backing up existing ~/.config..."

    mkdir -p "$BACKUP_DIR"

    # Only back up directories/files that this repository
    # is going to replace.
    for item in "$REPO_DIR/.config/"*; do
        [[ -e "$item" ]] || continue

        name="$(basename "$item")"

        if [[ -e "$CONFIG_DIR/$name" ]]; then
            cp -a "$CONFIG_DIR/$name" "$BACKUP_DIR/"
        fi
    done

    success "Existing configuration backed up to:"
    printf '  %s\n' "$BACKUP_DIR"
else
    mkdir -p "$CONFIG_DIR"
fi

# --------------------------------------------------
# Install dotfiles
# --------------------------------------------------

info "Installing dotfiles..."

cp -a "$REPO_DIR/.config/." "$CONFIG_DIR/"

success "Dotfiles installed."

# --------------------------------------------------
# Wallpapers
# --------------------------------------------------

if [[ -d "$REPO_DIR/Wallpapers" ]]; then
    info "Installing wallpapers..."

    mkdir -p "$HOME/Pictures/Wallpapers"
    cp -a "$REPO_DIR/Wallpapers/." "$HOME/Pictures/Wallpapers/"

    success "Wallpapers installed."
fi

# --------------------------------------------------
# Enable user audio services
# --------------------------------------------------

if command -v systemctl >/dev/null 2>&1; then
    info "Enabling PipeWire..."

    systemctl --user enable --now pipewire.service
    systemctl --user enable --now pipewire-pulse.service
    systemctl --user enable --now wireplumber.service

    success "PipeWire configured."
else
    warning "systemctl was not found; skipping PipeWire service setup."
fi

# --------------------------------------------------
# Permissions
# --------------------------------------------------

info "Setting executable permissions on scripts..."

if [[ -d "$CONFIG_DIR/hypr/scripts" ]]; then
    find "$CONFIG_DIR/hypr/scripts" \
        -type f \
        -exec chmod +x {} \;
fi

success "Permissions configured."

# --------------------------------------------------
# Finish
# --------------------------------------------------

printf '\n'
printf '\033[1;32m========================================\033[0m\n'
printf '\033[1;32m       43PR Hyprland Setup Ready       \033[0m\n'
printf '\033[1;32m========================================\033[0m\n'
printf '\n'

printf 'Distribution:  %s\n' "${PRETTY_NAME:-unknown}"
printf 'Package mgr:   %s\n' "$PACKAGE_MANAGER"
printf 'Configuration: %s\n' "$CONFIG_DIR"

if [[ -d "$BACKUP_DIR" ]]; then
    printf 'Backup:        %s\n' "$BACKUP_DIR"
fi

printf '\n'
warning "Log out and back into Hyprland for the changes to fully take effect."

printf '\n'
info "You can start Hyprland with:"
printf '  Hyprland\n'

printf '\n'
success "Installation complete!"
```

