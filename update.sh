#!/usr/bin/env bash

set -uo pipefail

# 43PR/dotfiles updater
#
# Fast-path sync for iterating on the dotfiles after the initial install.sh
# run. It:
#   1. Installs any packages from packages.txt that are not installed yet
#   2. Compares every file in the repo's .config (and .zshrc) with what is
#      installed, and prints exactly which files are NEW or UPDATED
#   3. Backs up only the files it is about to overwrite
#   4. Copies only the files that actually changed
#   5. Regenerates the theme
#
# Does NOT touch: default shell, PipeWire services, Papirus folders, or
# wallpapers (one-time install.sh concerns). It never deletes files, so
# anything you added to ~/.config yourself is left alone.
#
# Usage:
#   ./update.sh                   install new packages, sync, regenerate theme
#   ./update.sh --dry-run         show what would change, write nothing
#   ./update.sh --diff            also print a diff for every updated file
#   ./update.sh --skip-packages   skip package installation
#   ./update.sh --skip-theme      do not run 'theme.py apply'
#   ./update.sh --restart-shell   also restart Quickshell (qs)
#   ./update.sh --help            show this help
#
# Backups live in ~/.config-backups/update-<timestamp>/ and only contain the
# files that were overwritten. The newest 5 update backups are kept.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
SRC="$REPO_DIR/.config"
PACKAGE_FILE="$REPO_DIR/packages.txt"
BACKUP_ROOT="$HOME/.config-backups"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
BACKUP_DIR="$BACKUP_ROOT/update-$TIMESTAMP"
KEEP_BACKUPS=5

DRY_RUN=0
SHOW_DIFF=0
RESTART_SHELL=0
SKIP_PACKAGES=0
SKIP_THEME=0

info()    { printf '\n\033[1;34m[INFO]\033[0m %s\n' "$1"; }
success() { printf '\n\033[1;32m[DONE]\033[0m %s\n' "$1"; }
warning() { printf '\n\033[1;33m[WARN]\033[0m %s\n' "$1"; }
error()   { printf '\n\033[1;31m[ERROR]\033[0m %s\n' "$1" >&2; }

usage() {
    sed -n '3,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

for arg in "$@"; do
    case "$arg" in
        --dry-run)        DRY_RUN=1 ;;
        --diff)           SHOW_DIFF=1 ;;
        --restart-shell)  RESTART_SHELL=1 ;;
        --skip-packages)  SKIP_PACKAGES=1 ;;
        --skip-theme)     SKIP_THEME=1 ;;
        -h|--help)        usage; exit 0 ;;
        *)
            error "Unknown option: $arg (try --help)"
            exit 1
            ;;
    esac
done

if [[ "${EUID}" -eq 0 ]]; then
    error "Do not run this script as root."
    exit 1
fi

if [[ ! -d "$SRC" ]]; then
    error "No .config directory found at $SRC"
    exit 1
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
    mapfile -t PACKAGES < <(grep -vE '^[[:space:]]*(#|$)' "$PACKAGE_FILE")

    if [[ "${#PACKAGES[@]}" -eq 0 ]]; then
        warning "packages.txt does not contain any packages."
    elif [[ "$DRY_RUN" -eq 1 ]]; then
        # Fast check only: which packages are not installed yet?
        MISSING=()
        for pkg in "${PACKAGES[@]}"; do
            pacman -Qi "$pkg" >/dev/null 2>&1 || MISSING+=("$pkg")
        done

        if [[ "${#MISSING[@]}" -eq 0 ]]; then
            info "Packages: everything in packages.txt is already installed."
        else
            info "Packages that would be installed (${#MISSING[@]}): ${MISSING[*]}"
        fi
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

        info "Checking packages.txt against installed packages..."

        for pkg in "${PACKAGES[@]}"; do
            if pacman -Qi "$pkg" >/dev/null 2>&1; then
                continue
            elif pacman -Si "$pkg" >/dev/null 2>&1; then
                OFFICIAL_PACKAGES+=("$pkg")
            elif [[ -n "$AUR_HELPER" ]] && "$AUR_HELPER" -Si "$pkg" >/dev/null 2>&1; then
                AUR_PACKAGES+=("$pkg")
            else
                UNKNOWN_PACKAGES+=("$pkg")
            fi
        done

        if [[ "${#OFFICIAL_PACKAGES[@]}" -eq 0 && "${#AUR_PACKAGES[@]}" -eq 0 ]]; then
            success "All packages already installed."
        fi

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
# Compare repo vs installed (nothing is written here)
# --------------------------------------------------

