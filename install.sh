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
#   4. Symlinks this repository's configuration into ~/.config, so the
#      repo is the only copy of each file — editing either path edits
#      the same file, and update.sh never needs to sync or diff anything
#   5. Generates the initial theme
#
# Supported package managers:
#   - pacman       (official repos: Arch, Manjaro, EndeavourOS, CachyOS, etc.)
#   - paru / yay   (AUR helpers, optional but recommended)

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_DIR/.config"
CONFIG_DIR="$HOME/.config"
BACKUP_ROOT="$HOME/.config-backups"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"

# Files written by theme.py at runtime. These are copied once (so they
# exist before the first boot), 
GENERATED_FILES=(
    "kitty/matugen.conf"
    "hypr/hyprlock-colors.conf"
    "gtk-3.0/colors.css"
    "gtk-4.0/colors.css"
    "gtk-3.0/settings.ini"
    "gtk-4.0/settings.ini"
    "rofi/colors.rasi"
    "quickshell/Theme.qml"
)
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

if [[ ! -d "$SRC" ]]; then
    error "No .config directory found at $SRC"
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
# Default shell
# --------------------------------------------------

if [[ -x /bin/zsh ]]; then
    if [[ "$SHELL" != "/bin/zsh" ]]; then
        info "Setting Zsh as the default shell..."

        if chsh -s /bin/zsh; then
            success "Default shell changed to Zsh."
            warning "Log out and back in for the shell change to take effect."
        else
            warning "Failed to change the default shell to Zsh."
        fi
    else
        info "Zsh is already the default shell."
    fi
else
    warning "Zsh is not installed; skipping default shell configuration."
fi

# --------------------------------------------------
# Link dotfiles (symlinked — the repo is the only copy)
# --------------------------------------------------

info "Linking dotfiles..."

mkdir -p "$CONFIG_DIR"

is_generated() {
    local rel="$1" g
    for g in "${GENERATED_FILES[@]}"; do
        [[ "$rel" == "$g" ]] && return 0
    done
    return 1
}

LINK_FAILED=0
LINKED_COUNT=0
BACKED_UP_COUNT=0

while IFS= read -r -d '' src; do
    rel="${src#"$SRC"/}"

    is_generated "$rel" && continue

    dest="$CONFIG_DIR/$rel"
    mkdir -p "$(dirname "$dest")"

    if [[ -L "$dest" ]]; then
        # Already a symlink (e.g. re-running install.sh) — repoint it in
        # case the repo was moved or cloned to a new path.
        ln -sfn "$src" "$dest"
    elif [[ -e "$dest" ]]; then
        # A real file/dir is in the way: back it up, then replace with a link.
        mkdir -p "$BACKUP_DIR/config/$(dirname "$rel")"
        mv "$dest" "$BACKUP_DIR/config/$rel"
        BACKED_UP_COUNT=$((BACKED_UP_COUNT + 1))
        ln -s "$src" "$dest"
    else
        ln -s "$src" "$dest"
    fi

    if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
        LINKED_COUNT=$((LINKED_COUNT + 1))
    else
        LINK_FAILED=1
        error "Failed to link $rel"
    fi
done < <(find "$SRC" \( -type f -o -type l \) -not -path '*/.git/*' -print0)

