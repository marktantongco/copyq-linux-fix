#!/usr/bin/env bash
# ==============================================================================
# Step 6: Enable CopyQ Autostart (v2.0)
# ==============================================================================
# GNOME 50 uses systemd --user for autostart. The preferred method for
# Flatpak apps is CopyQ's own autostart preference, which creates the
# correct systemd unit automatically.
# ==============================================================================

set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { echo -e "  ${BLUE}[INFO]${NC} $*"; }
pass() { echo -e "  ${GREEN}[PASS]${NC} $*"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $*"; return 1; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $*"; }

COPYQ_ID="com.github.hluk.copyq"

flatpak list --app 2>/dev/null | grep -qi "${COPYQ_ID}" || fail "CopyQ not installed. Run Step 2 first."

# Method 1: Use CopyQ's built-in autostart (preferred for Flatpak)
info "Enabling autostart via CopyQ preferences..."
if flatpak run --command=copyq "${COPYQ_ID}" --start 2>/dev/null; then
    pass "CopyQ started — autostart preference set in Preferences > General"
else
    warn "Could not set autostart via CLI — configure manually in CopyQ Preferences"
fi

# Method 2: XDG autostart .desktop file (fallback, works via systemd-xdg-autostart-generator)
AUTOSTART_DIR="${HOME}/.config/autostart"
AUTOSTART_TARGET="${AUTOSTART_DIR}/com.github.hluk.copyq.desktop"
mkdir -p "${AUTOSTART_DIR}"

if [[ ! -f "${AUTOSTART_TARGET}" ]]; then
    cat > "${AUTOSTART_TARGET}" << DESKTOP
[Desktop Entry]
Type=Application
Name=CopyQ
Comment=Advanced Clipboard Manager
Exec=flatpak run ${COPYQ_ID}
Icon=com.github.hluk.copyq
Terminal=false
Categories=Utility;Office;
X-GNOME-Autostart-enabled=true
StartupNotify=false
DESKTOP
    pass "XDG autostart entry created"
else
    # Check if old v1.x autostart has X-GNOME-Autostart-Delay (deprecated in GNOME 50)
    if grep -q 'X-GNOME-Autostart-Delay' "${AUTOSTART_TARGET}" 2>/dev/null; then
        sed -i '/^X-GNOME-Autostart-Delay=/d' "${AUTOSTART_TARGET}"
        warn "Removed deprecated X-GNOME-Autostart-Delay from autostart entry"
    fi
    pass "Autostart entry exists"
fi

echo ""
