#!/usr/bin/env bash
# ==============================================================================
# Step 7: Post-Install Verification (v2.0)
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
echo -e "${BOLD}Post-install verification (v2.0)...${NC}\n"

# CopyQ installed + version check
echo -e "${BOLD}── CopyQ Installation ──${NC}"
if flatpak list --app 2>/dev/null | grep -qi "${COPYQ_ID}"; then
    ver=$(flatpak list --app --columns=version 2>/dev/null | grep -i copyq | head -1 | tr -d ' ')
    major=$(echo "${ver}" | grep -oP '\d+' | head -1)
    if [[ -n "${major}" && "${major}" -ge 14 ]]; then
        pass "CopyQ v${ver} (v14+ — GNOME extension compatible)"
    else
        fail "CopyQ v${ver} too old — v14+ required for GNOME extension"
    fi
else
    fail "CopyQ NOT installed"
fi

# Flatpak override check
echo -e "\n${BOLD}── Flatpak Override ──${NC}"
OVERRIDE="${HOME}/.local/share/flatpak/overrides/${COPYQ_ID}"
if [[ -f "${OVERRIDE}" ]]; then
    pass "Flatpak override exists"
    # CRITICAL: Must NOT have XWayland forcing
    if grep -q 'QT_QPA_PLATFORM=xcb' "${OVERRIDE}"; then
        fail "  OVERWRITE STILL FORCES XWAYLAND (QT_QPA_PLATFORM=xcb) — breaks clipboard monitoring!"
    else
        pass "  No XWayland forcing (correct for v2.0)"
    fi
    if grep -q 'GDK_BACKEND=x11' "${OVERRIDE}"; then
        warn "  GDK_BACKEND=x11 found (unnecessary for native Wayland)"
    else
        pass "  No GDK_BACKEND=x11 (correct)"
    fi
    if grep -q 'COPYQ_USE_PORTAL' "${OVERRIDE}"; then
        pass "  Portal shortcuts enabled (COPYQ_USE_PORTAL)"
    else
        warn "  COPYQ_USE_PORTAL not set"
    fi
    if grep -q 'sockets=wayland' "${OVERRIDE}"; then
        pass "  Wayland socket enabled"
    else
        fail "  Wayland socket NOT configured"
    fi
else
    fail "Flatpak override NOT found"
fi

# GNOME Shell extension check (CRITICAL)
echo -e "\n${BOLD}── GNOME Shell Extension (CRITICAL) ──${NC}"
EXT_DIR="${HOME}/.local/share/gnome-shell/extensions/${EXTENSION_UUID}"
if [[ -f "${EXT_DIR}/metadata.json" ]]; then
    pass "GNOME Shell extension installed"
    ext_ver=$(grep -oP '"version"\s*:\s*\K\d+' "${EXT_DIR}/metadata.json" 2>/dev/null || echo "?")
    [[ -n "${ext_ver}" && "${ext_ver}" != "?" ]] && info "  Extension version: ${ext_ver}"
else
    fail "GNOME Shell extension NOT found — clipboard monitoring will NOT work!"
    info "  Install: See Step 3 or https://github.com/hluk/CopyQ"
fi

if command -v gnome-extensions &>/dev/null; then
    if gnome-extensions list 2>/dev/null | grep -q "${EXTENSION_UUID}"; then
        pass "Extension registered with GNOME Shell"
    else
        warn "Extension not yet registered — requires relogin"
    fi
    ext_state=$(gnome-extensions show "${EXTENSION_UUID}" 2>/dev/null | grep -oP 'State\s*:\s*\K\w+' || echo "unknown")
    if [[ "${ext_state}" == "ENABLED" ]]; then
        pass "Extension is ENABLED"
    elif [[ "${ext_state}" == "DISABLED" ]]; then
        warn "Extension is DISABLED — enable it after relogin"
    else
        info "Extension state: ${ext_state} (check after relogin)"
    fi
fi

# Session
echo -e "\n${BOLD}── Environment ──${NC}"
[[ "${XDG_SESSION_TYPE:-}" == "wayland" ]] && pass "Wayland session" || warn "Not Wayland (${XDG_SESSION_TYPE:-unknown})"

if command -v gnome-shell &>/dev/null; then
    gnome_ver=$(gnome-shell --version 2>/dev/null | grep -oP '\d+' | head -1)
    [[ "${gnome_ver}" -ge 48 ]] && pass "GNOME ${gnome_ver} (GlobalShortcuts portal available)" || warn "GNOME ${gnome_ver}"
fi

echo -e "\n${BOLD}  ${GREEN}Pass: ${pass_count}${NC} | ${YELLOW}Warn: ${warn_count}${NC} | ${RED}Fail: ${fail_count}${NC}"
if [[ ${fail_count} -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}All critical checks passed!${NC}"
    echo -e "${YELLOW}NEXT: Log out and back in to load the GNOME Shell extension.${NC}"
    echo -e "${YELLOW}Then: Press Ctrl+Alt+V (or your configured shortcut) to toggle CopyQ.${NC}"
else
    echo -e "${RED}Some checks failed — review above.${NC}"
fi
echo ""