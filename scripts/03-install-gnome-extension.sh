#!/usr/bin/env bash
# ==============================================================================
# Step 3: Install CopyQ GNOME Shell Extension (v2.0 — CRITICAL STEP)
# ==============================================================================
# CopyQ v14+ includes a custom GNOME Shell extension that bridges
# MetaSelection (GNOME's internal clipboard API) to CopyQ via D-Bus.
# This is MANDATORY for clipboard monitoring on GNOME Wayland.
#
# The extension UUID is: copyq-clipboard-monitor@hluk.github.com
# It's bundled with CopyQ but must be installed to the host filesystem
# (outside the Flatpak sandbox).
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { echo -e "  ${BLUE}[INFO]${NC} $*"; }
pass() { echo -e "  ${GREEN}[PASS]${NC} $*"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $*"; return 1; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $*"; }

EXTENSION_UUID="copyq-clipboard-monitor@hluk.github.com"
EXTENSION_DIR="${HOME}/.local/share/gnome-shell/extensions/${EXTENSION_UUID}"

info "Installing CopyQ GNOME Shell extension (${EXTENSION_UUID})"
echo -e "  ${YELLOW}This extension is MANDATORY for clipboard monitoring on GNOME Wayland.${NC}"
echo ""

# Method 1: Extract from the installed CopyQ Flatpak
FLATPAK_EXT_PATH="/app/share/gnome-shell/extensions/${EXTENSION_UUID}"

if flatpak list --app 2>/dev/null | grep -qi copyq; then
    info "Attempting to extract extension from CopyQ Flatpak..."
    if flatpak info --show-metadata com.github.hluk.copyq 2>/dev/null | grep -q "share/gnome-shell/extensions"; then
        mkdir -p "${EXTENSION_DIR}"
        if flatpak copy-files --external com.github.hluk.copyq "/app/share/gnome-shell/extensions/${EXTENSION_UUID}" "${HOME}/.local/share/gnome-shell/extensions/" 2>/dev/null; then
            pass "Extension extracted from Flatpak"
        else
            warn "flatpak copy-files failed — trying manual extraction"
        fi
    fi
fi

# Method 2: Download from CopyQ GitHub releases
if [[ ! -f "${EXTENSION_DIR}/metadata.json" ]]; then
    info "Flatpak extraction unavailable — downloading from CopyQ GitHub..."

    # Find latest CopyQ release that includes the extension
    # The extension was added in v14.0.0
    COPYQ_VERSION="16.0.0"
    EXTENSION_URL="https://github.com/hluk/CopyQ/releases/download/v${COPYQ_VERSION}/copyq-gnome-shell-extension-v${COPYQ_VERSION}.zip"
    TMPDIR=$(mktemp -d)

    if command -v curl &>/dev/null; then
        if curl -fsSL "${EXTENSION_URL}" -o "${TMPDIR}/extension.zip" 2>/dev/null; then
            mkdir -p "${EXTENSION_DIR}"
            if unzip -o "${TMPDIR}/extension.zip" -d "${EXTENSION_DIR}" &>/dev/null; then
                pass "Extension downloaded and extracted from GitHub v${COPYQ_VERSION}"
            else
                # Try alternate URL patterns
                info "Standard URL failed, trying CopyQ source tarball..."
                SOURCE_URL="https://github.com/hluk/CopyQ/archive/refs/tags/v${COPYQ_VERSION}.tar.gz"
                curl -fsSL "${SOURCE_URL}" -o "${TMPDIR}/source.tar.gz" 2>/dev/null && \
                tar xzf "${TMPDIR}/source.tar.gz" -C "${TMPDIR}" && \
                cp -r "${TMPDIR}/CopyQ-v${COPYQ_VERSION}/src/platform/linux/gnome_shell/extension/"* "${EXTENSION_DIR}/" 2>/dev/null && \
                pass "Extension extracted from source tarball" || \
                warn "Could not extract extension from source tarball"
            fi
        else
            warn "Download failed — extension may need manual installation"
        fi
    else
        warn "curl not available — cannot download extension"
    fi

    rm -rf "${TMPDIR}"
fi

# Method 3: Check if it was already installed
if [[ -f "${EXTENSION_DIR}/metadata.json" ]]; then
    pass "Extension files found at ${EXTENSION_DIR}"
    ext_name=$(grep -oP '"name"\s*:\s*"\K[^"]+' "${EXTENSION_DIR}/metadata.json" 2>/dev/null || echo "unknown")
    info "Extension name: ${ext_name}"
else
    fail "Extension NOT found after all methods"
    echo -e "  ${YELLOW}Manual install: Visit https://github.com/hluk/CopyQ and download the GNOME extension${NC}"
    echo -e "  ${YELLOW}Then extract it to: ${EXTENSION_DIR}${NC}"
    return 0
fi

# Enable the extension
info "Enabling extension..."
if command -v gnome-extensions &>/dev/null; then
    if gnome-extensions enable "${EXTENSION_UUID}" 2>/dev/null; then
        pass "GNOME Shell extension enabled"
    else
        # Extension may need GNOME Shell restart
        warn "Could not enable via CLI — may need to enable in GNOME Extensions app"
        info "  After relogin: open Extensions app and enable 'CopyQ Clipboard Monitor'"
    fi

    # Verify it's listed
    if gnome-extensions list 2>/dev/null | grep -q "${EXTENSION_UUID}"; then
        pass "Extension registered with GNOME Shell"
    else
        warn "Extension not yet visible — requires GNOME Shell restart (relogin)"
    fi
else
    warn "gnome-extensions CLI not available — enable manually after relogin"
    info "  Open: gnome-extensions-app or Settings > Extensions > CopyQ Clipboard Monitor"
fi

echo -e "  ${YELLOW}IMPORTANT: You MUST log out and back in (or restart GNOME Shell) for the extension to load.${NC}"
echo ""