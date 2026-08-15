#!/usr/bin/env bash
# ==============================================================================
# Step 7: Post-Install Verification
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
pass_count=0; fail_count=0; warn_count=0
pass() { echo -e "  ${GREEN}[PASS]${NC} $*"; ((pass_count++)); }
fail() { echo -e "  ${RED}[FAIL]${NC} $*"; ((fail_count++)); }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $*"; ((warn_count++)); }
info() { echo -e "  ${BLUE}[INFO]${NC} $*"; }

COPYQ_ID="com.github.hluk.copyq"
echo -e "${BOLD}Post-install verification...${NC}\n"

# CopyQ installed
if flatpak list --app 2>/dev/null | grep -qi "${COPYQ_ID}"; then
    ver=$(flatpak list --app --columns=version 2>/dev/null | grep -i copyq | head -1 | tr -d ' ')
    pass "CopyQ installed (v${ver})"
else
    fail "CopyQ NOT installed"
fi

# Flatpak override
OVERRIDE="${HOME}/.local/share/flatpak/overrides/${COPYQ_ID}"
if [[ -f "${OVERRIDE}" ]]; then
    pass "Flatpak override exists"
    grep -q 'QT_QPA_PLATFORM=xcb' "${OVERRIDE}" && pass "  QT_QPA_PLATFORM=xcb" || fail "  QT_QPA_PLATFORM missing"
    grep -q 'GDK_BACKEND=x11' "${OVERRIDE}" && pass "  GDK_BACKEND=x11" || fail "  GDK_BACKEND missing"
else
    fail "Flatpak override NOT found"
fi

# Environment
ENV_FILE="${HOME}/.config/environment.d/wayland.conf"
if [[ -f "${ENV_FILE}" ]]; then
    pass "wayland.conf exists"
    for var in GDK_BACKEND QT_QPA_PLATFORM SDL_VIDEODRIVER ELECTRON_OZONE_PLATFORM_HINT; do
        grep -q "${var}=" "${ENV_FILE}" && pass "  ${var} set" || warn "  ${var} missing"
    done
else
    fail "wayland.conf NOT found"
fi

# Shortcuts
CUSTOM_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
found=false
for i in 0 1; do
    sname=$(gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"${CUSTOM_PATH}/custom${i}" name 2>/dev/null || echo "")
    [[ -n "${sname}" && "${sname}" != "''" ]] && { pass "Shortcut: ${sname}"; found=true; }
done
[[ "${found}" == "false" ]] && warn "No GNOME shortcuts found (may need relogin)"

# Autostart
AUTOSTART="${HOME}/.config/autostart/com.github.hluk.copyq.desktop"
[[ -f "${AUTOSTART}" ]] && pass "Autostart entry exists" || fail "Autostart missing"

# Session
[[ "${XDG_SESSION_TYPE:-}" == "wayland" ]] && pass "Wayland session" || warn "Not Wayland (${XDG_SESSION_TYPE:-unknown})"

# XWayland
pgrep -x Xwayland &>/dev/null && pass "XWayland running" || warn "XWayland not detected (may start on demand)"

# ydotool (optional)
if command -v ydotool &>/dev/null; then
    pgrep -x ydotoold &>/dev/null && pass "ydotool daemon running" || warn "ydotool found but ydotoold not running"
else
    info "ydotool not installed (optional)"
fi

# Issue #3587 warning
echo -e "  ${YELLOW}[INFO]${NC} See docs/TROUBLESHOOTING.md Section 8 for Issue #3587 (XWayland monitoring drop)"

echo -e "\n${BOLD}  ${GREEN}Pass: ${pass_count}${NC} | ${YELLOW}Warn: ${warn_count}${NC} | ${RED}Fail: ${fail_count}${NC}"
[[ ${fail_count} -eq 0 ]] && echo -e "${GREEN}${BOLD}All critical checks passed! Press Ctrl+Alt+V to toggle CopyQ.${NC}" || echo -e "${YELLOW}Some checks failed — review above.${NC}"
echo ""
