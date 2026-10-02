#!/usr/bin/env bash

set -uo pipefail

# 43PR/dotfiles updater (symlink model)
#
# Dotfiles are symlinked from the repo into ~/.config, so editing either
# path edits the same file — there is nothing to sync for existing files.
#   1. Install any new packages.txt entries
#   2. Link any files newly added to the repo since the last run
#   3. Regenerate the theme
#
# Usage:
#   ./update.sh
#   ./update.sh --dry-run
#   ./update.sh --skip-packages
#   ./update.sh --skip-theme
#   ./update.sh --restart-shell

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_DIR/.config"
CONFIG_DIR="$HOME/.config"
PACKAGE_FILE="$REPO_DIR/packages.txt"

GENERATED_FILES=(
    "kitty/matugen.conf"
    "waybar/colors.css"
    "hypr/hyprlock-colors.conf"
    "gtk-3.0/colors.css"
    "gtk-4.0/colors.css"
    "rofi/colors.rasi"
    "quickshell/state/powermenu-state.json"
    "quickshell/state/settings-state.json"
)

DRY_RUN=0
SKIP_PACKAGES=0
SKIP_THEME=0
RESTART_SHELL=0

for arg in "$@"; do
    case "$arg" in
        --dry-run)       DRY_RUN=1 ;;
        --skip-packages) SKIP_PACKAGES=1 ;;
        --skip-theme)    SKIP_THEME=1 ;;
        --restart-shell) RESTART_SHELL=1 ;;
        *)
            printf '\033[1;31m[ERROR]\033[0m Unknown option: %s\n' "$arg" >&2
            exit 1
            ;;
    esac
done

info()    { printf '\n\033[1;34m[INFO]\033[0m %s\n' "$1"; }
success() { printf '\n\033[1;32m[DONE]\033[0m %s\n' "$1"; }
warning() { printf '\n\033[1;33m[WARN]\033[0m %s\n' "$1"; }
error()   { printf '\n\033[1;31m[ERROR]\033[0m %s\n' "$1" >&2; }

if [[ "${EUID}" -eq 0 ]]; then
    error "Do not run this script as root."
    exit 1
fi

if [[ ! -d "$SRC" ]]; then
    error "No .config directory found at $SRC"
    exit 1
fi

is_generated() {
    local rel="$1" g
    for g in "${GENERATED_FILES[@]}"; do
        [[ "$rel" == "$g" ]] && return 0
    done
    return 1
}

# --------------------------------------------------
# Packages
# --------------------------------------------------

UNKNOWN_PACKAGES=()

if [[ "$SKIP_PACKAGES" -eq 1 ]]; then
    info "Skipping package installation (--skip-packages)."
elif ! command -v pacman >/dev/null 2>&1; then
    error "pacman was not found. This updater requires an Arch-based system."
    exit 1
elif [[ ! -f "$PACKAGE_FILE" ]]; then
    warning "packages.txt not found; skipping package installation."
else
    mapfile -t PACKAGES < <(grep -vE '^[[:space:]]*(#|$)' "$PACKAGE_FILE")

    MISSING=()
    for pkg in "${PACKAGES[@]}"; do
        pacman -Qi "$pkg" >/dev/null 2>&1 || MISSING+=("$pkg")
    done

    if [[ "${#MISSING[@]}" -eq 0 ]]; then
        info "Packages: everything in packages.txt is already installed."
    elif [[ "$DRY_RUN" -eq 1 ]]; then
        info "Would install (${#MISSING[@]}): ${MISSING[*]}"
    elif ! command -v sudo >/dev/null 2>&1; then
        warning "sudo not found; skipping package installation."
    else
        AUR_HELPER=""
        if command -v paru >/dev/null 2>&1; then
            AUR_HELPER="paru"
        elif command -v yay >/dev/null 2>&1; then
            AUR_HELPER="yay"
        fi

        OFFICIAL_PACKAGES=()
        AUR_PACKAGES=()

        info "Resolving new packages..."
        for pkg in "${MISSING[@]}"; do
            if pacman -Si "$pkg" >/dev/null 2>&1; then
                OFFICIAL_PACKAGES+=("$pkg")
            elif [[ -n "$AUR_HELPER" ]] && "$AUR_HELPER" -Si "$pkg" >/dev/null 2>&1; then
                AUR_PACKAGES+=("$pkg")
            else
                UNKNOWN_PACKAGES+=("$pkg")
            fi
        done

        if [[ "${#OFFICIAL_PACKAGES[@]}" -gt 0 ]]; then
            info "Installing new official-repo packages: ${OFFICIAL_PACKAGES[*]}"
            if sudo pacman -S --needed --noconfirm "${OFFICIAL_PACKAGES[@]}"; then
                success "Official-repo packages installed."
            else
                warning "pacman reported an error. If it was a 404 or stale database, run 'sudo pacman -Syu' and re-run this script."
            fi
        fi

        if [[ "${#AUR_PACKAGES[@]}" -gt 0 ]]; then
            if [[ -n "$AUR_HELPER" ]]; then
                info "Installing new AUR packages with $AUR_HELPER: ${AUR_PACKAGES[*]}"
                if "$AUR_HELPER" -S --needed --noconfirm "${AUR_PACKAGES[@]}"; then
                    success "AUR packages installed."
                else
                    warning "$AUR_HELPER reported an error installing one or more packages. Continuing anyway."
                fi
            else
                warning "No AUR helper found; cannot install: ${AUR_PACKAGES[*]}"
                warning "Run install.sh once to bootstrap an AUR helper, or install one manually."
            fi
        fi

        if [[ "${#UNKNOWN_PACKAGES[@]}" -gt 0 ]]; then
            warning "Could not resolve the following package(s) in any repo: ${UNKNOWN_PACKAGES[*]}"
            warning "Check the name with 'pacman -Ss <name>' or https://aur.archlinux.org, then fix packages.txt."
        fi
    fi