# ~/.zshrc is installed from .config/.zshrc but lives outside ~/.config
if [[ -f "$SRC/.zshrc" ]]; then
    if [[ -e "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
        mkdir -p "$BACKUP_DIR/home"
        mv "$HOME/.zshrc" "$BACKUP_DIR/home/.zshrc"
        BACKED_UP_COUNT=$((BACKED_UP_COUNT + 1))
    fi
    ln -sfn "$SRC/.zshrc" "$HOME/.zshrc"
    success "Linked ~/.zshrc."
fi

# Generated files: copy once so configs that `include`/`source`/`@import`
# them don't fail to parse before the first `theme apply` runs.
for g in "${GENERATED_FILES[@]}"; do
    [[ -f "$SRC/$g" ]] || continue
    dest="$CONFIG_DIR/$g"
    if [[ ! -e "$dest" || -L "$dest" ]]; then
        # Fresh install, or a stale symlink from an older version of this
        # script — replace with a real, independent copy.
        [[ -L "$dest" ]] && rm -f "$dest"
        mkdir -p "$(dirname "$dest")"
        cp "$SRC/$g" "$dest"
    fi
done

if [[ "$LINK_FAILED" -eq 1 ]]; then
    error "One or more files failed to link. See errors above."
else
    success "Dotfiles linked ($LINKED_COUNT file(s))."
fi

if [[ "$BACKED_UP_COUNT" -gt 0 ]]; then
    info "Replaced $BACKED_UP_COUNT existing file(s) with symlinks; originals saved to:"
    printf '  %s\n' "$BACKUP_DIR"
fi

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
# User directories + default wallpaper
# --------------------------------------------------

info "Creating user directories..."

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
DEFAULT_WALLPAPER_SRC="$REPO_DIR/wallhaven-k8jvm7.jpg"
DEFAULT_WALLPAPER_DEST="$WALLPAPER_DIR/wallhaven-k8jvm7.jpg"

mkdir -p "$HOME/Pictures" "$WALLPAPER_DIR"

# Copy (not symlink) so the picker can rename/delete it freely.
# Never overwrite: if the user already has this file, leave it alone.
if [[ -f "$DEFAULT_WALLPAPER_SRC" && ! -e "$DEFAULT_WALLPAPER_DEST" ]]; then
    cp "$DEFAULT_WALLPAPER_SRC" "$DEFAULT_WALLPAPER_DEST"
fi

success "Pictures and Wallpapers directories ready."

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
# Enable system services
# --------------------------------------------------

if command -v systemctl >/dev/null 2>&1; then
    if pacman -Qi power-profiles-daemon >/dev/null 2>&1; then
        info "Enabling power-profiles-daemon..."

        if sudo systemctl enable --now power-profiles-daemon.service; then
            success "power-profiles-daemon enabled."
        else
            warning "Failed to enable power-profiles-daemon."
        fi
    else
        warning "power-profiles-daemon is not installed; the Power page will not work."
    fi
fi

# --------------------------------------------------
# Permissions
# --------------------------------------------------
#
# Scripts are now symlinks into the repo, so chmod must target the repo's
# real files — a symlink's own permission bits are irrelevant on Linux,
# what matters is the target's. `find -type f` on ~/.config would no
# longer even match these paths, since a symlink is type l, not type f.

info "Setting executable permissions on shell scripts..."

find "$SRC" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} \;

success "Shell script permissions configured."

# --------------------------------------------------
# Default wallpaper (only if the user has no wallpaper recorded yet)
# --------------------------------------------------

THEME_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/43pr/state.json"

if [[ -f "$DEFAULT_WALLPAPER_DEST" ]] && command -v python3 >/dev/null 2>&1; then
    if [[ -f "$THEME_STATE" ]] && grep -q '"wallpaper":' "$THEME_STATE"; then
        info "A wallpaper is already recorded; leaving it alone."
    else
        info "Setting default wallpaper and generating colors..."
        python3 "$CONFIG_DIR/43pr/bin/theme.py" wallpaper "$DEFAULT_WALLPAPER_DEST" \
            || warning "Could not apply the default wallpaper."
    fi
fi

# --------------------------------------------------
# Initial theme (generates the files the configs include)
# --------------------------------------------------

if command -v python3 >/dev/null 2>&1; then
    info "Generating initial theme..."
    python3 "$CONFIG_DIR/43pr/bin/theme.py" apply \
        || warning "Initial theme generation failed."
else
    warning "python3 not found; skipping initial theme generation. Configs will use the committed fallback colors until you install python3 and run 'theme apply'."
fi

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
printf 'Configuration: %s (symlinked to %s)\n' "$CONFIG_DIR" "$SRC"

if [[ "$BACKED_UP_COUNT" -gt 0 ]]; then
    printf 'Backup:        %s\n' "$BACKUP_DIR"
fi

if [[ "${#UNKNOWN_PACKAGES[@]}" -gt 0 ]]; then
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
