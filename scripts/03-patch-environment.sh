#!/usr/bin/env bash
# ==============================================================================
# Step 3: Patch Environment Variables for Wayland Compatibility
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { echo -e "  ${BLUE}[INFO]${NC} $*"; }
pass() { echo -e "  ${GREEN}[PASS]${NC} $*"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $*"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $*"; return 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_SOURCE="${SCRIPT_DIR}/../config/environment.d/wayland.conf"
ENV_TARGET_DIR="${HOME}/.config/environment.d"
ENV_TARGET="${ENV_TARGET_DIR}/wayland.conf"

mkdir -p "${ENV_TARGET_DIR}"

[[ ! -f "${ENV_SOURCE}" ]] && fail "Source not found: ${ENV_SOURCE}"

if [[ -f "${ENV_TARGET}" ]]; then
    if diff -q "${ENV_SOURCE}" "${ENV_TARGET}" &>/dev/null; then
        pass "wayland.conf already up to date"; exit 0
    fi
    cp "${ENV_TARGET}" "${ENV_TARGET}.bak.$(date +%Y%m%d%H%M%S)"
    warn "Backed up existing wayland.conf"
fi

cp "${ENV_SOURCE}" "${ENV_TARGET}"
[[ -f "${ENV_TARGET}" ]] && pass "wayland.conf installed" || fail "Install failed"

var_count=$(grep -cE '^[A-Z_]+=' "${ENV_TARGET}" 2>/dev/null || echo "0")
info "${var_count} environment variables configured"
info "${YELLOW}Log out/in or reboot required for system-wide effect.${NC}"
echo ""
