#!/usr/bin/env bash
# ==============================================================================
# Standalone Diagnostic Tool
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
pass_count=0; fail_count=0; warn_count=0
pass() { echo -e "  ${GREEN}[PASS]${NC} $*"; ((pass_count++)); }
fail() { echo -e "  ${RED}[FAIL]${NC} $*"; ((fail_count++)); }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $*"; ((warn_count++)); }
info() { echo -e "  ${BLUE}[INFO]${NC} $*"; }

COPYQ_ID="com.github.hluk.copyq"

echo -e "${CYAN}${BOLD}"
echo "  CopyQ + Wayland Diagnostic Report"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "${NC}\n"

# OS
[[ -f /etc/os-release ]] && { . /etc/os-release; info "OS: ${NAME} ${VERSION}"; } || fail "Cannot detect OS"

# Desktop
command -v gnome-shell &>/dev/null && info "Desktop: $(gnome-shell --version 2>/dev/null)" || warn "GNOME Shell not detected"
info "Session: ${XDG_SESSION_TYPE:-unknown}"

# XWayland
if pgrep -x Xwayland &>/dev/null; then
    pass "XWayland running (PID: $(pgrep -x Xwayland | head -1))"
else
    warn "XWayland not detected"
fi

# CopyQ
if flatpak list --app 2>/dev/null | grep -qi "${COPYQ_ID}"; then
    ver=$(flatpak list --app --columns=version 2>/dev/null | grep -i copyq | head -1 | tr -d ' ')
    pass "CopyQ v${ver} installed"
    flatpak ps 2>/dev/null | grep -qi copyq && pass "CopyQ is running" || warn "CopyQ not running"
else
    fail "CopyQ NOT installed"
fi

# Override
OVERRIDE="${HOME}/.local/share/flatpak/overrides/${COPYQ_ID}"
if [[ -f "${OVERRIDE}" ]]; then
    pass "Flatpak override exists"
    echo -e "  ${CYAN}Contents:${NC}"
    while IFS= read -r line; do [[ -n "${line}" ]] && echo -e "    ${line}"; done < "${OVERRIDE}"
else
    fail "No Flatpak override"
fi

# Environment
ENV_FILE="${HOME}/.config/environment.d/wayland.conf"
if [[ -f "${ENV_FILE}" ]]; then
    pass "wayland.conf exists"
    for var in GDK_BACKEND QT_QPA_PLATFORM SDL_VIDEODRIVER ELECTRON_OZONE_PLATFORM_HINT; do
        fval=$(grep "^${var}=" "${ENV_FILE}" 2>/dev/null | cut -d= -f2 || echo "")
        eval="${val}=$(printenv "${var}" 2>/dev/null || echo "(unset)")
        [[ "${eval}" != "(unset)" ]] && pass "  ${var}=${eval} (active)" || \
            [[ -n "${fval}" ]] && warn "  ${var}=${fval} (relogin needed)" || fail "  ${var} not set"
    done
else
    fail "wayland.conf NOT found"
fi

# Shortcuts
CUSTOM_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
for i in 0 1 2 3; do
    sname=$(gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"${CUSTOM_PATH}/custom${i}" name 2>/dev/null || echo "")
    [[ -n "${sname}" && "${sname}" != "''" ]] && pass "Shortcut: ${sname}"
done

# Autostart
[[ -f "${HOME}/.config/autostart/com.github.hluk.copyq.desktop" ]] && pass "Autostart exists" || fail "No autostart"

# Display
echo -n "  DISPLAY="; [[ -n "${DISPLAY:-}" ]] && pass "${DISPLAY} (XWayland reachable)" || warn "(unset)"

# Session type and XWayland status
info "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-unknown}"
pgrep -x Xwayland &>/dev/null && pass "XWayland running (PID: $(pgrep -x Xwayland | head -1))" || warn "XWayland not running"

# Flatpak override environment check
if [[ -f "${OVERRIDE}" ]]; then
    grep -q 'QT_QPA_PLATFORM=xcb' "${OVERRIDE}" && pass "Override: QT_QPA_PLATFORM=xcb" || fail "Override: QT_QPA_PLATFORM not set to xcb"
    grep -q 'GDK_BACKEND=x11' "${OVERRIDE}" && pass "Override: GDK_BACKEND=x11" || fail "Override: GDK_BACKEND not set to x11"
fi

# ydotool (optional)
if command -v ydotool &>/dev/null; then
    if pgrep -x ydotoold &>/dev/null; then
        pass "ydotool + ydotoold available (keyboard simulation works)"
    else
        warn "ydotool found but ydotoold daemon not running"
        info "  Enable: systemctl --user enable --now ydotoold"
    fi
else
    info "ydotool not installed (optional — for CopyQ script keyboard simulation)"
fi

# GNOME CopyQ Clipboard Monitor extension
if gnome-extensions list 2>/dev/null | grep -qi "copyq-clipboard-monitor\|copyq_clipboard_monitor"; then
    warn "GNOME CopyQ Clipboard Monitor extension detected"
    warn "  This extension is for native/X11 CopyQ only — it does NOT work with Flatpak CopyQ"
    info "  Consider disabling it to avoid confusion"
else
    info "GNOME CopyQ Clipboard Monitor extension not installed (expected for Flatpak setup)"
fi

echo -e "\n  ${GREEN}Pass:${pass_count}${NC} ${YELLOW}Warn:${warn_count}${NC} ${RED}Fail:${fail_count}${NC}\n"
