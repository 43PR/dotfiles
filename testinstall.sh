#!/usr/bin/env bash
#
# 43PR/dotfiles installer — Arch-compatible Linux + Hyprland (fully unattended)
#
# Usage:
#   ./install.sh                 # everything is auto-detected; asks for sudo ONCE
#   ./install.sh --gpu nvidia    # override GPU detection: nvidia,amd,intel,vm,none
#   ./install.sh --no-aur        # never touch the AUR (AUR-only packages are skipped)
#   ./install.sh --help
#
# What it does (no further prompts after the single sudo password):
#   1. Verifies an Arch-based system, network, and bootstraps an AUR helper
#   2. Detects your GPU(s) and kernel(s) and picks the right driver stack
#   3. Installs packages.txt (official repos first, then AUR); skips what is
#      already installed or unavailable and reports every failure at the end
#   4. Symlinks .config/* into ~/.config (existing files are backed up)
#   5. Writes GPU config (auto-detects hybrid setups) and wires it into Hyprland
#   6. Enables user + system services, sets zsh, Papirus folders, Flathub
#   7. Sets the default wallpaper and generates the initial theme
#   8. Invalidates sudo credentials and exits cleanly (even on Ctrl-C / errors)
#
# Re-running is safe: every step is idempotent.

set -uo pipefail

# --------------------------------------------------
# Paths / config
# --------------------------------------------------

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
REPO_DIR="$(dirname "$SCRIPT_PATH")"
SRC="$REPO_DIR/.config"
PACKAGE_FILE="$REPO_DIR/packages.txt"
CONFIG_DIR="$HOME/.config"
BACKUP_ROOT="$HOME/.config-backups"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/43pr"
THEME_STATE="$STATE_DIR/state.json"
THEME_PY="$CONFIG_DIR/43pr/bin/theme.py"
LOG_FILE="$STATE_DIR/install-$TIMESTAMP.log"

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

# Never let a tool stop and wait for input or a pager.
export GIT_TERMINAL_PROMPT=0 SYSTEMD_PAGER=cat PAGER=cat LC_ALL="${LC_ALL:-C.UTF-8}"

# --------------------------------------------------
# State (everything the final report needs)
# --------------------------------------------------

STARTED=0                 # set once preflight passes (summary is only shown then)
SUMMARY_DONE=0
SUDO_USED=0
KEEPALIVE_PID=""
TMP_DIRS=()
STATUS_OVERRIDE=""        # "interrupted" | "failed"
EXIT_CODE=0
CURRENT_STEP="starting"

DISTRO="unknown"
KERNEL_RUNNING="$(uname -r)"
AUR_HELPER=""
DETECTED_GPUS=""
SELECTED_GPUS=""
GPU_NOTE=""
HYBRID_CONF=""

PKG_REQUESTED=0
PKG_ALREADY=0
PKG_INSTALLED=0
PKG_FAILED=()             # "name — reason"
PKG_SKIPPED_AUR=()

DOT_NEW=0
DOT_OK=0
DOT_RELINKED=0
DOT_BACKED_UP=0
DOT_FAILED=0

WARNINGS=()               # non-package problems
NOTES=()                  # important info shown at the end
SERVICES_ON=()
SERVICES_FAIL=()

# --------------------------------------------------
# Output helpers
# --------------------------------------------------

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_RST=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
    C_RED=$'\033[1;31m'; C_GRN=$'\033[1;32m'; C_YEL=$'\033[1;33m'
    C_BLU=$'\033[1;34m'; C_MAG=$'\033[1;35m'; C_CYN=$'\033[1;36m'
else
    C_RST=""; C_BOLD=""; C_DIM=""; C_RED=""; C_GRN=""; C_YEL=""
    C_BLU=""; C_MAG=""; C_CYN=""
fi

log()     { mkdir -p "$STATE_DIR" 2>/dev/null; printf '%s %s\n' "$(date '+%H:%M:%S')" "$1" >>"$LOG_FILE" 2>/dev/null || true; }
info()    { printf '\n%s[INFO]%s %s\n' "$C_BLU" "$C_RST" "$1"; log "INFO  $1"; }
success() { printf '\n%s[DONE]%s %s\n' "$C_GRN" "$C_RST" "$1"; log "DONE  $1"; }
warning() { printf '\n%s[WARN]%s %s\n' "$C_YEL" "$C_RST" "$1"; log "WARN  $1"; }
error()   { printf '\n%s[ERROR]%s %s\n' "$C_RED" "$C_RST" "$1" >&2; log "ERROR $1"; }
note_warning() { WARNINGS+=("$1"); warning "$1"; }
add_note()     { NOTES+=("$1"); log "NOTE  $1"; }

STEP_NO=0
STEP_TOTAL=9
step() {
    STEP_NO=$((STEP_NO + 1))
    CURRENT_STEP="$1"
    printf '\n%s==> [%d/%d] %s%s\n' "$C_MAG" "$STEP_NO" "$STEP_TOTAL" "$1" "$C_RST"
    log "STEP  [$STEP_NO/$STEP_TOTAL] $1"
}

# --------------------------------------------------
# Arguments
# --------------------------------------------------

