#!/usr/bin/env bash
# ==============================================================================
# Step 4: Configure Flatpak Overrides for CopyQ
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

if [[ -f "${OVERRIDE_SOURCE}" ]]; then
    cp "${OVERRIDE_SOURCE}" "${OVERRIDE_TARGET}"
    pass "Flatpak override installed"
else
    warn "Override source not found — creating minimal..."
    cat > "${OVERRIDE_TARGET}" << 'EOF'
[Context]
filesystems=xdg-config/gtk-3.0:ro;xdg-config/gtk-4.0:ro;xdg-config/kdeglobals:ro
sockets=wayland;x11

[Environment]
# CRITICAL: CopyQ must use XWayland for clipboard monitoring.
# GNOME mutter does NOT implement wl-data-control protocol.
# These override the system-wide wayland.conf for CopyQ only.
#
# NOTE: XDG Desktop Portal clipboard (v1.18+) is for remote desktop
# sessions only, NOT for third-party clipboard managers.
#
# WARNING (Issue #3587): QT_QPA_PLATFORM=xcb can break clipboard
# monitoring when the main window is closed. Keep CopyQ minimized.
QT_QPA_PLATFORM=xcb
GDK_BACKEND=x11
EOF
    pass "Minimal override created"
fi

info "Setting clipboard portal permission..."
flatpak override --user "${COPYQ_ID}" --permission=clipboard=yes 2>&1 || warn "Clipboard permission flag not supported (ok on older Flatpak)"

info "Checking for ydotool (Wayland keyboard simulation)..."
if command -v ydotool &>/dev/null; then
    if pgrep -x ydotoold &>/dev/null; then
        pass "ydotool + ydotoold available (keyboard simulation works)"
    else
        warn "ydotool found but ydotoold daemon not running"
        info "  Enable: systemctl --user enable --now ydotoold"
    fi
else
    info "ydotool not installed (optional — for CopyQ script keyboard simulation)"
    info "  Install: sudo apt install ydotool && systemctl --user enable --now ydotoold"
fi

warn "NOTE: Issue #3587 — Closing CopyQ main window may stop clipboard monitoring on XWayland"
info "  Workaround: Keep CopyQ minimized, not closed. Use tray icon."
info "  Or enable tray-only mode in CopyQ Preferences > Appearance > Show Tray Icon"

info "Override contents:"
while IFS= read -r line; do [[ -n "${line}" ]] && echo -e "    ${line}"; done < "${OVERRIDE_TARGET}"
echo ""
