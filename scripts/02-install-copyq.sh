#!/usr/bin/env bash
# ==============================================================================
# Step 2: Install CopyQ v16+ via Flatpak
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { echo -e "  ${BLUE}[INFO]${NC} $*"; }
pass() { echo -e "  ${GREEN}[PASS]${NC} $*"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $*"; return 1; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $*"; }

COPYQ_ID="com.github.hluk.copyq"
MINIMUM_MAJOR=14

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

# Check current version before install/update
old_ver=""
if flatpak list --app 2>/dev/null | grep -qi "${COPYQ_ID}"; then
    old_ver=$(flatpak list --app --columns=version 2>/dev/null | grep -i copyq | head -1 | tr -d ' ')
    info "CopyQ v${old_ver} already installed — updating..."
else
    info "Installing CopyQ from Flathub..."
fi

flatpak install flathub "${COPYQ_ID}" -y --noninteractive 2>&1 && pass "CopyQ installed/updated" || fail "CopyQ install/update failed"

# Verify version meets minimum
installed_ver=$(flatpak list --app --columns=version 2>/dev/null | grep -i copyq | head -1 | tr -d ' ')
major_num=$(echo "${installed_ver}" | grep -oP '\d+' | head -1)
if [[ -n "${major_num}" && "${major_num}" -ge "${MINIMUM_MAJOR}" ]]; then
    pass "CopyQ v${installed_ver} (meets v${MINIMUM_MAJOR}+ requirement for GNOME extension)"
else
    fail "CopyQ v${installed_ver} is too old — v${MINIMUM_MAJOR}+ required for GNOME Shell extension support"
fi

mkdir -p "${HOME}/.local/share/flatpak/overrides"
echo ""