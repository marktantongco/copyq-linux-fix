#!/usr/bin/env bash
# ==============================================================================
# Ubuntu 26.04 LTS — CopyQ Native Wayland Installer
# ==============================================================================
# CopyQ v14+ uses a GNOME Shell extension (MetaSelection D-Bus bridge) for
# clipboard monitoring on GNOME Wayland. This installer configures native
# Wayland mode — no XWayland forcing.
#
# Usage: ./install.sh [--dry-run] [--uninstall] [--diagnose] [--help]
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
LOG_FILE="${SCRIPT_DIR}/install.log"
PASS=0; FAIL=0; WARN=0; TOTAL=7

log()  { local l="$1"; shift; echo -e "[${l}] $*" | tee -a "${LOG_FILE}"; }
info() { log "${BLUE}INFO${NC}"  "$*"; }
pass() { log "${GREEN}PASS${NC}"  "$*"; ((PASS++)); }
fail() { log "${RED}FAIL${NC}"  "$*"; ((FAIL++)); }
warn() { log "${YELLOW}WARN${NC}"  "$*"; ((WARN++)); }

banner() {
    echo -e "${CYAN}${BOLD}"
    echo "  ╔═══════════════════════════════════════════════════════════╗"
    echo "  ║   CopyQ Native Wayland Installer for Ubuntu 26.04    ║"
    echo "  ║   Version 2.0.0 | GNOME 50 | Native Wayland Mode     ║"
    echo "  ╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "  ${YELLOW}v2.0 uses the GNOME Shell extension for clipboard monitoring.${NC}"
    echo -e "  ${YELLOW}The XWayland bridge approach (v1.x) is no longer needed.${NC}"
    echo ""
}

run_step() {
    local n="$1" name="$2" script="$3"
    echo -e "\n${BOLD}━━━ Step ${n}/${TOTAL}: ${name} ━━━${NC}"
    if [[ "${DRY:-false}" == "true" ]]; then
        info "[DRY RUN] Would execute: ${script}"; return 0
    fi
    [[ ! -f "${script}" ]] && { fail "Not found: ${script}"; return 1; }
    if bash "${script}"; then pass "Step ${n} done"
    else fail "Step ${n} failed"; return 1; fi
}

summary() {
    echo -e "\n${BOLD}═══════════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}✓ Passed:   ${PASS}${NC}"
    echo -e "  ${YELLOW}⚠ Warnings: ${WARN}${NC}"
    echo -e "  ${RED}✗ Failed:   ${FAIL}${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"
    if [[ ${FAIL} -gt 0 ]]; then
        echo -e "${RED}Errors occurred. Log: ${LOG_FILE}${NC}"
    else
        echo -e "${GREEN}${BOLD}Success! Log out/in to activate the GNOME Shell extension,${NC}"
        echo -e "${GREEN}${BOLD}then press Ctrl+Alt+V to toggle CopyQ.${NC}"
    fi
    echo ""
}

DRY="false"; MODE="install"
for arg in "${@}"; do
    case "${arg}" in
        --dry-run)   DRY="true" ;;
        --uninstall) MODE="uninstall" ;;
        --diagnose)  MODE="diagnose" ;;
        --help|-h)
            echo "Usage: $0 [--dry-run] [--uninstall] [--diagnose] [--help]"; exit 0 ;;
        *) echo "Unknown: ${arg}"; exit 1 ;;
    esac
done

banner
[[ "${DRY}" == "true" ]] && echo -e "${YELLOW}  *** DRY RUN ***${NC}\n"

case "${MODE}" in
    uninstall)
        bash "${SCRIPTS_DIR}/uninstall.sh" ;;
    diagnose)
        bash "${SCRIPTS_DIR}/diagnose.sh" ;;
    install)
        echo "" > "${LOG_FILE}"
        run_step 1 "System Check"           "${SCRIPTS_DIR}/01-check-system.sh" || true
        run_step 2 "Install CopyQ"          "${SCRIPTS_DIR}/02-install-copyq.sh" || true
        run_step 3 "Install GNOME Extension" "${SCRIPTS_DIR}/03-install-gnome-extension.sh" || true
        run_step 4 "Configure Flatpak"      "${SCRIPTS_DIR}/04-configure-flatpak.sh" || true
        run_step 5 "Setup Shortcuts"        "${SCRIPTS_DIR}/05-setup-shortcuts.sh" || true
        run_step 6 "Enable Autostart"       "${SCRIPTS_DIR}/06-enable-autostart.sh" || true
        run_step 7 "Post-Install Check"    "${SCRIPTS_DIR}/07-post-install-check.sh" || true
        summary ;;
esac
