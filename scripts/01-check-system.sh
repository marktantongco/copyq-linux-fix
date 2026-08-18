#!/usr/bin/env bash
# ==============================================================================
# Step 1: System Compatibility Check (v2.0)
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
pass_count=0; fail_count=0; warn_count=0
pass() { echo -e "  ${GREEN}[PASS]${NC} $*"; ((pass_count++)); }
fail() { echo -e "  ${RED}[FAIL]${NC} $*"; ((fail_count++)); }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $*"; ((warn_count++)); }
info() { echo -e "  ${BLUE}[INFO]${NC} $*"; }

echo -e "${BOLD}Running pre-flight system checks...${NC}\n"

# OS
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    echo -e "  ${BLUE}Detected OS: ${NAME} ${VERSION}${NC}"
    if [[ "${ID:-}" == "ubuntu" ]]; then
        major="${VERSION_ID%%.*}"
        if [[ "${major}" -ge 26 ]]; then
            pass "Ubuntu version ${VERSION_ID} (26.04 or newer)"
        elif [[ "${major}" -eq 24 ]]; then
            warn "Ubuntu ${VERSION_ID} — Wayland is default but Xorg still available"
            warn "  GNOME Shell extension approach requires GNOME 48+"
        else
            warn "Ubuntu ${VERSION_ID} — GNOME Shell extension may not be available"
        fi
    else
        warn "Not Ubuntu (${ID}). This installer targets Ubuntu 26.04 LTS."
    fi
else
    fail "/etc/os-release not found"
fi

# Session type
session="${XDG_SESSION_TYPE:-unknown}"
if [[ "${session}" == "wayland" ]]; then
    pass "Session type: Wayland"
elif [[ "${session}" == "x11" ]]; then
    warn "Session type: X11 — Wayland patches are unnecessary on X11"
else
    fail "Session type: ${session}"
fi

# GNOME Shell version (v48+ required for GlobalShortcuts portal)
if command -v gnome-shell &>/dev/null; then
    gnome_ver=$(gnome-shell --version 2>/dev/null | grep -oP '\d+' | head -1)
    if [[ -n "${gnome_ver}" ]]; then
        if [[ "${gnome_ver}" -ge 48 ]]; then
            pass "GNOME Shell ${gnome_ver} (v48+ — GlobalShortcuts portal available)"
        elif [[ "${gnome_ver}" -ge 46 ]]; then
            warn "GNOME Shell ${gnome_ver} — GlobalShortcuts portal not available, falling back to gsettings"
        else
            fail "GNOME Shell ${gnome_ver} too old — GNOME Shell extension requires v46+"
        fi
    fi
else
    fail "GNOME Shell not found"
fi

# Flatpak
command -v flatpak &>/dev/null && pass "Flatpak installed" || fail "Flatpak not installed (installer will add it)"
flatpak remotes 2>/dev/null | grep -q flathub && pass "Flathub remote configured" || fail "Flathub remote missing"

# Network
ping -c 1 -W 3 flathub.org &>/dev/null 2>&1 && pass "Network: flathub.org reachable" || warn "Network: flathub.org unreachable"

# gnome-extensions CLI
if command -v gnome-extensions &>/dev/null; then
    pass "gnome-extensions CLI available"
else
    # Try alternative
    if command -v gjs &>/dev/null; then
        warn "gnome-extensions CLI not found, but gjs is available (extension install may still work)"
    else
        warn "gnome-extensions CLI not found — install: sudo apt install gnome-shell-extension-common"
        info "  Alternative: sudo apt install gnome-shell-extensions"
    fi
fi

# Check if CopyQ is already installed and its version
if flatpak list --app 2>/dev/null | grep -qi copyq; then
    installed_ver=$(flatpak list --app --columns=version 2>/dev/null | grep -i copyq | head -1 | tr -d ' ')
    if [[ -n "${installed_ver}" ]]; then
        # Extract major version number
        major_ver="${installed_ver%%.*}"
        major_num=$(echo "${major_ver}" | grep -oP '\d+' | head -1)
        if [[ -n "${major_num}" && "${major_num}" -ge 14 ]]; then
            pass "CopyQ v${installed_ver} already installed (v14+ — GNOME extension supported)"
        elif [[ -n "${major_num}" && "${major_num}" -ge 8 ]]; then
            warn "CopyQ v${installed_ver} installed — v14+ required for GNOME extension. Will update."
        else
            fail "CopyQ v${installed_ver} too old — v14+ required for native Wayland. Will update."
        fi
    else
        warn "CopyQ installed but version detection failed. Will reinstall."
    fi
else
    pass "CopyQ not installed — fresh install"
fi

# Warn about old v1.x overrides
OLD_OVERRIDE="${HOME}/.local/share/flatpak/overrides/com.github.hluk.copyq"
if [[ -f "${OLD_OVERRIDE}" ]] && grep -q 'QT_QPA_PLATFORM=xcb' "${OLD_OVERRIDE}"; then
    warn "OLD v1.x override detected with QT_QPA_PLATFORM=xcb"
    warn "  This will be replaced with native Wayland configuration (v2.0)"
fi

echo -e "\n${BOLD}  Summary: ${GREEN}${pass_count} passed${NC}, ${YELLOW}${warn_count} warnings${NC}, ${RED}${fail_count} failures${NC}\n"
