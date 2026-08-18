#!/usr/bin/env bash
# ==============================================================================
# Step 5: Setup Keyboard Shortcuts for CopyQ (v2.0)
# ==============================================================================
# GNOME 48+ supports the XDG GlobalShortcuts portal, which allows Flatpak
# apps to register global keyboard shortcuts natively on Wayland.
# CopyQ v15+ supports this via COPYQ_USE_PORTAL=1.
#
# Fallback: On GNOME <48, use gsettings custom keybindings.
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { echo -e "  ${BLUE}[INFO]${NC} $*"; }
pass() { echo -e "  ${GREEN}[PASS]${NC} $*"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $*"; }

COPYQ_ID="com.github.hluk.copyq"

# Detect GNOME version for shortcut strategy
gnome_ver="0"
if command -v gnome-shell &>/dev/null; then
    gnome_ver=$(gnome-shell --version 2>/dev/null | grep -oP '\d+' | head -1)
fi

if [[ "${gnome_ver}" -ge 48 ]]; then
    info "GNOME ${gnome_ver}: Using XDG GlobalShortcuts portal (native Wayland)"
    info "  CopyQ v15+ with COPYQ_USE_PORTAL=1 handles shortcut registration automatically"
    info "  On first launch, GNOME will prompt you to confirm the shortcut."
    pass "GlobalShortcuts portal strategy selected"
    echo -e "  ${YELLOW}Note: Configure shortcuts in CopyQ Preferences > Shortcuts${NC}"
    echo -e "  ${YELLOW}The portal will ask for confirmation on first use.${NC}"
else
    info "GNOME ${gnome_ver}: Using gsettings custom keybindings (legacy fallback)"
    COPYQ_CMD="flatpak run ${COPYQ_ID}"
    CUSTOM_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"

    register_shortcut() {
        local idx="$1" name="$2" cmd="$3" binding="$4"
        local path="${CUSTOM_PATH}/custom${idx}"
        gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"${path}" name "${name}"
        gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"${path}" command "${cmd}"
        gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"${path}" binding "${binding}"
        pass "${binding} -> ${name}"
    }

    register_shortcut 0 "CopyQ Toggle" "${COPYQ_CMD} --toggle" "<Ctrl><Alt>v"
    register_shortcut 1 "CopyQ Menu" "${COPYQ_CMD} menu" "<Ctrl><Alt><Shift>v"

    gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings \
        "['${CUSTOM_PATH}/custom0', '${CUSTOM_PATH}/custom1']"
    pass "Keybinding list updated"
    warn "  gsettings shortcuts require XWayland for 'flatpak run' commands"
    warn "  Upgrade to GNOME 48+ for native portal shortcuts"
fi

echo ""