#!/usr/bin/env bash

set -uo pipefail

# 43PR/dotfiles updater v2
#
# The repo is the source of truth for the desktop. Every file in .config is
# symlinked into ~/.config and repaired on each run, EXCEPT:
#
#   USER_OWNED     your personal files (fastfetch, cava, rofi config, themes,
#                  quickshell/state, ...). Copied once if missing, then never
#                  touched again. New files shipped by the repo are added,
#                  your edited ones are kept.
#   GENERATED      written by theme.py (colors etc). Copied once, never linked.
#
# Steps:
#   1. (optional) git pull
#   2. Install new packages.txt entries
#   3. Link new files, repair wrong links, replace real files in the way
#      (backed up first), remove stale links for files deleted/renamed in repo
#   4. Seed user-owned + generated files
#   5. Regenerate theme, reload Hyprland
#
# Usage:
#   ./update2.sh                  normal update
#   ./update2.sh --dry-run        show what would change, write nothing
#   ./update2.sh --pull           bring the repo to upstream first (automatic;
#                                 diverged local work is backed up, upstream wins)
#   ./update2.sh --skip-packages
#   ./update2.sh --skip-theme
#   ./update2.sh --restart-shell  restart Quickshell afterwards
#   ./update2.sh --reset-user     overwrite user-owned files with repo versions
#                                 (originals are backed up)

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_DIR/.config"
CONFIG_DIR="$HOME/.config"
PACKAGE_FILE="$REPO_DIR/packages.txt"
BACKUP_DIR="$HOME/.config-backups/$(date '+%Y-%m-%d_%H-%M-%S')"

# Glob patterns, relative to ~/.config. Edit freely.
USER_OWNED=(
    "quickshell/state/*"
    "fastfetch/*"
    "cava/*"
    "rofi/config.rasi"
    "43pr/themes/*"
    "btop/btop.conf"
    "neofetch/*"
    "nwg-look/*"
    "xed/*"
    "spicetify/config-xpui.ini"
    "starship.toml"
    "hypr/monitors.lua"
)

# Written by theme.py at runtime.
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

# Args to pass along when the script re-runs itself after pulling.
REST_ARGS=()
for arg in "$@"; do
    [[ "$arg" == "--pull" ]] || REST_ARGS+=("$arg")
done

DRY_RUN=0
PULL=0
SKIP_PACKAGES=0
SKIP_THEME=0
RESTART_SHELL=0
RESET_USER=0

for arg in "$@"; do
    case "$arg" in
        --dry-run)       DRY_RUN=1 ;;
        --pull)          PULL=1 ;;
        --skip-packages) SKIP_PACKAGES=1 ;;
        --skip-theme)    SKIP_THEME=1 ;;
        --restart-shell) RESTART_SHELL=1 ;;
        --reset-user)    RESET_USER=1 ;;
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

is_user_owned() {
    local rel="$1" p
    for p in "${USER_OWNED[@]}"; do
        # shellcheck disable=SC2053
        [[ "$rel" == $p ]] && return 0
    done
    return 1
}

backup() {   # backup <path> <subpath>
    mkdir -p "$BACKUP_DIR/$(dirname "$2")"
    mv "$1" "$BACKUP_DIR/$2"
}

# --------------------------------------------------
# Pull
# --------------------------------------------------

# Brings the repo to upstream without ever stopping to ask. Fast-forwards when
# possible; if history diverged or local edits are in the way, the repo wins:
#   - local commits are kept on a backup/pre-update-* branch
#   - uncommitted edits are kept in `git stash list`
#   - then the branch is reset to upstream
sync_repo_upstream_wins() {
    local g=(git -C "$REPO_DIR") stamp ahead behind
    stamp="$(date '+%Y%m%d-%H%M%S')"

    "${g[@]}" fetch --quiet || { error "git fetch failed (network?)."; return 1; }
    if ! "${g[@]}" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
        warning "No upstream branch configured; skipping pull."
        return 0
    fi

    read -r ahead behind < <("${g[@]}" rev-list --left-right --count 'HEAD...@{u}')
    if [[ "$behind" -eq 0 ]]; then
        info "Repository already up to date."
        return 0
    fi

    if "${g[@]}" pull --ff-only --quiet 2>/dev/null; then
        return 0
    fi

    warning "Local repo state conflicts with upstream; saving it and taking upstream."
    if [[ "$ahead" -gt 0 ]]; then
        "${g[@]}" branch "backup/pre-update-$stamp" HEAD >/dev/null 2>&1 \
            && info "Local commits saved to branch backup/pre-update-$stamp"
    fi
    if [[ -n "$("${g[@]}" status --porcelain)" ]]; then
        "${g[@]}" stash push -u -m "update2.sh auto-stash $stamp" >/dev/null \
            && info "Uncommitted edits saved in 'git stash list'"
    fi
    "${g[@]}" reset --hard '@{u}' >/dev/null || { error "git reset failed."; return 1; }
    return 0
}


