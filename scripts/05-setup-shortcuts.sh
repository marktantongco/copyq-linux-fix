#!/usr/bin/env bash
# ==============================================================================
# Step 5: Setup GNOME Custom Keyboard Shortcuts for CopyQ
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { echo -e "  ${BLUE}[INFO]${NC} $*"; }
pass() { echo -e "  ${GREEN}[PASS]${NC} $*"; }

COPYQ_ID="com.github.hluk.copyq"
COPYQ_CMD="flatpak run ${COPYQ_ID}"
CUSTOM_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"

register_shortcut() {
    local idx="$1" name="$2" cmd="$3" binding="$4"
    local path="${CUSTOM_PATH}/custom${idx}/"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"${path}" name "${name}"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"${path}" command "${cmd}"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"${path}" binding "${binding}"
    pass "${binding} -> ${name}"
}

info "Registering GNOME custom shortcuts..."

# Super+V is claimed by GNOME Shell's toggle-message-tray by default, which
# makes the CopyQ grab silently fail. Free it first (Super+M remains as the
# message-tray shortcut).
if gsettings get org.gnome.shell.keybindings toggle-message-tray 2>/dev/null | grep -q "<Super>v"; then
    gsettings set org.gnome.shell.keybindings toggle-message-tray "['<Super>m']"
    info "Freed Super+V from message tray (kept Super+M)"
fi

register_shortcut 0 "CopyQ Toggle" "${COPYQ_CMD} --toggle" "<Super>v"
register_shortcut 1 "CopyQ Menu" "${COPYQ_CMD} menu" "<Super><Shift>v"

gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings \
    "['${CUSTOM_PATH}/custom0/', '${CUSTOM_PATH}/custom1/']"
pass "Keybinding list updated"
info "Shortcuts: Super+V (toggle), Super+Shift+V (menu)"
echo ""
