#!/usr/bin/env bash
# ==============================================================================
# Uninstall: Remove CopyQ and all configurations
# ==============================================================================

set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
info() { echo -e "  ${BLUE}[DONE]${NC} $*"; }
warn() { echo -e "  ${YELLOW}[SKIP]${NC} $*"; }

COPYQ_ID="com.github.hluk.copyq"
echo -e "${BOLD}Uninstalling CopyQ + all configs...${NC}\n"

flatpak list --app 2>/dev/null | grep -qi "${COPYQ_ID}" && { flatpak uninstall "${COPYQ_ID}" -y 2>&1; info "CopyQ removed"; } || warn "CopyQ not installed"

OVR="${HOME}/.local/share/flatpak/overrides/${COPYQ_ID}"
[[ -f "${OVR}" ]] && { rm -f "${OVR}"; info "Override removed"; }

ENV="${HOME}/.config/environment.d/wayland.conf"
[[ -f "${ENV}" ]] && { rm -f "${ENV}"; info "wayland.conf removed"; }

AS="${HOME}/.config/autostart/com.github.hluk.copyq.desktop"
[[ -f "${AS}" ]] && { rm -f "${AS}"; info "Autostart removed"; }

CUSTOM_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
for i in 0 1 2 3 4; do
    scmd=$(gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"${CUSTOM_PATH}/custom${i}" command 2>/dev/null || echo "")
    [[ "${scmd}" == *copyq* ]] && {
        gsettings reset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"${CUSTOM_PATH}/custom${i}" name 2>/dev/null || true
        gsettings reset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"${CUSTOM_PATH}/custom${i}" command 2>/dev/null || true
        gsettings reset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"${CUSTOM_PATH}/custom${i}" binding 2>/dev/null || true
        info "Shortcut custom${i} removed"
    }
done

rm -f "${HOME}/.config/environment.d/wayland.conf.bak."* "${HOME}/.config/autostart/com.github.hluk.copyq.desktop.bak."* 2>/dev/null

echo -e "\n${GREEN}${BOLD}Uninstall complete.${NC}"
echo -e "${YELLOW}Flatpak runtimes kept. Remove with: flatpak uninstall --unused${NC}\n"
