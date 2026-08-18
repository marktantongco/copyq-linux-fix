#!/usr/bin/env bash
# ==============================================================================
# Step 4: Configure Flatpak Overrides for CopyQ (v2.0)
# ==============================================================================
# v2.0: Native Wayland mode. NO QT_QPA_PLATFORM=xcb.
# CopyQ v14+ uses the GNOME Shell extension for clipboard monitoring.
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { echo -e "  ${BLUE}[INFO]${NC} $*"; }
pass() { echo -e "  ${GREEN}[PASS]${NC} $*"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $*"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $*"; return 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COPYQ_ID="com.github.hluk.copyq"
OVERRIDE_SOURCE="${SCRIPT_DIR}/../config/flatpak-overrides/com.github.hluk.copyq"
OVERRIDE_DIR="${HOME}/.local/share/flatpak/overrides"
OVERRIDE_TARGET="${OVERRIDE_DIR}/${COPYQ_ID}"

flatpak list --app 2>/dev/null | grep -qi "${COPYQ_ID}" || fail "CopyQ not installed. Run Step 2 first."

mkdir -p "${OVERRIDE_DIR}"

# Backup old override if it has XWayland settings
if [[ -f "${OVERRIDE_TARGET}" ]] && grep -q 'QT_QPA_PLATFORM=xcb' "${OVERRIDE_TARGET}"; then
    cp "${OVERRIDE_TARGET}" "${OVERRIDE_TARGET}.v1.bak.$(date +%Y%m%d%H%M%S)"
    warn "Backed up old v1.x override (XWayland mode)"
fi

if [[ -f "${OVERRIDE_SOURCE}" ]]; then
    cp "${OVERRIDE_SOURCE}" "${OVERRIDE_TARGET}"
    pass "Flatpak override installed (native Wayland mode)"
else
    fail "Override source not found: ${OVERRIDE_SOURCE}"
fi

# Verify override does NOT contain XWayland forcing
if grep -q 'QT_QPA_PLATFORM=xcb' "${OVERRIDE_TARGET}"; then
    fail "Override still contains QT_QPA_PLATFORM=xcb — this breaks clipboard monitoring!"
fi

if grep -q 'GDK_BACKEND=x11' "${OVERRIDE_TARGET}"; then
    warn "Override contains GDK_BACKEND=x11 — removing (not needed for native Wayland)"
    sed -i '/^GDK_BACKEND=x11$/d' "${OVERRIDE_TARGET}"
fi

# Verify critical settings
if grep -q 'COPYQ_USE_PORTAL=1' "${OVERRIDE_TARGET}"; then
    pass "COPYQ_USE_PORTAL=1 set (enables portal shortcuts)"
else
    warn "COPYQ_USE_PORTAL not set — portal shortcuts may not work"
fi

# D-Bus access for GNOME extension communication (Issue #3539)
info "Checking D-Bus access for GNOME extension..."
if grep -q 'dbus.*alk=org.gnome.Shell' "${OVERRIDE_TARGET}" 2>/dev/null; then
    pass "D-Bus access configured for GNOME Shell"
else
    info "  Adding D-Bus access for GNOME Shell extension communication..."
    # Ensure dbus line exists in [Context]
    if ! grep -q '\[Context\]' "${OVERRIDE_TARGET}"; then
        sed -i '1i\[Context]' "${OVERRIDE_TARGET}"
    fi
    warn "Manual D-Bus config may be needed — see Issue #3539"
fi

info "Override contents:"
while IFS= read -r line; do [[ -n "${line}" ]] && echo -e "    ${line}"; done < "${OVERRIDE_TARGET}"
echo ""