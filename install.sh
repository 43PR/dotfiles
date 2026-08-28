#!/usr/bin/env bash

set -uo pipefail

# 43PR/dotfiles installer
# Arch-compatible Linux + Hyprland
#
# Usage:
#   ./install.sh
#
# This script:
#   1. Verifies that the system is Arch-based
#   2. Detects the available package manager(s)
#   3. Splits packages.txt into "official repo" vs "AUR-only" and
#      installs each with the right tool, so a single AUR-only or
#      unresolvable name never aborts the whole install
#   4. Backs up existing ~/.config
#   5. Installs this repository's configuration
#
# Supported package managers:
#   - pacman       (official repos: Arch, Manjaro, EndeavourOS, CachyOS, etc.)
#   - paru / yay   (AUR helpers, optional but recommended)
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

if ! command -v pacman >/dev/null 2>&1; then
    error "pacman was not found. This installer requires an Arch-based system."
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

AUR_HELPER=""
if command -v paru >/dev/null 2>&1; then
    AUR_HELPER="paru"
elif command -v yay >/dev/null 2>&1; then
    AUR_HELPER="yay"
fi

info "Detected distribution: ${PRETTY_NAME:-unknown}"

if [[ -n "$AUR_HELPER" ]]; then
    info "AUR helper available: $AUR_HELPER"
else
    info "No AUR helper found. Bootstrapping yay..."

    if sudo pacman -S --needed --noconfirm git base-devel; then
        YAY_BUILD_DIR="$(mktemp -d)"

        if git clone https://aur.archlinux.org/yay.git "$YAY_BUILD_DIR/yay" \
            && (cd "$YAY_BUILD_DIR/yay" && makepkg -si --noconfirm); then
            AUR_HELPER="yay"
            success "yay installed."
        else
            warning "Failed to build/install yay automatically."
            warning "You can install one manually (paru or yay) and re-run this script."
        fi

        rm -rf "$YAY_BUILD_DIR"
    else
        warning "Failed to install git/base-devel; cannot bootstrap an AUR helper."
        warning "AUR-only packages will be listed but skipped."
    fi
fi

# --------------------------------------------------
# Packages: split into official-repo vs AUR-only
# --------------------------------------------------

mapfile -t PACKAGES < <(
    grep -vE '^[[:space:]]*(#|$)' "$PACKAGE_FILE"
)

OFFICIAL_PACKAGES=()
AUR_PACKAGES=()
UNKNOWN_PACKAGES=()

if [[ "${#PACKAGES[@]}" -eq 0 ]]; then
    warning "packages.txt does not contain any packages."
else
    info "Resolving packages against official repos..."

    for pkg in "${PACKAGES[@]}"; do
        if pacman -Si "$pkg" >/dev/null 2>&1; then
            OFFICIAL_PACKAGES+=("$pkg")
        elif [[ -n "$AUR_HELPER" ]] && "$AUR_HELPER" -Si "$pkg" >/dev/null 2>&1; then
            AUR_PACKAGES+=("$pkg")
        else
            UNKNOWN_PACKAGES+=("$pkg")
        fi
    done

    if [[ "${#OFFICIAL_PACKAGES[@]}" -gt 0 ]]; then
        info "Installing official-repo packages..."
        if sudo pacman -Syu --needed --noconfirm "${OFFICIAL_PACKAGES[@]}"; then
            success "Official-repo packages installed."
        else
            warning "pacman reported an error installing one or more official-repo packages. Continuing anyway."
        fi
    fi

    if [[ "${#AUR_PACKAGES[@]}" -gt 0 ]]; then
        if [[ -n "$AUR_HELPER" ]]; then
            info "Installing AUR packages with $AUR_HELPER: ${AUR_PACKAGES[*]}"
            if "$AUR_HELPER" -S --needed --noconfirm "${AUR_PACKAGES[@]}"; then
                success "AUR packages installed."
            else
                warning "$AUR_HELPER reported an error installing one or more AUR packages. Continuing anyway."
            fi
        fi
    fi

    if [[ "${#UNKNOWN_PACKAGES[@]}" -gt 0 ]]; then
        warning "Could not resolve the following package(s) in any repo: ${UNKNOWN_PACKAGES[*]}"
        warning "Check the name with 'pacman -Ss <name>' or https://aur.archlinux.org, then fix packages.txt."
    fi
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
# Papirus folder color
# --------------------------------------------------

if [[ -n "$AUR_HELPER" ]]; then
    info "Installing Papirus folders..."

    if "$AUR_HELPER" -S --needed --noconfirm papirus-folders; then
        if papirus-folders -C white; then
            success "Papirus folders set to white."
        else
            warning "papirus-folders was installed, but setting the folder color failed."
        fi
    else
        warning "Failed to install papirus-folders."
    fi
else
    warning "No AUR helper available; skipping papirus-folders."
fi

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
printf 'AUR helper:    %s\n' "${AUR_HELPER:-none}"
printf 'Configuration: %s\n' "$CONFIG_DIR"

if [[ -d "$BACKUP_DIR" ]]; then
    printf 'Backup:        %s\n' "$BACKUP_DIR"
fi

if [[ "${#UNKNOWN_PACKAGES[@]:-0}" -gt 0 ]]; then
    printf '\n'
    warning "Unresolved packages (install manually): ${UNKNOWN_PACKAGES[*]}"
fi

printf '\n'
warning "Log out and back into Hyprland for the changes to fully take effect."

printf '\n'
info "You can start Hyprland with:"
printf '  Hyprland\n'

printf '\n'
success "Installation complete!"
