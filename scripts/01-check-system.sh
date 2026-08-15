#!/usr/bin/env bash
# ==============================================================================
# Step 1: System Compatibility Check
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
pass_count=0; fail_count=0; warn_count=0
pass() { echo -e "  ${GREEN}[PASS]${NC} $*"; pass_count=$((pass_count+1)); }
fail() { echo -e "  ${RED}[FAIL]${NC} $*"; fail_count=$((fail_count+1)); }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $*"; warn_count=$((warn_count+1)); }

echo -e "${BOLD}Running pre-flight system checks...${NC}\n"

if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    echo -e "  ${BLUE}Detected OS: ${NAME} ${VERSION}${NC}"
    if [[ "${ID:-}" == "ubuntu" ]]; then
        major="${VERSION_ID%%.*}"
        if [[ "${major}" -ge 26 ]]; then
            pass "Ubuntu version ${VERSION_ID} (26.04 or newer)"
        elif [[ "${major}" -eq 24 ]]; then
            warn "Ubuntu ${VERSION_ID} — Wayland is default but Xorg still available"
        else
            warn "Ubuntu ${VERSION_ID} — You may be on an Xorg session. CopyQ should work natively."
        fi
    else
        warn "Not Ubuntu (${ID}). This package targets Ubuntu 26.04 LTS."
    fi
else
    fail "/etc/os-release not found"
fi

session="${XDG_SESSION_TYPE:-unknown}"
if [[ "${session}" == "wayland" ]]; then
    pass "Session type: Wayland"
elif [[ "${session}" == "x11" ]]; then
    warn "Session type: X11 — Wayland patches are unnecessary on X11"
else
    fail "Session type: ${session}"
fi

if command -v gnome-shell &>/dev/null; then
    gnome_ver=$(gnome-shell --version 2>/dev/null | grep -oP '\d+' | head -1)
    if [[ -n "${gnome_ver}" ]]; then
        [[ "${gnome_ver}" -ge 50 ]] && pass "GNOME Shell ${gnome_ver} (v50+)" || warn "GNOME Shell ${gnome_ver} (targets v50)"
    fi
else
    fail "GNOME Shell not found"
fi

if pgrep -x Xwayland &>/dev/null; then
    pass "XWayland running (PID: $(pgrep -x Xwayland | head -1))"
else
    [[ "${session}" == "wayland" ]] && warn "XWayland not detected (may start on demand)"
fi

command -v flatpak &>/dev/null && pass "Flatpak installed" || fail "Flatpak not installed (installer will add it)"
flatpak remotes 2>/dev/null | grep -q flathub && pass "Flathub remote configured" || fail "Flathub remote missing"

ping -c 1 -W 3 flathub.org &>/dev/null 2>&1 && pass "Network: flathub.org reachable" || warn "Network: flathub.org unreachable"

flatpak list 2>/dev/null | grep -qi copyq && warn "CopyQ already installed (will update)" || pass "CopyQ not installed — fresh install"

echo -e "\n${BOLD}  Summary: ${GREEN}${pass_count} passed${NC}, ${YELLOW}${warn_count} warnings${NC}, ${RED}${fail_count} failures${NC}\n"