NO_AUR=0
GPU_ARG=""

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

  --gpu LIST    Override GPU detection: nvidia, amd, intel, vm, none
                (comma-separated for hybrid setups, e.g. intel,nvidia)
  --no-aur      Never use the AUR; AUR-only packages are skipped
  -y, --yes     Accepted for compatibility (the installer never prompts)
  -h, --help    Show this help

The installer asks for your sudo password once, then runs unattended.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes)  ;;
        --no-aur)  NO_AUR=1 ;;
        --gpu)
            [[ $# -ge 2 ]] || { error "--gpu needs a value (nvidia,amd,intel,vm,none)"; exit 1; }
            GPU_ARG="$2"; shift ;;
        --gpu=*)   GPU_ARG="${1#--gpu=}" ;;
        -h|--help) usage; exit 0 ;;
        *)         error "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
done

# --------------------------------------------------
# Final report (fancy finish screen) — defined early so traps can use it
# --------------------------------------------------

W=70   # total box width

_rep() { local s="" i; for ((i = 0; i < $1; i++)); do s+="$2"; done; printf '%s' "$s"; }
box_top()  { printf '%s╭%s╮%s\n' "$1" "$(_rep $((W - 2)) '─')" "$C_RST"; }
box_mid()  { printf '%s├%s┤%s\n' "$1" "$(_rep $((W - 2)) '─')" "$C_RST"; }
box_bot()  { printf '%s╰%s╯%s\n' "$1" "$(_rep $((W - 2)) '─')" "$C_RST"; }

