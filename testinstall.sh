#!/usr/bin/env bash
#
# 43PR/dotfiles installer — Arch-compatible Linux + Hyprland
#
# Usage:
#   ./install.sh                 # interactive GPU prompt (auto-detected default)
#   ./install.sh --yes           # fully unattended, GPU auto-detected
#   ./install.sh --gpu nvidia    # force GPU(s): nvidia,amd,intel,vm,none (comma-separated)
#   ./install.sh --no-aur        # never touch the AUR (AUR-only packages are skipped)
#   ./install.sh --help
#
# What it does:
#   1. Verifies an Arch-based system and bootstraps an AUR helper if needed
#   2. Detects your GPU(s) and installs the matching driver stack
#   3. Installs everything in packages.txt (official repos first, then AUR),
#      retrying package-by-package so one bad name never aborts the install
#   4. Symlinks .config/* into ~/.config (the repo is the only copy)
#   5. Enables user + system services (PipeWire, NetworkManager, Bluetooth, ...)
#   6. Sets up zsh, Papirus folders, wallpapers dir, Flathub, and the initial theme
#
# Re-running is safe: everything is idempotent.

set -uo pipefail

# --------------------------------------------------
# Paths / config
# --------------------------------------------------

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_DIR/.config"
PACKAGE_FILE="$REPO_DIR/packages.txt"
CONFIG_DIR="$HOME/.config"
BACKUP_ROOT="$HOME/.config-backups"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/43pr"
THEME_STATE="$STATE_DIR/state.json"
THEME_PY="$CONFIG_DIR/43pr/bin/theme.py"

# Files written by theme.py at runtime. They are copied once (not linked) so
# configs that include/source/@import them parse before the first theme run,
# and so theme.py can rewrite them without touching the repo.
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

# System services: "package:unit". Enabled only if the package is installed.
SYSTEM_SERVICES=(
    "networkmanager:NetworkManager.service"
    "bluez:bluetooth.service"
    "power-profiles-daemon:power-profiles-daemon.service"
    "upower:upower.service"
)

# User services: "package:unit". Socket units are preferred where they exist.
USER_SERVICES=(
    "pipewire:pipewire.socket"
    "pipewire-pulse:pipewire-pulse.socket"
    "wireplumber:wireplumber.service"
)

# --------------------------------------------------
# Output helpers
# --------------------------------------------------

info()    { printf '\n\033[1;34m[INFO]\033[0m %s\n' "$1"; }
success() { printf '\n\033[1;32m[DONE]\033[0m %s\n' "$1"; }
warning() { printf '\n\033[1;33m[WARN]\033[0m %s\n' "$1"; }
error()   { printf '\n\033[1;31m[ERROR]\033[0m %s\n' "$1" >&2; }
step()    { printf '\n\033[1;35m==> %s\033[0m\n' "$1"; }

FAILURES=()
note_failure() { FAILURES+=("$1"); warning "$1"; }

# --------------------------------------------------
# Arguments
# --------------------------------------------------

ASSUME_YES=0
NO_AUR=0
GPU_ARG=""

usage() {
    sed -n '3,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes)   ASSUME_YES=1 ;;
        --no-aur)   NO_AUR=1 ;;
        --gpu)
            [[ $# -ge 2 ]] || { error "--gpu needs a value (nvidia,amd,intel,vm,none)"; exit 1; }
            GPU_ARG="$2"; shift ;;
        --gpu=*)    GPU_ARG="${1#--gpu=}" ;;
        -h|--help)  usage; exit 0 ;;
        *)          error "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
done

INTERACTIVE=0
[[ -t 0 && -t 1 && "$ASSUME_YES" -eq 0 ]] && INTERACTIVE=1

# --------------------------------------------------
# Preflight checks
# --------------------------------------------------

step "Preflight checks"

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

if [[ "${ID:-}" != "arch" && "${ID_LIKE:-}" != *arch* ]]; then
    error "This installer is intended for Arch-compatible Linux distributions."
    error "Detected: ${PRETTY_NAME:-unknown}"
    exit 1
fi

for cmd in sudo pacman; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        error "$cmd is required but was not found."
        exit 1
    fi