CH_KIND=()    # add | update
CH_SRC=()     # file in the repo
CH_DEST=()    # where it gets installed
CH_NAME=()    # name shown to the user
CH_BACKUP=()  # path inside the backup dir
UNCHANGED=0

consider() {
    local src="$1" dest="$2" name="$3" backup="$4" kind

    if [[ ! -e "$dest" && ! -L "$dest" ]]; then
        kind="add"
    elif cmp -s "$src" "$dest"; then
        UNCHANGED=$((UNCHANGED + 1))
        return
    else
        kind="update"
    fi

    CH_KIND+=("$kind")
    CH_SRC+=("$src")
    CH_DEST+=("$dest")
    CH_NAME+=("$name")
    CH_BACKUP+=("$backup")
}

while IFS= read -r -d '' file; do
    rel="${file#"$SRC"/}"

    # .zshrc is installed to ~/.zshrc (handled below), not ~/.config/.zshrc
    [[ "$rel" == ".zshrc" ]] && continue

    consider "$file" "$CONFIG_DIR/$rel" "$rel" "config/$rel"
done < <(find "$SRC" \( -type f -o -type l \) -not -path '*/.git/*' -print0 | sort -z)

if [[ -f "$SRC/.zshrc" ]]; then
    consider "$SRC/.zshrc" "$HOME/.zshrc" "~/.zshrc" "home/.zshrc"
fi

ADDED_COUNT=0
UPDATED_COUNT=0
declare -A TOUCHED=()

for i in "${!CH_KIND[@]}"; do
    if [[ "${CH_KIND[$i]}" == "add" ]]; then
        ADDED_COUNT=$((ADDED_COUNT + 1))
    else
        UPDATED_COUNT=$((UPDATED_COUNT + 1))
    fi

    top="${CH_NAME[$i]#\~/}"
    top="${top%%/*}"
    TOUCHED["$top"]=$(( ${TOUCHED["$top"]:-0} + 1 ))
done

TOTAL_CHANGES=$((ADDED_COUNT + UPDATED_COUNT))

info "Comparing $SRC with your installed config..."

if [[ "$TOTAL_CHANGES" -eq 0 ]]; then
    success "Everything is already up to date ($UNCHANGED files identical)."
else
    if [[ "$ADDED_COUNT" -gt 0 ]]; then
        printf '\n\033[1;32mNew files (%d):\033[0m\n' "$ADDED_COUNT"
        for i in "${!CH_KIND[@]}"; do
            [[ "${CH_KIND[$i]}" == "add" ]] && printf '  \033[32m+\033[0m %s\n' "${CH_NAME[$i]}"
        done
    fi

    if [[ "$UPDATED_COUNT" -gt 0 ]]; then
        printf '\n\033[1;33mUpdated files (%d), these will be backed up first:\033[0m\n' "$UPDATED_COUNT"
        for i in "${!CH_KIND[@]}"; do
            [[ "${CH_KIND[$i]}" == "update" ]] && printf '  \033[33m~\033[0m %s\n' "${CH_NAME[$i]}"
        done
    fi

    printf '\n\033[1mFolders affected:\033[0m\n'
    for top in $(printf '%s\n' "${!TOUCHED[@]}" | sort); do
        printf '  %-24s %d file(s)\n' "$top" "${TOUCHED[$top]}"
    done
    printf '\nUnchanged: %d file(s)\n' "$UNCHANGED"

    if [[ "$SHOW_DIFF" -eq 1 && "$UPDATED_COUNT" -gt 0 ]]; then
        printf '\n\033[1mDiffs (installed -> repo):\033[0m\n'
        for i in "${!CH_KIND[@]}"; do
            [[ "${CH_KIND[$i]}" == "update" ]] || continue
            printf '\n\033[1;36m--- %s ---\033[0m\n' "${CH_NAME[$i]}"
            diff -u --label "installed: ${CH_NAME[$i]}" --label "repo: ${CH_NAME[$i]}" \
                "${CH_DEST[$i]}" "${CH_SRC[$i]}" || true
        done
    fi
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '\n'
    info "Dry run: nothing was written. Re-run without --dry-run to apply."
    [[ "$UPDATED_COUNT" -gt 0 && "$SHOW_DIFF" -eq 0 ]] && info "Add --diff to see exactly what changes inside each updated file."
    exit 0
fi

# --------------------------------------------------
# Back up the files that are about to be overwritten
# --------------------------------------------------