fi

# --------------------------------------------------
# Link anything new
# --------------------------------------------------

NEW_LINKS=0
SKIPPED_REAL_FILES=0

while IFS= read -r -d '' src; do
    rel="${src#"$SRC"/}"

    is_generated "$rel" && continue

    dest="$CONFIG_DIR/$rel"
    [[ -L "$dest" ]] && continue   # already linked, nothing to do

    if [[ "$DRY_RUN" -eq 1 ]]; then
        if [[ -e "$dest" ]]; then
            info "Would skip (real file exists, not overwriting): $rel"
        else
            info "Would link: $rel"
        fi
        NEW_LINKS=$((NEW_LINKS + 1))
        continue
    fi

    if [[ -e "$dest" ]]; then
        warning "A real file exists at $rel — leaving it, not overwriting. Remove it manually to let the symlink take over, or re-run install.sh to migrate it safely (it backs up before replacing)."
        SKIPPED_REAL_FILES=$((SKIPPED_REAL_FILES + 1))
        continue
    fi

    mkdir -p "$(dirname "$dest")"
    ln -s "$src" "$dest"
    NEW_LINKS=$((NEW_LINKS + 1))
done < <(find "$SRC" -type f -not -path '*/.git/*' -print0)

# Generated files: ensure they exist (copy once), never link.
if [[ "$DRY_RUN" -eq 0 ]]; then
    for g in "${GENERATED_FILES[@]}"; do
        [[ -f "$SRC/$g" ]] || continue
        dest="$CONFIG_DIR/$g"
        if [[ ! -e "$dest" ]]; then
            mkdir -p "$(dirname "$dest")"
            cp "$SRC/$g" "$dest"
        fi
    done
fi

if [[ "$NEW_LINKS" -eq 0 ]]; then
    success "No new files to link."
elif [[ "$DRY_RUN" -eq 0 ]]; then
    success "Linked $NEW_LINKS new file(s)."
fi

[[ "$SKIPPED_REAL_FILES" -gt 0 ]] && warning "$SKIPPED_REAL_FILES file(s) skipped — see warnings above."

if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '\n'
    info "Dry run: nothing was written. Re-run without --dry-run to apply."
    exit 0
fi

# --------------------------------------------------
# Regenerate theme
# --------------------------------------------------

if [[ "$SKIP_THEME" -eq 1 ]]; then
    info "Skipping theme regeneration (--skip-theme)."
elif command -v python3 >/dev/null 2>&1; then
    info "Regenerating theme from current palette..."
    if python3 "$CONFIG_DIR/43pr/bin/theme.py" apply; then
        success "Theme regenerated and consumers reloaded (Kitty, Waybar)."
    else
        error "Theme regeneration failed, check the error above."
        exit 1
    fi
else
    warning "python3 not found; theme was NOT regenerated."
fi

# --------------------------------------------------
# Manual-reload reminders
# --------------------------------------------------

printf '\n'
warning "GTK apps (Thunar) cache colors per-process. If Thunar looks stale: thunar -q && thunar"
warning "Rofi re-read CSS on next launch, no action needed."
warning "Hyprlock re-reads its config on next lock, no action needed."

if [[ "$RESTART_SHELL" -eq 1 ]]; then
    info "Restarting Quickshell (qs)..."
    pkill -x qs 2>/dev/null || true
    sleep 1
    nohup qs >/dev/null 2>&1 &
    disown
    success "Quickshell restarted."
else
    warning "Quickshell (qs) was NOT restarted. Only needed if a .qml file changed; re-run with --restart-shell if so."
fi

if [[ "${#UNKNOWN_PACKAGES[@]}" -gt 0 ]]; then
    printf '\n'
    warning "Unresolved packages (install manually): ${UNKNOWN_PACKAGES[*]}"
fi

printf '\n'
success "Update complete."