if [[ "$PULL" -eq 1 ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
        info "Would run: git pull --ff-only"
    elif git -C "$REPO_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        info "Pulling latest changes..."
        if sync_repo_upstream_wins; then
            success "Repository up to date."
            # The pull may have changed this script; re-run the fresh copy.
            exec bash "${BASH_SOURCE[0]}" "${REST_ARGS[@]}"
        else
            exit 1
        fi
    else
        warning "$REPO_DIR is not a git repository; skipping pull."
    fi
fi

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
    mapfile -t PACKAGES < <(sed -E 's/[[:space:]]*#.*$//; s/^[[:space:]]+//; s/[[:space:]]+$//; /^$/d' "$PACKAGE_FILE")

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
            info "Installing official-repo packages: ${OFFICIAL_PACKAGES[*]}"
            if sudo pacman -S --needed --noconfirm "${OFFICIAL_PACKAGES[@]}"; then
                success "Official-repo packages installed."
            else
                warning "pacman reported an error. If it was a 404 or stale database, run 'sudo pacman -Syu' and re-run this script."
            fi
        fi

        if [[ "${#AUR_PACKAGES[@]}" -gt 0 ]]; then
            if [[ -n "$AUR_HELPER" ]]; then
                info "Installing AUR packages with $AUR_HELPER: ${AUR_PACKAGES[*]}"
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
            warning "Could not resolve in any repo: ${UNKNOWN_PACKAGES[*]}"
            warning "Check the name with 'pacman -Ss <name>' or https://aur.archlinux.org, then fix packages.txt."
        fi
    fi
fi

# --------------------------------------------------
# Link / repair / seed
# --------------------------------------------------

NEW_LINKS=0
FIXED_LINKS=0
REPLACED_FILES=0
SEEDED=0
MIGRATED=0
RESET_COUNT=0
STALE_REMOVED=0

# ensure_link <src> <dest> <label> <backup-subpath>
ensure_link() {
    local src="$1" dest="$2" label="$3" bak="$4" action

    if [[ -L "$dest" ]]; then
        [[ "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]] && return 0
        action="repoint"
    elif [[ -e "$dest" ]]; then
        action="replace"
    else
        action="link"
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        info "Would $action: $label"
    else
        mkdir -p "$(dirname "$dest")"
        if [[ "$action" == "replace" ]]; then
            backup "$dest" "$bak"
            REPLACED_FILES=$((REPLACED_FILES + 1))
        fi
        ln -sfn "$src" "$dest"
    fi

    if [[ "$action" == "link" ]]; then
        NEW_LINKS=$((NEW_LINKS + 1))
    else
        FIXED_LINKS=$((FIXED_LINKS + 1))
    fi
}

# seed_file <src> <dest> <rel>   (user-owned: copy once, keep edits)
seed_file() {
    local src="$1" dest="$2" rel="$3" tmp

    if [[ -L "$dest" ]]; then
        # Old symlinked install: turn into a real, independent copy.
        if [[ "$DRY_RUN" -eq 1 ]]; then
            info "Would convert link to real copy: $rel"
        else
            tmp="$(mktemp)"
            if cp -L "$dest" "$tmp" 2>/dev/null; then
                rm -f "$dest" && mv "$tmp" "$dest"
            else
                rm -f "$tmp" "$dest"
                cp "$src" "$dest"
            fi
        fi
        MIGRATED=$((MIGRATED + 1))
    elif [[ ! -e "$dest" ]]; then
        if [[ "$DRY_RUN" -eq 1 ]]; then
            info "Would seed: $rel"
        else
            mkdir -p "$(dirname "$dest")"
            cp "$src" "$dest"
        fi
        SEEDED=$((SEEDED + 1))
    elif [[ "$RESET_USER" -eq 1 ]]; then
        if cmp -s "$src" "$dest"; then
            return 0
        fi
        if [[ "$DRY_RUN" -eq 1 ]]; then
            info "Would reset to repo version: $rel"
        else
            backup "$dest" "config/$rel"
            cp "$src" "$dest"
        fi
        RESET_COUNT=$((RESET_COUNT + 1))
    fi
}

info "Syncing dotfiles..."

[[ "$DRY_RUN" -eq 0 ]] && mkdir -p "$CONFIG_DIR/quickshell/state"

while IFS= read -r -d '' src; do
    rel="${src#"$SRC"/}"
    dest="$CONFIG_DIR/$rel"

    [[ "$rel" == ".zshrc" ]] && continue          # handled below
    is_generated "$rel" && continue                # handled below

    if is_user_owned "$rel"; then
        seed_file "$src" "$dest" "$rel"
    else
        ensure_link "$src" "$dest" "$rel" "config/$rel"
    fi
done < <(find "$SRC" \( -type f -o -type l \) -not -path '*/.git/*' -print0)

# ~/.zshrc lives outside ~/.config
if [[ -f "$SRC/.zshrc" ]]; then
    ensure_link "$SRC/.zshrc" "$HOME/.zshrc" ".zshrc" "home/.zshrc"
fi

# Remove dangling links pointing into the repo (files deleted or renamed there)
while IFS= read -r -d '' l; do
    t="$(readlink "$l")"
    [[ "$t" == "$SRC"/* && ! -e "$l" ]] || continue
    if [[ "$DRY_RUN" -eq 1 ]]; then
        info "Would remove stale link: ${l#"$CONFIG_DIR"/}"
    else
        rm -f "$l"
        # tidy now-empty parent dirs (never ~/.config itself)
        d="$(dirname "$l")"
        while [[ "$d" != "$CONFIG_DIR" && "$d" == "$CONFIG_DIR"/* ]] && rmdir "$d" 2>/dev/null; do
            d="$(dirname "$d")"
        done
    fi
    STALE_REMOVED=$((STALE_REMOVED + 1))
done < <(find "$CONFIG_DIR" -type l -print0 2>/dev/null)

if [[ "$DRY_RUN" -eq 0 ]]; then
    # Generated files: real copies, created once, never linked.
    for g in "${GENERATED_FILES[@]}"; do
        [[ -f "$SRC/$g" ]] || continue
        dest="$CONFIG_DIR/$g"
        [[ -L "$dest" ]] && rm -f "$dest"
        if [[ ! -e "$dest" ]]; then
            mkdir -p "$(dirname "$dest")"
            cp "$SRC/$g" "$dest"
        fi
    done

    # Scripts may be new or have lost their exec bit.
    find "$SRC" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} \;
fi

# --------------------------------------------------
# Summary of sync
# --------------------------------------------------

success "Linked $NEW_LINKS new, repaired $FIXED_LINKS, removed $STALE_REMOVED stale link(s)."
[[ "$SEEDED"   -gt 0 ]] && info "Added $SEEDED new user-owned file(s) (your existing ones were kept)."
[[ "$MIGRATED" -gt 0 ]] && info "Converted $MIGRATED old symlinked user file(s) into real copies."
[[ "$RESET_COUNT" -gt 0 ]] && info "Reset $RESET_COUNT user-owned file(s) to repo versions (--reset-user)."

if [[ "$REPLACED_FILES" -gt 0 || "$RESET_COUNT" -gt 0 ]]; then
    info "Originals that were replaced are saved in:"
    printf '  %s\n' "$BACKUP_DIR"
fi

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
        success "Theme regenerated and consumers reloaded."
    else
        error "Theme regeneration failed, check the error above."
        exit 1
    fi
else
    warning "python3 not found; theme was NOT regenerated."
fi

# --------------------------------------------------
# Reload desktop
# --------------------------------------------------

if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
    info "Reloading Hyprland config..."
    hyprctl reload >/dev/null 2>&1 && success "Hyprland reloaded." \
        || warning "hyprctl reload failed."
else
    warning "Not inside a Hyprland session; skipped reload. Log in again or run 'hyprctl reload'."
fi

if [[ "$RESTART_SHELL" -eq 1 ]]; then
    info "Restarting Quickshell (qs)..."
    pkill -x qs 2>/dev/null || true
    sleep 1
    nohup qs >/dev/null 2>&1 &
    disown
    success "Quickshell restarted."
else
    warning "Quickshell was NOT restarted. Edits usually live-reload; if not, re-run with --restart-shell."
fi

warning "GTK apps (Thunar) cache colors per-process. If stale: thunar -q && thunar"

if [[ "${#UNKNOWN_PACKAGES[@]}" -gt 0 ]]; then
    printf '\n'
    warning "Unresolved packages (install manually): ${UNKNOWN_PACKAGES[*]}"
fi

printf '\n'
success "Update complete."
