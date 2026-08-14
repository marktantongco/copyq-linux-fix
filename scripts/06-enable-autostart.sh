#!/usr/bin/env bash
# ==============================================================================
# Step 6: Enable CopyQ Autostart
# ==============================================================================

set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { echo -e "  ${BLUE}[INFO]${NC} $*"; }
pass() { echo -e "  ${GREEN}[PASS]${NC} $*"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $*"; return 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COPYQ_ID="com.github.hluk.copyq"
AUTOSTART_SOURCE="${SCRIPT_DIR}/../config/autostart/com.github.hluk.copyq.desktop"
AUTOSTART_DIR="${HOME}/.config/autostart"
AUTOSTART_TARGET="${AUTOSTART_DIR}/com.github.hluk.copyq.desktop"

flatpak list --app 2>/dev/null | grep -qi "${COPYQ_ID}" || fail "CopyQ not installed. Run Step 2 first."

mkdir -p "${AUTOSTART_DIR}"

if [[ -f "${AUTOSTART_TARGET}" ]]; then
    cp "${AUTOSTART_TARGET}" "${AUTOSTART_TARGET}.bak.$(date +%Y%m%d%H%M%S)"
fi

if [[ -f "${AUTOSTART_SOURCE}" ]]; then
    cp "${AUTOSTART_SOURCE}" "${AUTOSTART_TARGET}"
else
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
X-GNOME-Autostart-Delay=3
StartupNotify=false
DESKTOP
fi

pass "Autostart enabled (3s delay)"
echo ""