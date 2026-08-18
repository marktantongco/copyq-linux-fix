#!/usr/bin/env bash
# ==============================================================================
# Uninstall Script (v2.0)
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { echo -e "  ${BLUE}[INFO]${NC} $*"; }
pass() { echo -e "  ${GREEN}[PASS]${NC} $*"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $*"; }

COPYQ_ID="com.github.hluk.copyq"
EXTENSION_UUID="copyq-clipboard-monitor@hluk.github.com"

echo -e "${YELLOW}${BOLD}Uninstalling CopyQ Native Wayland configuration...${NC}\n"

# Disable and remove GNOME Shell extension
if command -v gnome-extensions &>/dev/null; then
    if gnome-extensions list 2>/dev/null | grep -q "${EXTENSION_UUID}"; then
        info "Disabling GNOME Shell extension..."
        gnome-extensions disable "${EXTENSION_UUID}" 2>/dev/null || true
        pass "Extension disabled"
    fi
fi
EXT_DIR="${HOME}/.local/share/gnome-shell/extensions/${EXTENSION_UUID}"
if [[ -d "${EXT_DIR}" ]]; then
    rm -rf "${EXT_DIR}"
    pass "Extension files removed"
fi

# Remove Flatpak override
OVERRIDE="${HOME}/.local/share/flatpak/overrides/${COPYQ_ID}"
if [[ -f "${OVERRIDE}" ]]; then
    rm -f "${OVERRIDE}"
    pass "Flatpak override removed"
fi

# Remove autostart
AUTOSTART="${HOME}/.config/autostart/com.github.hluk.copyq.desktop"
if [[ -f "${AUTOSTART}" ]]; then
    rm -f "${AUTOSTART}"
    pass "Autostart entry removed"
fi

# Remove GNOME shortcuts
CUSTOM_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
for i in 0 1 2 3; do
    path="${CUSTOM_PATH}/custom${i}"
    sname=$(gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"${path}" name 2>/dev/null || echo "")
    if [[ -n "${sname}" && "${sname}" == *"CopyQ"* ]]; then
        gsettings reset-recursively org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"${path}" 2>/dev/null || true
        pass "Removed shortcut: ${sname}"
    fi
done
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "[]" 2>/dev/null || true

# Remove environment config
ENV_FILE="${HOME}/.config/environment.d/wayland.conf"
if [[ -f "${ENV_FILE}" ]]; then
    rm -f "${ENV_FILE}"
    pass "wayland.conf removed"
fi

# Ask about CopyQ itself
echo -e "\n${YELLOW}CopyQ Flatpak app is still installed. To remove:${NC}"
echo -e "  flatpak uninstall ${COPYQ_ID}"
echo -e "\n${GREEN}Configuration removed. CopyQ app preserved.${NC}\n"