done

[[ -d "$SRC" ]]          || { error "No .config directory found at $SRC"; exit 1; }
[[ -f "$PACKAGE_FILE" ]] || { error "packages.txt not found at $PACKAGE_FILE"; exit 1; }

info "Detected distribution: ${PRETTY_NAME:-unknown}"

# Cache sudo credentials up front and keep them alive for long AUR builds.
if ! sudo -v; then
    error "Could not obtain sudo privileges."
    exit 1
fi
( while true; do sudo -n true 2>/dev/null; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT

# Package installs are always unattended; only the GPU prompt is interactive.
PACMAN_FLAGS=(--needed --noconfirm)

# --------------------------------------------------
# AUR helper
# --------------------------------------------------

step "AUR helper"

AUR_HELPER=""
if [[ "$NO_AUR" -eq 1 ]]; then
    info "--no-aur given; AUR packages will be skipped."
elif command -v paru >/dev/null 2>&1; then
    AUR_HELPER="paru"
elif command -v yay >/dev/null 2>&1; then
    AUR_HELPER="yay"
else
    info "No AUR helper found. Bootstrapping yay-bin..."
    if sudo pacman -S "${PACMAN_FLAGS[@]}" git base-devel; then
        YAY_BUILD_DIR="$(mktemp -d)"
        if git clone https://aur.archlinux.org/yay-bin.git "$YAY_BUILD_DIR/yay-bin" \
            && (cd "$YAY_BUILD_DIR/yay-bin" && makepkg -si --noconfirm); then
            AUR_HELPER="yay"
            success "yay installed."
        else
            note_failure "Could not build yay automatically. Install paru or yay and re-run to get AUR packages."
        fi
        rm -rf "$YAY_BUILD_DIR"
    else
        note_failure "Could not install git/base-devel; AUR packages will be skipped."
    fi
fi

[[ -n "$AUR_HELPER" ]] && info "Using AUR helper: $AUR_HELPER"

# --------------------------------------------------
# Package helpers
# --------------------------------------------------

# Install a list with pacman. On batch failure, retry one-by-one to isolate culprits.
pac_install() {
    [[ $# -gt 0 ]] || return 0
    if sudo pacman -S "${PACMAN_FLAGS[@]}" "$@"; then
        return 0
    fi
    warning "Batch install failed; retrying packages individually..."
    local p
    for p in "$@"; do
        sudo pacman -S "${PACMAN_FLAGS[@]}" "$p" || note_failure "Failed to install (pacman): $p"
    done
}

aur_install() {
    [[ $# -gt 0 && -n "$AUR_HELPER" ]] || return 0
    if "$AUR_HELPER" -S "${PACMAN_FLAGS[@]}" "$@"; then
        return 0
    fi
    warning "Batch AUR install failed; retrying packages individually..."
    local p
    for p in "$@"; do
        "$AUR_HELPER" -S "${PACMAN_FLAGS[@]}" "$p" || note_failure "Failed to install (AUR): $p"
    done
}

is_installed() { pacman -Qq "$1" >/dev/null 2>&1; }

# Read packages.txt: strips full-line AND inline comments, blanks, duplicates.
read_packages() {
    sed -E 's/[[:space:]]*#.*$//; s/^[[:space:]]+//; s/[[:space:]]+$//' "$PACKAGE_FILE" \
        | grep -v '^$' | awk '!seen[$0]++'
}

# --------------------------------------------------
# GPU detection + selection
# --------------------------------------------------

detect_gpus() {
    local out=() lines
    if command -v lspci >/dev/null 2>&1; then
        lines="$(lspci -nn 2>/dev/null | grep -Ei 'vga compatible|3d controller|display controller')"
    else
        lines=""
    fi

    grep -qi 'nvidia' <<<"$lines"                              && out+=(nvidia)
    grep -Eqi 'advanced micro devices|\bamd\b|\bati\b' <<<"$lines" && out+=(amd)
    grep -qi 'intel' <<<"$lines"                               && out+=(intel)
    grep -Eqi 'virtio|vmware|qxl|virtualbox|red hat' <<<"$lines"   && out+=(vm)

    printf '%s\n' "${out[@]:-}" | grep -v '^$' | paste -sd, -
}

normalize_gpus() {
    # Validate and de-duplicate a comma-separated list. Prints cleaned list or returns 1.
    local item cleaned=()
    IFS=',' read -ra items <<<"${1// /}"
    for item in "${items[@]}"; do
        case "${item,,}" in
            nvidia|amd|intel|vm) cleaned+=("${item,,}") ;;
            none|"")             ;;
            *) return 1 ;;
        esac
    done
    printf '%s\n' "${cleaned[@]:-}" | grep -v '^$' | awk '!s[$0]++' | paste -sd, -
}

step "GPU selection"

DETECTED_GPUS="$(detect_gpus)"
if [[ -n "$DETECTED_GPUS" ]]; then
    info "Detected GPU vendor(s): ${DETECTED_GPUS//,/, }"
else
    info "No GPU detected via lspci (is pciutils installed?)."
fi

SELECTED_GPUS=""
if [[ -n "$GPU_ARG" ]]; then
    if ! SELECTED_GPUS="$(normalize_gpus "$GPU_ARG")"; then
        error "Invalid --gpu value '$GPU_ARG'. Use: nvidia, amd, intel, vm, none (comma-separated)."
        exit 1
    fi
    info "GPU selection from --gpu: ${SELECTED_GPUS:-none}"
elif [[ "$INTERACTIVE" -eq 1 ]]; then
    printf '\nWhich GPU driver stack(s) should be installed?\n'
    printf '  Options: nvidia, amd, intel, vm (virtual machine), none\n'
    printf '  Combine with commas for hybrid setups, e.g. "intel,nvidia".\n'
    while true; do
        read -r -p "GPU(s) [${DETECTED_GPUS:-none}]: " reply </dev/tty
        reply="${reply:-${DETECTED_GPUS:-none}}"
        if SELECTED_GPUS="$(normalize_gpus "$reply")"; then
            break
        fi
        warning "Unrecognised input. Try again (nvidia, amd, intel, vm, none)."
    done
else
    SELECTED_GPUS="$DETECTED_GPUS"
    info "Non-interactive: using detected GPUs: ${SELECTED_GPUS:-none}"
fi

has_gpu() { [[ ",$SELECTED_GPUS," == *",$1,"* ]]; }

# Builds the driver package list for the selected GPUs into GPU_PACKAGES.
GPU_PACKAGES=()
build_gpu_packages() {
    if has_gpu amd; then
        GPU_PACKAGES+=(mesa vulkan-radeon)
    fi

    if has_gpu intel; then
        GPU_PACKAGES+=(mesa vulkan-intel intel-media-driver intel-gpu-tools)
    fi

    if has_gpu vm; then
        GPU_PACKAGES+=(mesa)
    fi

    if has_gpu nvidia; then
        # nvidia-utils provides nvidia-smi, which the bar's GPU probe uses.
        GPU_PACKAGES+=(nvidia-utils nvidia-settings libva-nvidia-driver)

        local kernels=() k
        while IFS= read -r k; do kernels+=("$k"); done \
            < <(pacman -Qq 2>/dev/null | grep -E '^linux(-lts|-zen|-hardened)?$')

        if [[ "${#kernels[@]}" -eq 1 && "${kernels[0]}" == "linux" ]]; then
            GPU_PACKAGES+=(nvidia-open)
        else
            GPU_PACKAGES+=(nvidia-open-dkms dkms)
            for k in "${kernels[@]}"; do GPU_PACKAGES+=("${k}-headers"); done
            [[ "${#kernels[@]}" -eq 0 ]] && warning "No stock Arch kernel found; installing nvidia-open-dkms. Install your kernel's headers package too."
        fi

        warning "nvidia-open supports Turing (RTX 20xx / GTX 16xx) and newer. Older cards need a legacy AUR driver (e.g. nvidia-580xx-dkms); re-run with --gpu none and install it manually."
    fi
}

build_gpu_packages

# --------------------------------------------------
# Packages
# --------------------------------------------------

step "Packages"

mapfile -t PACKAGES < <(read_packages)
mapfile -t GPU_PACKAGES < <(printf '%s\n' "${GPU_PACKAGES[@]:-}" | grep -v '^$' | awk '!s[$0]++')

ALL_PACKAGES=("${PACKAGES[@]}" "${GPU_PACKAGES[@]}")

if [[ "${#ALL_PACKAGES[@]}" -eq 0 ]]; then
    warning "No packages to install."
else
    info "Syncing databases and upgrading the system (avoids partial upgrades)..."
    sudo pacman -Syu --noconfirm \
        || note_failure "System upgrade failed or was incomplete; package installs may fail."

    OFFICIAL_PACKAGES=()
    AUR_PACKAGES=()
    UNKNOWN_PACKAGES=()

    declare -A IN_REPOS=()
    while IFS= read -r name; do IN_REPOS["$name"]=1; done < <(pacman -Slq 2>/dev/null)

    info "Resolving ${#ALL_PACKAGES[@]} package(s) against official repos and the AUR..."
    for pkg in "${ALL_PACKAGES[@]}"; do
        if [[ -n "${IN_REPOS[$pkg]:-}" ]] || pacman -Sg "$pkg" >/dev/null 2>&1; then
            OFFICIAL_PACKAGES+=("$pkg")
        elif [[ -n "$AUR_HELPER" ]] && "$AUR_HELPER" -Si "$pkg" >/dev/null 2>&1; then
            AUR_PACKAGES+=("$pkg")
        else
            UNKNOWN_PACKAGES+=("$pkg")
        fi
    done

    if [[ "${#OFFICIAL_PACKAGES[@]}" -gt 0 ]]; then
        info "Installing ${#OFFICIAL_PACKAGES[@]} official-repo package(s)..."
        pac_install "${OFFICIAL_PACKAGES[@]}"
    fi

    if [[ "${#AUR_PACKAGES[@]}" -gt 0 ]]; then
        info "Installing AUR package(s) with $AUR_HELPER: ${AUR_PACKAGES[*]}"
        aur_install "${AUR_PACKAGES[@]}"
    fi

    if [[ "${#UNKNOWN_PACKAGES[@]}" -gt 0 ]]; then
        if [[ -z "$AUR_HELPER" ]]; then
            note_failure "Skipped (not in official repos, no AUR helper): ${UNKNOWN_PACKAGES[*]}"
        else
            note_failure "Could not resolve in any repo: ${UNKNOWN_PACKAGES[*]}"
        fi
    fi

    success "Package installation finished."
fi

# --------------------------------------------------
# GPU configuration
# --------------------------------------------------

step "GPU configuration"

GPU_CONF="$CONFIG_DIR/hypr/gpu.conf"
mkdir -p "$CONFIG_DIR/hypr"

if has_gpu nvidia && ! has_gpu amd && ! has_gpu intel; then
    cat > "$GPU_CONF" <<'CONF'
# Generated by install.sh — NVIDIA-only system.
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = NVD_BACKEND,direct
CONF
    success "Wrote $GPU_CONF (NVIDIA environment)."
elif has_gpu nvidia; then
    cat > "$GPU_CONF" <<'CONF'
# Generated by install.sh — hybrid system (NVIDIA + integrated GPU).
# Hyprland renders on the first GPU in AQ_DRM_DEVICES. Find your cards with:
#   ls -l /dev/dri/by-path/
# and uncomment, listing the integrated GPU first, e.g.:
# env = AQ_DRM_DEVICES,/dev/dri/card1:/dev/dri/card0
CONF
    success "Wrote $GPU_CONF (hybrid template)."
else
    : > "$GPU_CONF"
    info "No special GPU environment needed."
fi

if [[ -s "$GPU_CONF" ]]; then
    info "Add this line to your Hyprland config to apply it:"
    printf '  source = ~/.config/hypr/gpu.conf\n'
fi

mkdir -p "$STATE_DIR"
printf '%s\n' "${SELECTED_GPUS:-none}" > "$STATE_DIR/gpu"

if has_gpu nvidia; then
    warning "NVIDIA: reboot after install so the kernel module loads. For flicker-free boot, consider early KMS (add nvidia nvidia_modeset nvidia_uvm nvidia_drm to MODULES in /etc/mkinitcpio.conf, then run mkinitcpio -P)."
fi

# --------------------------------------------------
# Default shell
# --------------------------------------------------

step "Default shell"

ZSH_PATH="$(command -v zsh || true)"
if [[ -n "$ZSH_PATH" ]]; then
    if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$ZSH_PATH" ]]; then
        grep -qxF "$ZSH_PATH" /etc/shells || echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
        if sudo chsh -s "$ZSH_PATH" "$USER"; then
            success "Default shell set to Zsh (takes effect at next login)."
        else
            note_failure "Failed to change the default shell to Zsh."
        fi
    else
        info "Zsh is already the default shell."
    fi
else
    warning "Zsh is not installed; skipping shell setup."
fi

# --------------------------------------------------
# Link dotfiles
# --------------------------------------------------

step "Dotfiles"

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

    # .zshrc is linked to ~/.zshrc below, not ~/.config/.zshrc
    [[ "$rel" == ".zshrc" ]] && continue
    is_generated "$rel" && continue

    dest="$CONFIG_DIR/$rel"
    mkdir -p "$(dirname "$dest")"

    if [[ -L "$dest" ]]; then
        ln -sfn "$src" "$dest"
    elif [[ -e "$dest" ]]; then
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

if [[ -f "$SRC/.zshrc" ]]; then
    if [[ -e "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
        mkdir -p "$BACKUP_DIR/home"
        mv "$HOME/.zshrc" "$BACKUP_DIR/home/.zshrc"
        BACKED_UP_COUNT=$((BACKED_UP_COUNT + 1))
    fi
    ln -sfn "$SRC/.zshrc" "$HOME/.zshrc"
    info "Linked ~/.zshrc."
fi

for g in "${GENERATED_FILES[@]}"; do
    [[ -f "$SRC/$g" ]] || continue
    dest="$CONFIG_DIR/$g"
    if [[ ! -e "$dest" || -L "$dest" ]]; then
        [[ -L "$dest" ]] && rm -f "$dest"
        mkdir -p "$(dirname "$dest")"
        cp "$SRC/$g" "$dest"
    fi
done

if [[ "$LINK_FAILED" -eq 1 ]]; then
    note_failure "One or more dotfiles failed to link. See errors above."
else
    success "Dotfiles linked ($LINKED_COUNT file(s))."
fi

if [[ "$BACKED_UP_COUNT" -gt 0 ]]; then
    info "Replaced $BACKED_UP_COUNT existing file(s); originals saved to: $BACKUP_DIR"
fi

# Scripts are symlinks into the repo, so chmod the repo's real files.
find "$SRC" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} \;

# --------------------------------------------------
# Services
# --------------------------------------------------

step "Services"

HAVE_SYSTEMD=0
[[ -d /run/systemd/system ]] && HAVE_SYSTEMD=1

if ! command -v systemctl >/dev/null 2>&1; then
    warning "systemctl not found; skipping all service setup."
else
    # --- system services ---
    for entry in "${SYSTEM_SERVICES[@]}"; do
        pkg="${entry%%:*}"; unit="${entry#*:}"
        if ! is_installed "$pkg"; then
            info "Skipping $unit ($pkg not installed)."
            continue
        fi
        if [[ "$HAVE_SYSTEMD" -eq 1 ]]; then
            sudo systemctl enable --now "$unit" \
                && info "Enabled $unit" \
                || note_failure "Failed to enable $unit"
        else
            sudo systemctl enable "$unit" \
                && info "Enabled $unit (will start on next boot)" \
                || note_failure "Failed to enable $unit"
        fi
    done

    # --- user services ---
    USER_BUS_OK=0
    systemctl --user show-environment >/dev/null 2>&1 && USER_BUS_OK=1

    for entry in "${USER_SERVICES[@]}"; do
        pkg="${entry%%:*}"; unit="${entry#*:}"
        if ! is_installed "$pkg"; then
            info "Skipping user $unit ($pkg not installed)."
            continue
        fi
        if [[ "$USER_BUS_OK" -eq 1 ]]; then
            systemctl --user enable --now "$unit" \
                && info "Enabled user $unit" \
                || note_failure "Failed to enable user $unit"
        else
            systemctl --user enable "$unit" 2>/dev/null \
                && info "Enabled user $unit (starts at next login)" \
                || note_failure "Could not enable user $unit (no user session bus). Log in graphically and re-run."
        fi
    done

    # --- flathub ---
    if is_installed flatpak; then
        sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo \
            && info "Flathub remote configured." \
            || warning "Could not add the Flathub remote (network?)."
    fi

    success "Services configured."
fi

# --------------------------------------------------
# Appearance: Papirus folders, XDG dirs, wallpapers
# --------------------------------------------------

step "Appearance and user directories"

if command -v papirus-folders >/dev/null 2>&1; then
    if sudo papirus-folders -C white --theme Papirus-Dark >/dev/null 2>&1 \
        || sudo papirus-folders -C white >/dev/null 2>&1; then
        info "Papirus folders set to white."
    else
        note_failure "papirus-folders is installed but setting the folder color failed."
    fi
else
    warning "papirus-folders not available; skipping folder color."
fi

command -v xdg-user-dirs-update >/dev/null 2>&1 && xdg-user-dirs-update

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
DEFAULT_WALLPAPER_SRC="$REPO_DIR/wallhaven-k8jvm7.jpg"
DEFAULT_WALLPAPER_DEST="$WALLPAPER_DIR/wallhaven-k8jvm7.jpg"

mkdir -p "$WALLPAPER_DIR"

# Copy (not symlink) so the picker can rename/delete it. Never overwrite.
if [[ -f "$DEFAULT_WALLPAPER_SRC" && ! -e "$DEFAULT_WALLPAPER_DEST" ]]; then
    cp "$DEFAULT_WALLPAPER_SRC" "$DEFAULT_WALLPAPER_DEST"
fi

success "Directories ready."

# --------------------------------------------------
# Theme
# --------------------------------------------------

step "Theme"

if command -v python3 >/dev/null 2>&1 && [[ -f "$THEME_PY" ]]; then
    if [[ -f "$DEFAULT_WALLPAPER_DEST" ]] && ! { [[ -f "$THEME_STATE" ]] && grep -q '"wallpaper":' "$THEME_STATE"; }; then
        info "Setting default wallpaper and generating colors..."
        python3 "$THEME_PY" wallpaper "$DEFAULT_WALLPAPER_DEST" \
            || note_failure "Could not apply the default wallpaper."
    fi

    info "Generating initial theme..."
    python3 "$THEME_PY" apply || note_failure "Initial theme generation failed."
else
    warning "python3 or theme.py missing; configs will use committed fallback colors until you run 'theme apply'."
fi

# --------------------------------------------------
# Summary
# --------------------------------------------------

printf '\n\033[1;32m========================================\033[0m\n'
printf '\033[1;32m       43PR Hyprland Setup Ready       \033[0m\n'
printf '\033[1;32m========================================\033[0m\n\n'

printf 'Distribution:  %s\n' "${PRETTY_NAME:-unknown}"
printf 'AUR helper:    %s\n' "${AUR_HELPER:-none}"
printf 'GPU stack:     %s\n' "${SELECTED_GPUS:-none}"
printf 'Configuration: %s (symlinked to %s)\n' "$CONFIG_DIR" "$SRC"
[[ "$BACKED_UP_COUNT" -gt 0 ]] && printf 'Backup:        %s\n' "$BACKUP_DIR"

if [[ "${#FAILURES[@]}" -gt 0 ]]; then
    printf '\n\033[1;33mCompleted with %d issue(s):\033[0m\n' "${#FAILURES[@]}"
    printf '  - %s\n' "${FAILURES[@]}"
else
    success "Everything installed without issues."
fi

printf '\n'
warning "Reboot (or at least log out and back in) for services, the shell change and GPU drivers to take effect."
info "Then start Hyprland with:"
printf '  Hyprland\n\n'