if [[ "$UPDATED_COUNT" -gt 0 ]]; then
    info "Backing up $UPDATED_COUNT file(s) that will be overwritten..."

    BACKUP_FAILED=0

    mkdir -p "$BACKUP_DIR"
    {
        printf 'Update backup created %s\n' "$TIMESTAMP"
        printf 'Repo: %s\n\n' "$REPO_DIR"
        printf 'UPDATED (original versions saved in this folder):\n'
    } > "$BACKUP_DIR/CHANGES.txt"

    for i in "${!CH_KIND[@]}"; do
        [[ "${CH_KIND[$i]}" == "update" ]] || continue
        bpath="$BACKUP_DIR/${CH_BACKUP[$i]}"
        mkdir -p "$(dirname "$bpath")"
        if cp -a "${CH_DEST[$i]}" "$bpath"; then
            printf '  %s\n' "${CH_NAME[$i]}" >> "$BACKUP_DIR/CHANGES.txt"
        else
            BACKUP_FAILED=1
            error "Could not back up ${CH_NAME[$i]}"
        fi
    done

    printf '\nNEW (did not exist before):\n' >> "$BACKUP_DIR/CHANGES.txt"
    for i in "${!CH_KIND[@]}"; do
        [[ "${CH_KIND[$i]}" == "add" ]] && printf '  %s\n' "${CH_NAME[$i]}" >> "$BACKUP_DIR/CHANGES.txt"
    done

    if [[ "$BACKUP_FAILED" -eq 1 ]]; then
        error "Backup incomplete, aborting before anything was overwritten."
        exit 1
    fi

    success "Backup saved to: $BACKUP_DIR"
fi

# --------------------------------------------------
# Apply only the changed files
# --------------------------------------------------

if [[ "$TOTAL_CHANGES" -gt 0 ]]; then
    info "Installing $TOTAL_CHANGES changed file(s)..."

    COPY_FAILED=0
    for i in "${!CH_KIND[@]}"; do
        dest="${CH_DEST[$i]}"
        mkdir -p "$(dirname "$dest")"

        if cp -a "${CH_SRC[$i]}" "$dest"; then
            case "$dest" in
                *.sh|*.py) chmod +x "$dest" ;;
            esac
        else
            COPY_FAILED=$((COPY_FAILED + 1))
            error "Failed to install ${CH_NAME[$i]}"
        fi
    done

    if [[ "$COPY_FAILED" -gt 0 ]]; then
        warning "$COPY_FAILED file(s) failed to install; see errors above."
    else
        success "Config files synced ($ADDED_COUNT new, $UPDATED_COUNT updated)."
    fi
fi

# Keep only the newest $KEEP_BACKUPS update backups
if [[ -d "$BACKUP_ROOT" ]]; then
    mapfile -t OLD_BACKUPS < <(ls -1dt "$BACKUP_ROOT"/update-* 2>/dev/null | tail -n +$((KEEP_BACKUPS + 1)))
    for old in "${OLD_BACKUPS[@]}"; do
        [[ -n "$old" ]] && rm -rf -- "$old"
    done
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
        error "Configs on disk may be a mix of old and new; run 'theme apply' again once fixed."
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
warning "Rofi and wlogout re-read their CSS on next launch, no action needed."
warning "Hyprlock re-reads its config on next lock, no action needed."

if [[ "$RESTART_SHELL" -eq 1 ]]; then
    info "Restarting Quickshell (qs)..."
    pkill -x qs 2>/dev/null || true
    sleep 1
    nohup qs >/dev/null 2>&1 &
    disown
    success "Quickshell restarted."
else
    warning "Quickshell (qs) was NOT restarted. Only needed if a .qml file changed;"
    warning "  re-run with --restart-shell if so."
fi

if [[ "${#UNKNOWN_PACKAGES[@]}" -gt 0 ]]; then
    printf '\n'
    warning "Unresolved packages (install manually): ${UNKNOWN_PACKAGES[*]}"
fi

# --------------------------------------------------
# Summary
# --------------------------------------------------

printf '\n'
success "Update complete: $ADDED_COUNT new, $UPDATED_COUNT updated, $UNCHANGED unchanged."

if [[ "$UPDATED_COUNT" -gt 0 ]]; then
    printf '\nYour previous versions of the updated files are in:\n  %s\n' "$BACKUP_DIR"
    printf '\nTo undo this update:\n'
    printf '  cp -a "%s/config/." ~/.config/\n' "$BACKUP_DIR"
    [[ -f "$BACKUP_DIR/home/.zshrc" ]] && printf '  cp -a "%s/home/.zshrc" ~/.zshrc\n' "$BACKUP_DIR"
fi
