#!/usr/bin/env bash
# ==============================================================================
# Step 2: Install CopyQ 16.0.0 via Flatpak
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { echo -e "  ${BLUE}[INFO]${NC} $*"; }
pass() { echo -e "  ${GREEN}[PASS]${NC} $*"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $*"; return 1; }

COPYQ_ID="com.github.hluk.copyq"

if ! command -v flatpak &>/dev/null; then
    info "Flatpak not found. Installing..."
    sudo apt update && sudo apt install -y flatpak
    command -v flatpak &>/dev/null && pass "Flatpak installed" || fail "Flatpak install failed"
fi

flatpak remotes 2>/dev/null | grep -q flathub || {
    info "Adding Flathub remote..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    pass "Flathub remote added"
}

if flatpak list --app 2>/dev/null | grep -qi "${COPYQ_ID}"; then
    info "CopyQ already installed — updating..."
else
    info "Installing CopyQ from Flathub..."
fi

flatpak install flathub "${COPYQ_ID}" -y --noninteractive 2>&1 && pass "CopyQ installed" || fail "CopyQ install failed"

installed_ver=$(flatpak info "${COPYQ_ID}" 2>/dev/null | awk '/^Version/{print $2}' || true)
info "Installed version: ${installed_ver}"
mkdir -p "${HOME}/.local/share/flatpak/overrides"
echo ""
