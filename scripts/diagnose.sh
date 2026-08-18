#!/usr/bin/env bash
# ==============================================================================
# Standalone Diagnostic Tool (v2.0)
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
pass_count=0; fail_count=0; warn_count=0
pass() { echo -e "  ${GREEN}[PASS]${NC} $*"; ((pass_count++)); }
fail() { echo -e "  ${RED}[FAIL]${NC} $*"; ((fail_count++)); }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $*"; ((warn_count++)); }
info() { echo -e "  ${BLUE}[INFO]${NC} $*"; }

COPYQ_ID="com.github.hluk.copyq"
EXTENSION_UUID="copyq-clipboard-monitor@hluk.github.com"

echo -e "${CYAN}${BOLD}"
echo "  CopyQ Native Wayland Diagnostic Report (v2.0)"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "${NC}\n"

# OS
[[ -f /etc/os-release ]] && { . /etc/os-release; info "OS: ${NAME} ${VERSION}"; } || fail "Cannot detect OS"

# Desktop
if command -v gnome-shell &>/dev/null; then
    gnome_ver=$(gnome-shell --version 2>/dev/null | grep -oP '\d+' | head -1)
    info "Desktop: GNOME Shell ${gnome_ver}"
    [[ "${gnome_ver}" -ge 48 ]] && pass "  GlobalShortcuts portal available" || warn "  GNOME <48: portal shortcuts unavailable"
else
    warn "GNOME Shell not detected"
fi
info "Session: ${XDG_SESSION_TYPE:-unknown}"

# CopyQ
echo -e "\n${BOLD}── CopyQ Status ──${NC}"
if flatpak list --app 2>/dev/null | grep -qi "${COPYQ_ID}"; then
    ver=$(flatpak list --app --columns=version 2>/dev/null | grep -i copyq | head -1 | tr -d ' ')
    major=$(echo "${ver}" | grep -oP '\d+' | head -1)
    if [[ -n "${major}" && "${major}" -ge 14 ]]; then
        pass "CopyQ v${ver} (v14+ — GNOME extension compatible)"
    else
        warn "CopyQ v${ver} — v14+ required for GNOME extension support"
    fi
    flatpak ps 2>/dev/null | grep -qi copyq && pass "CopyQ is running" || warn "CopyQ not running"
else
    fail "CopyQ NOT installed"
fi

# Flatpak Override
echo -e "\n${BOLD}── Flatpak Override ──${NC}"
OVERRIDE="${HOME}/.local/share/flatpak/overrides/${COPYQ_ID}"
if [[ -f "${OVERRIDE}" ]]; then
    pass "Override exists"
    echo -e "  ${CYAN}Contents:${NC}"
    while IFS= read -r line; do [[ -n "${line}" ]] && echo -e "    ${line}"; done < "${OVERRIDE}"
    echo ""
    if grep -q 'QT_QPA_PLATFORM=xcb' "${OVERRIDE}"; then
        fail "  XWAYLAND FORCING DETECTED (QT_QPA_PLATFORM=xcb) — this breaks clipboard monitoring!"
        info "  Fix: Remove QT_QPA_PLATFORM=xcb and GDK_BACKEND=x11 from override"
        info "  Run: ./install.sh to reconfigure for v2.0 (native Wayland)"
    else
        pass "  No XWayland forcing (correct)"
    fi
    grep -q 'COPYQ_USE_PORTAL' "${OVERRIDE}" && pass "  Portal shortcuts configured" || warn "  COPYQ_USE_PORTAL not set"
else
    fail "No Flatpak override found"
fi

# GNOME Shell Extension (CRITICAL)
echo -e "\n${BOLD}── GNOME Shell Extension (CRITICAL) ──${NC}"
EXT_DIR="${HOME}/.local/share/gnome-shell/extensions/${EXTENSION_UUID}"
if [[ -f "${EXT_DIR}/metadata.json" ]]; then
    pass "Extension installed at ${EXT_DIR}"
else
    fail "Extension NOT installed — clipboard monitoring will NOT work!"
    info "  The CopyQ GNOME Shell extension is MANDATORY for GNOME Wayland."
    info "  Install: ./install.sh (Step 3)"
fi

if command -v gnome-extensions &>/dev/null; then
    if gnome-extensions list 2>/dev/null | grep -q "${EXTENSION_UUID}"; then
        pass "Extension registered with GNOME Shell"
        ext_state=$(gnome-extensions show "${EXTENSION_UUID}" 2>/dev/null | grep -oP 'State\s*:\s*\K\w+' || echo "unknown")
        [[ "${ext_state}" == "ENABLED" ]] && pass "  Extension is ENABLED" || warn "  Extension state: ${ext_state}"
        ext_err=$(gnome-extensions show "${EXTENSION_UUID}" 2>/dev/null | grep -oP 'Error\s*:\s*\K.*' || echo "")
        [[ -n "${ext_err}" && "${ext_err}" != "None" && "${ext_err}" != "" ]] && fail "  Extension error: ${ext_err}"
    else
        warn "Extension not registered — requires relogin after installation"
    fi
else
    warn "gnome-extensions CLI not available — check Extensions app manually"
fi

# Shortcuts
echo -e "\n${BOLD}── Shortcuts ──${NC}"
CUSTOM_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
found=false
for i in 0 1 2 3; do
    sname=$(gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"${CUSTOM_PATH}/custom${i}" name 2>/dev/null || echo "")
    [[ -n "${sname}" && "${sname}" != "''" ]] && { pass "Shortcut: ${sname}"; found=true; }
done
[[ "${found}" == "false" ]] && info "No gsettings shortcuts (GNOME 48+ uses portal shortcuts instead)"

# Autostart
[[ -f "${HOME}/.config/autostart/com.github.hluk.copyq.desktop" ]] && pass "Autostart exists" || warn "No autostart entry"

echo -e "\n  ${GREEN}Pass:${pass_count}${NC} ${YELLOW}Warn:${warn_count}${NC} ${RED}Fail:${fail_count}${NC}\n"