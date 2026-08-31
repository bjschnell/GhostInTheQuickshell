#!/bin/bash

# Ghost — Post-Installation Validator

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

INSTALLED=0
MISSING=0
OPTIONAL_MISSING=0

log_installed() {
    echo -e "${GREEN}[✓]${NC} $1"
    ((INSTALLED++))
}

log_missing() {
    echo -e "${RED}[✗]${NC} $1 ${YELLOW}(MISSING)${NC}"
    ((MISSING++))
}

log_optional() {
    echo -e "${YELLOW}[○]${NC} $1 ${YELLOW}(optional)${NC}"
    ((OPTIONAL_MISSING++))
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

check_command() {
    if command -v "$1" &> /dev/null; then
        log_installed "$1"
    else
        log_missing "$1"
    fi
}

clear
echo "Ghost — Post-Installation Validator"
echo "Verify all dependencies are installed"
echo ""

if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    DISTRO="$ID"
else
    DISTRO="unknown"
fi

log_info "Detected distribution: $DISTRO"
echo ""

echo "# CORE RUNTIME"
check_command "quickshell"
check_command "hyprland"
check_command "hyprctl"

# Note: qt6-base / qt6-declarative are hard deps of quickshell and expose no
# binary of their own, so a working quickshell above already proves them.

echo ""
echo "# SYSTEM TOOLS"
check_command "pactl"
check_command "bluetoothctl"
check_command "notify-send"
check_command "pkexec"
check_command "python"
check_command "wl-copy"
check_command "slurp"

echo ""
echo "# SCREEN RECORDING"
check_command "wf-recorder"
check_command "cava"
check_command "mpv"

echo ""
echo "# WALLPAPER & THEMING"
check_command "magick"
check_command "awww"
check_command "matugen"

echo ""
echo "# CLIPBOARD"
check_command "wtype"
check_command "cliphist"

echo ""
echo "# POWER & HARDWARE"
check_command "sensors"

echo ""
echo "# HYPRLAND ECOSYSTEM"
check_command "hyprsunset"
check_command "hyprlock"
check_command "hypridle"
check_command "hyprshutdown"

echo ""
echo "# FONTS"
if fc-list : family | grep -q "JetBrainsMono Nerd Font"; then
    log_installed "JetBrainsMono Nerd Font"
else
    log_missing "JetBrainsMono Nerd Font  (family named by Theme.fontMono)"
fi

echo ""
echo "# CONFIGURATION FILES"

# hyprland.lua and hyprland.conf are alternatives, not both required.
# Hyprland loads .lua first when both exist, so check that one the same way
# install.sh picks it.
_HYPR_CONF=""
if [[ -f "$HOME/.config/hypr/hyprland.lua" ]]; then
    _HYPR_CONF="$HOME/.config/hypr/hyprland.lua"
elif [[ -f "$HOME/.config/hypr/hyprland.conf" ]]; then
    _HYPR_CONF="$HOME/.config/hypr/hyprland.conf"
fi

if [[ -n "$_HYPR_CONF" ]]; then
    log_installed "Hyprland config (${_HYPR_CONF##*/})"

    if grep -q "quickshell.*Ghost" "$_HYPR_CONF"; then
        log_installed "Ghost autostart in ${_HYPR_CONF##*/}"
    else
        log_missing "Ghost autostart in ${_HYPR_CONF##*/}"
    fi
else
    log_missing "Hyprland config (no hyprland.lua or hyprland.conf)"
fi

if [[ -d "$HOME/.local/src/Ghost" ]]; then
    log_installed "Ghost repository"
else
    log_missing "Ghost repository"
fi

if [[ -d "$HOME/.config/Ghost" ]]; then
    log_installed "Ghost config directory"
else
    log_missing "Ghost config directory"
fi

echo ""
echo "# BACKUPS"
BACKUP_COUNT=$(ls -d $HOME/.config.backup-* 2>/dev/null | wc -l)

if [[ $BACKUP_COUNT -gt 0 ]]; then
    log_info "Found $BACKUP_COUNT config backup(s)"
    ls -d $HOME/.config.backup-* 2>/dev/null | while read backup; do
        echo -e "  ${BLUE}→${NC} ${backup##*/}"
    done
else
    log_optional "No config backups found"
fi

echo ""
echo "# SUMMARY"
TOTAL=$((INSTALLED + MISSING + OPTIONAL_MISSING))

echo -e "${GREEN}✓ Installed: $INSTALLED${NC}"
echo -e "${RED}✗ Missing: $MISSING${NC}"
echo -e "${YELLOW}○ Optional: $OPTIONAL_MISSING${NC}"
echo ""

if [[ $MISSING -eq 0 ]]; then
    echo -e "${GREEN}All required dependencies are installed!${NC}"
    exit 0
else
    echo -e "${YELLOW}Some required dependencies are missing.${NC}"
    echo ""
    echo "To fix:  re-run dots-extra/install-arch.sh, or:  sudo pacman -S <pkg>"
    echo ""
    exit 1
fi