# box_text "text" [color] [bc]  — one padded line inside the box
box_text() {
    local t="${1:0:W-4}" col="${2:-}" bc="${3:-$C_DIM}"
    printf '%s│%s %s%s%s%*s %s│%s\n' "$bc" "$C_RST" "$col" "$t" "$C_RST" $((W - 4 - ${#t})) '' "$bc" "$C_RST"
}

# box_center "text" [color] [bc]
box_center() {
    local t="${1:0:W-4}" col="${2:-}" bc="${3:-$C_DIM}"
    local left=$(((W - 4 - ${#t}) / 2)) right=$((W - 4 - ${#t} - (W - 4 - ${#t}) / 2))
    printf '%s│%s %*s%s%s%s%*s %s│%s\n' "$bc" "$C_RST" "$left" '' "$col" "$t" "$C_RST" "$right" '' "$bc" "$C_RST"
}

# box_kv "label" "value" [value-color]
box_kv() {
    local k="$1" v="$2" vc="${3:-}" bc="${4:-$C_DIM}"
    local kw=15 max=$((W - 4 - 16))
    v="${v:0:max}"
    printf '%s│%s %s%-*s%s %s%s%s%*s %s│%s\n' "$bc" "$C_RST" "$C_CYN" "$kw" "$k" "$C_RST" "$vc" "$v" "$C_RST" $((max - ${#v})) '' "$bc" "$C_RST"
}

# box_wrapped "text" indent-first indent-rest [color]
box_wrapped() {
    local text="$1" first="$2" rest="$3" col="${4:-}" l n=0 width=$((W - 4 - ${#first}))
    while IFS= read -r l; do
        if [[ $n -eq 0 ]]; then box_text "$first$l" "$col"; else box_text "$rest$l" "$col"; fi
        n=$((n + 1))
    done < <(fold -s -w "$width" <<<"$text")
}

box_section() { box_mid "$C_DIM"; box_text "$1" "$C_BOLD$C_MAG"; }

fmt_elapsed() { local s=$1; printf '%dm %02ds' $((s / 60)) $((s % 60)); }

print_summary() {
    [[ "$SUMMARY_DONE" -eq 0 && "$STARTED" -eq 1 ]] || return 0
    SUMMARY_DONE=1

    local issues=$(( ${#PKG_FAILED[@]} + ${#WARNINGS[@]} + ${#SERVICES_FAIL[@]} + DOT_FAILED ))
    local status_txt status_col bc
    if [[ "$STATUS_OVERRIDE" == "interrupted" ]]; then
        status_txt="INTERRUPTED  ·  stopped during: $CURRENT_STEP"; status_col="$C_YEL"
    elif [[ "$STATUS_OVERRIDE" == "failed" ]]; then
        status_txt="STOPPED AFTER AN ERROR  ·  $CURRENT_STEP"; status_col="$C_RED"
    elif [[ "$issues" -eq 0 ]]; then
        status_txt="ALL DONE  ·  everything installed without issues"; status_col="$C_GRN"
    else
        status_txt="DONE WITH $issues ISSUE(S)  ·  details below"; status_col="$C_YEL"
    fi
    bc="$status_col"

    printf '\n'
    box_top "$bc"
    box_text "" "" "$bc"
    box_center "◆  4 3 P R   H Y P R L A N D  ◆" "$C_BOLD$C_CYN" "$bc"
    box_center "dotfiles installer" "$C_DIM" "$bc"
    box_text "" "" "$bc"
    box_center "$status_txt" "$C_BOLD$status_col" "$bc"
    box_text "" "" "$bc"

    box_mid "$bc"
    box_text "SYSTEM" "$C_BOLD$C_MAG" "$bc"
    box_kv "Distribution" "$DISTRO" "" "$bc"
    box_kv "Kernel" "$KERNEL_RUNNING" "" "$bc"
    box_kv "AUR helper" "${AUR_HELPER:-none}" "" "$bc"
    box_kv "GPU detected" "${DETECTED_GPUS:-none}" "" "$bc"
    box_kv "GPU stack" "${SELECTED_GPUS:-none}" "" "$bc"
    box_kv "Elapsed" "$(fmt_elapsed $((SECONDS - START_SECONDS)))" "" "$bc"

    box_mid "$bc"
    box_text "PACKAGES" "$C_BOLD$C_MAG" "$bc"
    box_kv "Requested" "$PKG_REQUESTED" "" "$bc"
    box_kv "Newly installed" "$PKG_INSTALLED" "$C_GRN" "$bc"
    box_kv "Already present" "$PKG_ALREADY" "$C_DIM" "$bc"
    if [[ "${#PKG_FAILED[@]}" -gt 0 ]]; then
        box_kv "Failed/skipped" "${#PKG_FAILED[@]}" "$C_RED" "$bc"
    else
        box_kv "Failed/skipped" "0" "$C_GRN" "$bc"
    fi

    box_mid "$bc"
    box_text "CONFIGURATION" "$C_BOLD$C_MAG" "$bc"
    box_kv "Config dir" "$CONFIG_DIR" "" "$bc"
    box_kv "Linked (new)" "$DOT_NEW" "" "$bc"
    box_kv "Up to date" "$DOT_OK" "$C_DIM" "$bc"
    box_kv "Re-linked" "$DOT_RELINKED" "" "$bc"
    box_kv "Backed up" "$DOT_BACKED_UP" "" "$bc"
    if [[ "$DOT_BACKED_UP" -gt 0 ]]; then box_kv "Backup dir" "$BACKUP_DIR" "" "$bc"; fi
    if [[ "${#SERVICES_ON[@]}" -gt 0 ]]; then
        box_kv "Services on" "${#SERVICES_ON[@]} enabled" "$C_GRN" "$bc"
    fi

    if [[ "${#PKG_FAILED[@]}" -gt 0 || "${#WARNINGS[@]}" -gt 0 || "${#SERVICES_FAIL[@]}" -gt 0 || "$DOT_FAILED" -gt 0 ]]; then
        box_mid "$bc"
        box_text "ISSUES" "$C_BOLD$C_RED" "$bc"
        local f
        for f in "${PKG_FAILED[@]}"; do box_wrapped "$f" "✘ " "  " "$C_RED"; done
        for f in "${SERVICES_FAIL[@]}"; do box_wrapped "service: $f" "✘ " "  " "$C_RED"; done
        [[ "$DOT_FAILED" -gt 0 ]] && box_text "✘ $DOT_FAILED dotfile(s) failed to link" "$C_RED"
        for f in "${WARNINGS[@]}"; do box_wrapped "$f" "▲ " "  " "$C_YEL"; done
        box_text "→ Fix the cause and re-run ./install.sh (safe to repeat)." "$C_DIM"
    fi

    if [[ "${#NOTES[@]}" -gt 0 ]]; then
        box_mid "$bc"
        box_text "IMPORTANT" "$C_BOLD$C_YEL" "$bc"
        local i=1 n
        for n in "${NOTES[@]}"; do
            box_wrapped "$n" "$i. " "   " ""
            i=$((i + 1))
        done
    fi

    box_mid "$bc"
    box_text "NEXT STEPS" "$C_BOLD$C_GRN" "$bc"
    box_text "1. Reboot (or log out and back in)" "" "$bc"
    box_text "2. At the TTY login, start the desktop with:  Hyprland" "" "$bc"
    box_text "3. Re-theme anytime:  python3 $THEME_PY apply" "$C_DIM" "$bc"
    box_mid "$bc"
    box_kv "Log file" "$LOG_FILE" "$C_DIM" "$bc"
    box_text "sudo credentials were invalidated — nothing stays privileged." "$C_DIM" "$bc"
    box_bot "$bc"
    printf '\n'
    log "SUMMARY status=${STATUS_OVERRIDE:-ok} issues=$issues installed=$PKG_INSTALLED failed=${#PKG_FAILED[@]}"
}

# --------------------------------------------------
# Cleanup / signals — always leave cleanly
# --------------------------------------------------

START_SECONDS=$SECONDS

cleanup() {
    local rc=$?
    trap - EXIT INT TERM HUP
    set +u

    # Stop the sudo keep-alive loop (and its sleeping child).
    if [[ -n "$KEEPALIVE_PID" ]]; then
        pkill -P "$KEEPALIVE_PID" 2>/dev/null
        kill "$KEEPALIVE_PID" 2>/dev/null
        wait "$KEEPALIVE_PID" 2>/dev/null
    fi

    local d
    for d in "${TMP_DIRS[@]}"; do [[ -n "$d" && -d "$d" ]] && rm -rf "$d"; done

    # Unexpected non-zero exit after start (not a clean finish and not already flagged).
    if [[ "$STARTED" -eq 1 && "$rc" -ne 0 && -z "$STATUS_OVERRIDE" ]]; then
        STATUS_OVERRIDE="failed"
    fi

    print_summary

    # Invalidate sudo credentials last, after every sudo call is done.
    if [[ "$SUDO_USED" -eq 1 ]]; then
        sudo -K 2>/dev/null
    fi
    printf '%s' "$C_RST"
    exit "$rc"
}

on_signal() {
    STATUS_OVERRIDE="interrupted"
    printf '\n%s[WARN]%s Received signal — stopping safely...\n' "$C_YEL" "$C_RST" >&2
    exit "$1"
}

trap cleanup EXIT
trap 'on_signal 130' INT
trap 'on_signal 143' TERM
trap 'on_signal 129' HUP

# --------------------------------------------------
# Preflight checks
# --------------------------------------------------

step "Preflight checks"

if [[ "${EUID}" -eq 0 ]]; then
    error "Do not run this script as root (it will use sudo when needed)."
    exit 1
fi

if [[ ! -f /etc/os-release ]]; then
    error "Cannot determine the operating system."
    exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release
DISTRO="${PRETTY_NAME:-${NAME:-unknown}}"

if [[ "${ID:-}" != "arch" && "${ID_LIKE:-}" != *arch* ]]; then
    error "This installer is intended for Arch-compatible Linux distributions."
    error "Detected: $DISTRO"
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

mkdir -p "$STATE_DIR"
STARTED=1
info "Detected distribution: $DISTRO"

# --- the ONLY prompt: sudo password, asked once -------------------------------
SUDO_USED=1
if ! sudo -v -p '[sudo] password for %u (asked once, kept alive for the whole install): '; then
    SUDO_USED=0
    error "Could not obtain sudo privileges."
    exit 1
fi

# Keep the sudo timestamp fresh for the entire run (including long AUR builds).
(
    while kill -0 "$$" 2>/dev/null; do
        sudo -n -v 2>/dev/null
        sleep 30 &
        wait $!
    done
) >/dev/null 2>&1 &
KEEPALIVE_PID=$!

if ! sudo -n true 2>/dev/null; then
    note_warning "sudo does not cache credentials here (timestamp_timeout=0?). Later sudo steps may fail."
fi

# Network check (non-fatal: installed packages still allow config-only runs).
ONLINE=1
if ! getent hosts archlinux.org >/dev/null 2>&1 && ! getent hosts aur.archlinux.org >/dev/null 2>&1; then
    ONLINE=0
    note_warning "No network detected — package installation will likely fail; configuration steps will still run."
fi

PACMAN_FLAGS=(--needed --noconfirm)

# Wait for (or clear a stale) pacman lock so we never block on it.
free_pacman_lock() {
    local waited=0
    while [[ -e /var/lib/pacman/db.lck ]]; do
        if ! pgrep -x 'pacman|yay|paru|pamac|packagekitd' >/dev/null 2>&1; then
            sudo rm -f /var/lib/pacman/db.lck
            log "removed stale pacman lock"
            break
        fi
        [[ $waited -ge 180 ]] && break
        sleep 3; waited=$((waited + 3))
    done
}

# --------------------------------------------------
# AUR helper
# --------------------------------------------------

step "AUR helper"

AUR_FLAGS=(--needed --noconfirm)
if [[ "$NO_AUR" -eq 1 ]]; then
    info "--no-aur given; AUR packages will be skipped."
elif command -v paru >/dev/null 2>&1; then
    AUR_HELPER="paru"
elif command -v yay >/dev/null 2>&1; then
    AUR_HELPER="yay"
elif [[ "$ONLINE" -eq 1 ]]; then
    info "No AUR helper found. Bootstrapping yay-bin..."
    free_pacman_lock
    if sudo pacman -S "${PACMAN_FLAGS[@]}" git base-devel; then
        YAY_BUILD_DIR="$(mktemp -d)"
        TMP_DIRS+=("$YAY_BUILD_DIR")
        if git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$YAY_BUILD_DIR/yay-bin" \
            && (cd "$YAY_BUILD_DIR/yay-bin" && makepkg -si --noconfirm); then
            AUR_HELPER="yay"
            success "yay installed."
        else
            note_warning "Could not build yay automatically; AUR packages will be skipped."
        fi
    else
        note_warning "Could not install git/base-devel; AUR packages will be skipped."
    fi
else
    note_warning "Offline: cannot bootstrap an AUR helper."
fi

case "$AUR_HELPER" in
    paru) AUR_FLAGS+=(--skipreview) ;;
    yay)  AUR_FLAGS+=(--answerclean None --answerdiff None --answeredit None --answerupgrade None) ;;
esac

[[ -n "$AUR_HELPER" ]] && info "Using AUR helper: $AUR_HELPER"

# --------------------------------------------------
# Package helpers
# --------------------------------------------------

# Returns 0 if the name (package, provider or group member) is already satisfied.
is_satisfied() { [[ -z "$(pacman -T "$1" 2>/dev/null)" ]]; }
is_installed() { pacman -Qq "$1" >/dev/null 2>&1; }

# Install a list with pacman. On batch failure, retry one-by-one to isolate culprits.
pac_install() {
    [[ $# -gt 0 ]] || return 0
    free_pacman_lock
    if sudo pacman -S "${PACMAN_FLAGS[@]}" "$@"; then
        return 0
    fi
    warning "Batch install failed; retrying packages individually..."
    local p
    for p in "$@"; do
        free_pacman_lock
        sudo pacman -S "${PACMAN_FLAGS[@]}" "$p" || log "pacman failed: $p"
    done
}

aur_install() {
    [[ $# -gt 0 && -n "$AUR_HELPER" ]] || return 0
    if "$AUR_HELPER" -S "${AUR_FLAGS[@]}" "$@"; then
        return 0
    fi
    warning "Batch AUR install failed; retrying packages individually..."
    local p
    for p in "$@"; do
        "$AUR_HELPER" -S "${AUR_FLAGS[@]}" "$p" || log "AUR failed: $p"
    done
}

# Read packages.txt: strips full-line AND inline comments, blanks, duplicates.
read_packages() {
    sed -E 's/[[:space:]]*#.*$//; s/^[[:space:]]+//; s/[[:space:]]+$//' "$PACKAGE_FILE" \
        | grep -v '^$' | awk '!seen[$0]++'
}

# --------------------------------------------------
# GPU + kernel detection
# --------------------------------------------------

declare -A CARD_VENDOR=()     # cardN -> nvidia|amd|intel|vm

detect_gpus() {
    local d name v vendor
    for d in /sys/class/drm/card[0-9]*; do
        [[ -e "$d" ]] || continue
        name="${d##*/}"
        [[ "$name" == *-* ]] && continue            # skip connectors (card0-DP-1)
        [[ -r "$d/device/vendor" ]] || continue
        v="$(<"$d/device/vendor")"
        case "${v,,}" in
            0x10de)                            vendor=nvidia ;;
            0x1002)                            vendor=amd ;;
            0x8086)                            vendor=intel ;;
            0x1af4|0x15ad|0x1234|0x80ee|0x1b36) vendor=vm ;;
            *) continue ;;
        esac
        CARD_VENDOR["$name"]="$vendor"
    done

    # Fallback: lspci, if sysfs gave nothing.
    if [[ "${#CARD_VENDOR[@]}" -eq 0 ]] && command -v lspci >/dev/null 2>&1; then
        local lines
        lines="$(lspci -nn 2>/dev/null | grep -Ei 'vga compatible|3d controller|display controller')"
        grep -qi 'nvidia' <<<"$lines"                                  && CARD_VENDOR[lspci-nvidia]=nvidia
        grep -Eqi 'advanced micro devices|\bamd\b|\bati\b' <<<"$lines" && CARD_VENDOR[lspci-amd]=amd
        grep -qi 'intel' <<<"$lines"                                   && CARD_VENDOR[lspci-intel]=intel
        grep -Eqi 'virtio|vmware|qxl|virtualbox|red hat' <<<"$lines"   && CARD_VENDOR[lspci-vm]=vm
    fi

    # Virtual machine with no recognisable GPU.
    if [[ "${#CARD_VENDOR[@]}" -eq 0 ]] && command -v systemd-detect-virt >/dev/null 2>&1 \
        && systemd-detect-virt -q 2>/dev/null; then
        CARD_VENDOR[virt]=vm
    fi

    if [[ "${#CARD_VENDOR[@]}" -gt 0 ]]; then
        printf '%s\n' "${CARD_VENDOR[@]}" | awk 'NF && !s[$0]++' | paste -sd, -
    fi
}

normalize_gpus() {
    # Validate and de-duplicate a comma-separated list. Prints cleaned list or returns 1.
    local item cleaned=() items=()
    IFS=',' read -ra items <<<"${1// /}"
    for item in "${items[@]}"; do
        case "${item,,}" in
            nvidia|amd|intel|vm) cleaned+=("${item,,}") ;;
            none|"")             ;;
            *) return 1 ;;
        esac
    done
    [[ "${#cleaned[@]}" -gt 0 ]] && printf '%s\n' "${cleaned[@]}" | awk 'NF && !s[$0]++' | paste -sd, -
    return 0
}

step "GPU and kernel detection"

DETECTED_GPUS="$(detect_gpus)"
if [[ -n "$DETECTED_GPUS" ]]; then
    info "Detected GPU vendor(s): ${DETECTED_GPUS//,/, }"
else
    info "No GPU detected."
fi

if [[ -n "$GPU_ARG" ]]; then
    if ! SELECTED_GPUS="$(normalize_gpus "$GPU_ARG")"; then
        error "Invalid --gpu value '$GPU_ARG'. Use: nvidia, amd, intel, vm, none (comma-separated)."
        exit 1
    fi
    info "GPU selection from --gpu: ${SELECTED_GPUS:-none}"
else
    SELECTED_GPUS="$DETECTED_GPUS"
    info "Using detected GPUs: ${SELECTED_GPUS:-none}"
fi

has_gpu() { [[ ",$SELECTED_GPUS," == *",$1,"* ]]; }

# Installed kernel package bases (linux, linux-lts, linux-zen, linux-cachyos, ...).
detect_kernels() {
    local f k
    for f in /usr/lib/modules/*/pkgbase; do
        [[ -r "$f" ]] && { k="$(<"$f")"; [[ -n "$k" ]] && printf '%s\n' "$k"; }
    done | awk '!s[$0]++'
}

GPU_PACKAGES=()
build_gpu_packages() {
    has_gpu amd   && GPU_PACKAGES+=(mesa vulkan-radeon)
    has_gpu intel && GPU_PACKAGES+=(mesa vulkan-intel intel-media-driver intel-gpu-tools)
    has_gpu vm    && GPU_PACKAGES+=(mesa)

    if has_gpu nvidia; then
        # nvidia-utils provides nvidia-smi, which the bar's GPU probe uses.
        GPU_PACKAGES+=(nvidia-utils nvidia-settings libva-nvidia-driver)

        local kernels=() k
        mapfile -t kernels < <(detect_kernels)
        if [[ "${#kernels[@]}" -eq 0 ]]; then
            mapfile -t kernels < <(pacman -Qq 2>/dev/null | grep -E '^linux(-lts|-zen|-hardened)?$')
        fi

        if [[ "${#kernels[@]}" -eq 1 && "${kernels[0]}" == "linux" ]]; then
            GPU_PACKAGES+=(nvidia-open)
        else
            GPU_PACKAGES+=(nvidia-open-dkms dkms)
            for k in "${kernels[@]}"; do GPU_PACKAGES+=("${k}-headers"); done
            [[ "${#kernels[@]}" -eq 0 ]] && note_warning "No kernel detected; installed nvidia-open-dkms. Install your kernel's headers package too."
        fi

        add_note "NVIDIA: nvidia-open supports Turing (RTX 20xx / GTX 16xx) and newer. Older cards need a legacy AUR driver (e.g. nvidia-580xx-dkms); re-run with --gpu none and install it manually."
        add_note "NVIDIA: reboot so the kernel module loads. For flicker-free boot, consider early KMS: add nvidia nvidia_modeset nvidia_uvm nvidia_drm to MODULES in /etc/mkinitcpio.conf, then run mkinitcpio -P."
    fi
}

build_gpu_packages

# --------------------------------------------------
# Packages
# --------------------------------------------------

step "Packages"

REQUESTED=()
mapfile -t REQUESTED < <({ read_packages; printf '%s\n' "${GPU_PACKAGES[@]:-}"; } | awk 'NF && !s[$0]++')
PKG_REQUESTED="${#REQUESTED[@]}"

TODO=()
for pkg in "${REQUESTED[@]}"; do
    if is_satisfied "$pkg"; then
        PKG_ALREADY=$((PKG_ALREADY + 1))
    else
        TODO+=("$pkg")
    fi
done

if [[ "$PKG_REQUESTED" -eq 0 ]]; then
    note_warning "packages.txt contains no packages."
elif [[ "${#TODO[@]}" -eq 0 ]]; then
    success "All $PKG_REQUESTED packages are already installed."
elif [[ "$ONLINE" -eq 0 ]]; then
    for pkg in "${TODO[@]}"; do PKG_FAILED+=("$pkg — no network"); done
else
    info "${#TODO[@]} package(s) to install, $PKG_ALREADY already present."
    info "Syncing databases and upgrading the system (avoids partial upgrades)..."
    free_pacman_lock
    sudo pacman -Syu --noconfirm \
        || note_warning "System upgrade failed or was incomplete; package installs may fail."

    OFFICIAL_PACKAGES=()
    AUR_PACKAGES=()
    UNKNOWN_PACKAGES=()

    declare -A IN_REPOS=()
    while IFS= read -r name; do IN_REPOS["$name"]=1; done < <(pacman -Slq 2>/dev/null)

    info "Resolving ${#TODO[@]} package(s) against official repos and the AUR..."
    for pkg in "${TODO[@]}"; do
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
        info "Installing ${#AUR_PACKAGES[@]} AUR package(s) with $AUR_HELPER: ${AUR_PACKAGES[*]}"
        is_installed base-devel || is_satisfied base-devel || pac_install base-devel
        aur_install "${AUR_PACKAGES[@]}"
    fi

    # Verify every requested package afterwards: that is the source of truth.
    for pkg in "${TODO[@]}"; do
        if is_satisfied "$pkg"; then
            PKG_INSTALLED=$((PKG_INSTALLED + 1))
        elif printf '%s\n' "${UNKNOWN_PACKAGES[@]:-}" | grep -qxF "$pkg"; then
            if [[ -z "$AUR_HELPER" ]]; then
                PKG_FAILED+=("$pkg — not in official repos (no AUR helper)")
            else
                PKG_FAILED+=("$pkg — not found in any repo or the AUR")
            fi
        else
            PKG_FAILED+=("$pkg — install failed (see output above)")
        fi
    done

    if [[ "${#PKG_FAILED[@]}" -gt 0 ]]; then
        warning "${#PKG_FAILED[@]} package(s) could not be installed; continuing."
    else
        success "Package installation finished."
    fi
fi

for f in "${PKG_FAILED[@]}"; do log "PKGFAIL $f"; done

# --------------------------------------------------
# GPU configuration
# --------------------------------------------------

step "GPU configuration"

GPU_CONF="$CONFIG_DIR/hypr/gpu.conf"
mkdir -p "$CONFIG_DIR/hypr"

# Hybrid: integrated GPU first, then NVIDIA, as DRM device nodes.
build_hybrid_devices() {
    local c igpu=() dgpu=()
    while IFS= read -r c; do
        [[ "$c" == card* && -e "/dev/dri/$c" ]] || continue
        case "${CARD_VENDOR[$c]}" in
            intel|amd) igpu+=("/dev/dri/$c") ;;
            nvidia)    dgpu+=("/dev/dri/$c") ;;
        esac
    done < <(printf '%s\n' "${!CARD_VENDOR[@]}" | sort -V)
    if [[ "${#igpu[@]}" -gt 0 && "${#dgpu[@]}" -gt 0 ]]; then
        local all=("${igpu[@]}" "${dgpu[@]}")
        local IFS=':'
        printf '%s' "${all[*]}"
    fi
}

write_gpu_conf() {
    local marker="# Generated by install.sh"

    # Never clobber a hand-written file or a hand-tuned hybrid line.
    if [[ -s "$GPU_CONF" ]] && ! grep -qF "$marker" "$GPU_CONF"; then
        info "Keeping your existing $GPU_CONF."
        return
    fi
    if grep -qE '^[[:space:]]*env[[:space:]]*=[[:space:]]*AQ_DRM_DEVICES' "$GPU_CONF" 2>/dev/null \
        && ! grep -qF '# auto-detected' "$GPU_CONF"; then
        info "Keeping your customised AQ_DRM_DEVICES in $GPU_CONF."
        return
    fi

    if has_gpu nvidia && ! has_gpu amd && ! has_gpu intel; then
        cat > "$GPU_CONF" <<'CONF'
# Generated by install.sh — NVIDIA-only system.
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = NVD_BACKEND,direct
CONF
        GPU_NOTE="NVIDIA environment"
    elif has_gpu nvidia; then
        HYBRID_CONF="$(build_hybrid_devices)"
        if [[ -n "$HYBRID_CONF" ]]; then
            cat > "$GPU_CONF" <<CONF
# Generated by install.sh — hybrid system (integrated GPU + NVIDIA).
# auto-detected: the integrated GPU is listed first so Hyprland renders on it.
# Card numbers can change between boots; verify with: ls -l /dev/dri/by-path/
env = AQ_DRM_DEVICES,$HYBRID_CONF
CONF
            GPU_NOTE="hybrid, AQ_DRM_DEVICES=$HYBRID_CONF"
            add_note "Hybrid GPU: Hyprland renders on $HYBRID_CONF (iGPU first). If the screen is blank after reboot, check 'ls -l /dev/dri/by-path/' and edit ~/.config/hypr/gpu.conf."
        else
            cat > "$GPU_CONF" <<'CONF'
# Generated by install.sh — hybrid system (NVIDIA + integrated GPU).
# Hyprland renders on the first GPU in AQ_DRM_DEVICES. Find your cards with:
#   ls -l /dev/dri/by-path/
# and uncomment, listing the integrated GPU first, e.g.:
# env = AQ_DRM_DEVICES,/dev/dri/card1:/dev/dri/card0
CONF
            GPU_NOTE="hybrid template (cards not resolvable yet)"
            add_note "Hybrid GPU: after reboot, set AQ_DRM_DEVICES in ~/.config/hypr/gpu.conf (integrated GPU first, e.g. /dev/dri/card1:/dev/dri/card0)."
        fi
    else
        : > "$GPU_CONF"
        GPU_NOTE="none needed"
    fi
}

write_gpu_conf
info "GPU config: ${GPU_NOTE:-unchanged}"

# Make sure Hyprland actually loads gpu.conf.
if [[ -s "$GPU_CONF" ]]; then
    HYPR_CONF="$CONFIG_DIR/hypr/hyprland.conf"
    if [[ -f "$HYPR_CONF" ]]; then
        if grep -q 'gpu\.conf' "$HYPR_CONF"; then
            info "hyprland.conf already sources gpu.conf."
        else
            HYPR_REAL="$(readlink -f "$HYPR_CONF")"
            if [[ -w "$HYPR_REAL" ]]; then
                printf '\n# GPU environment (added by install.sh)\nsource = ~/.config/hypr/gpu.conf\n' >> "$HYPR_REAL"
                info "Added 'source = ~/.config/hypr/gpu.conf' to hyprland.conf."
                add_note "Appended a 'source = ~/.config/hypr/gpu.conf' line to hyprland.conf (it is a symlink into your repo, so 'git diff' will show it)."
            else
                note_warning "Add 'source = ~/.config/hypr/gpu.conf' to hyprland.conf manually (file not writable)."
            fi
        fi
    else
        note_warning "hyprland.conf not found; add 'source = ~/.config/hypr/gpu.conf' to your Hyprland config."
    fi
fi

printf '%s\n' "${SELECTED_GPUS:-none}" > "$STATE_DIR/gpu"

# --------------------------------------------------
# Default shell
# --------------------------------------------------

step "Default shell"

ZSH_PATH="$(command -v zsh || true)"
if [[ -n "$ZSH_PATH" ]]; then
    if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$ZSH_PATH" ]]; then
        grep -qxF "$ZSH_PATH" /etc/shells || echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
        if sudo chsh -s "$ZSH_PATH" "$USER" </dev/null; then
            success "Default shell set to Zsh (takes effect at next login)."
        else
            note_warning "Failed to change the default shell to Zsh."
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

backup_path() {
    # backup_path <existing path> <relative name under backup root>
    local from="$1" rel="$2"
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    mv "$from" "$BACKUP_DIR/$rel"
    DOT_BACKED_UP=$((DOT_BACKED_UP + 1))
}

while IFS= read -r -d '' src; do
    rel="${src#"$SRC"/}"

    # .zshrc is linked to ~/.zshrc below, not ~/.config/.zshrc
    [[ "$rel" == ".zshrc" ]] && continue
    is_generated "$rel" && continue

    dest="$CONFIG_DIR/$rel"
    mkdir -p "$(dirname "$dest")"

    if [[ -L "$dest" ]]; then
        if [[ "$(readlink "$dest")" == "$src" ]]; then
            DOT_OK=$((DOT_OK + 1))
            continue
        fi
        ln -sfn "$src" "$dest"
        DOT_RELINKED=$((DOT_RELINKED + 1))
    elif [[ -e "$dest" ]]; then
        backup_path "$dest" "config/$rel"
        ln -s "$src" "$dest"
        DOT_NEW=$((DOT_NEW + 1))
    else
        ln -s "$src" "$dest"
        DOT_NEW=$((DOT_NEW + 1))
    fi

    if [[ ! -L "$dest" || "$(readlink -f "$dest")" != "$(readlink -f "$src")" ]]; then
        DOT_FAILED=$((DOT_FAILED + 1))
        error "Failed to link $rel"
    fi
done < <(find "$SRC" \( -type f -o -type l \) -not -path '*/.git/*' -print0)

if [[ -f "$SRC/.zshrc" ]]; then
    if [[ -e "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
        backup_path "$HOME/.zshrc" "home/.zshrc"
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

if [[ "$DOT_FAILED" -gt 0 ]]; then
    warning "$DOT_FAILED dotfile(s) failed to link. See errors above."
else
    success "Dotfiles ready: $DOT_NEW new, $DOT_RELINKED re-linked, $DOT_OK already up to date."
fi
[[ "$DOT_BACKED_UP" -gt 0 ]] && info "Replaced $DOT_BACKED_UP existing file(s); originals saved to: $BACKUP_DIR"

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
            if sudo systemctl enable --now "$unit"; then
                SERVICES_ON+=("$unit"); info "Enabled $unit"
            else
                SERVICES_FAIL+=("$unit (system)")
            fi
        else
            if sudo systemctl enable "$unit"; then
                SERVICES_ON+=("$unit"); info "Enabled $unit (will start on next boot)"
            else
                SERVICES_FAIL+=("$unit (system)")
            fi
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
            if systemctl --user enable --now "$unit"; then
                SERVICES_ON+=("$unit"); info "Enabled user $unit"
            else
                SERVICES_FAIL+=("$unit (user)")
            fi
        else
            if systemctl --user enable "$unit" 2>/dev/null; then
                SERVICES_ON+=("$unit"); info "Enabled user $unit (starts at next login)"
            else
                SERVICES_FAIL+=("$unit (user — no session bus)")
            fi
        fi
    done

    # --- flathub ---
    if is_installed flatpak && [[ "$ONLINE" -eq 1 ]]; then
        if sudo flatpak remote-add --if-not-exists --noninteractive flathub https://dl.flathub.org/repo/flathub.flatpakrepo; then
            info "Flathub remote configured."
        else
            note_warning "Could not add the Flathub remote."
        fi
    fi

    success "Services configured (${#SERVICES_ON[@]} enabled)."
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
        note_warning "papirus-folders is installed but setting the folder color failed."
    fi
else
    info "papirus-folders not available; skipping folder color."
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
        timeout 180 python3 "$THEME_PY" wallpaper "$DEFAULT_WALLPAPER_DEST" </dev/null \
            || note_warning "Could not apply the default wallpaper."
    fi

    info "Generating initial theme..."
    timeout 180 python3 "$THEME_PY" apply </dev/null \
        || note_warning "Initial theme generation failed (run 'python3 $THEME_PY apply' later)."
else
    note_warning "python3 or theme.py missing; configs use committed fallback colors until you run theme apply."
fi

# --------------------------------------------------
# Wrap up
# --------------------------------------------------

step "Finishing up"

add_note "Reboot (or at least log out and back in) so services, the shell change and GPU drivers take effect."
[[ -n "$(getent passwd "$USER" | cut -d: -f7 | grep -F zsh)" || -n "$ZSH_PATH" ]] \
    && add_note "Default shell is Zsh from your next login."
[[ "${#PKG_FAILED[@]}" -gt 0 ]] \
    && add_note "${#PKG_FAILED[@]} package(s) were skipped or failed — see ISSUES above. Re-running ./install.sh retries only what is missing."
[[ -z "$AUR_HELPER" ]] \
    && add_note "No AUR helper is available; AUR-only packages were not installed. Install paru or yay and re-run."

success "All configuration tasks finished."
# The EXIT trap prints the summary, stops the sudo keep-alive and runs 'sudo -K'.
exit 0
