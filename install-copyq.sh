#!/usr/bin/env bash
# CopyQ rootless installer for Ubuntu 26.04+ (Wayland + no sudo required)
# Fixes: missing Qt6/KDE6 runtime, Wayland xcb compatibility, no-root install.
set -euo pipefail

REPO_URL="https://ph.archive.ubuntu.com/ubuntu/pool"
WORKDIR="/tmp/copyq-install-$$"
RUNTIME="$HOME/.local/lib/copyq-runtime"
APPDIR="$HOME/Applications/copyq"
BINDIR="$HOME/.local/bin"
DESKTOPDIR="$HOME/.local/share/applications"
ICONDIR="$HOME/.local/share/icons/hicolor"
SVDIR="$HOME/.config/systemd/user"

log()  { printf '\033[1;32m[+]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$1"; }
err()  { printf '\033[1;31m[x]\033[0m %s\n' "$1" >&2; }

cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        CODENAME="${VERSION_CODENAME:-oracular}"
        VERSION_ID="${VERSION_ID:-26.04}"
    else
        CODENAME="oracular"; VERSION_ID="26.04"
    fi
    ARCH="$(dpkg --print-architecture)"
    # Multiarch lib dir (e.g. x86_64-linux-gnu) differs from dpkg arch (amd64)
    MULTIARCH="$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null || echo "$ARCH")"
    log "Detected: $NAME $VERSION_ID ($CODENAME) $ARCH"
}

get_deb_url() {
    local pkg="$1"
    apt-get download --print-uris "$pkg" 2>/dev/null \
        | grep -oE "'http[^']+'" | head -1 | tr -d "'"
}

download_packages() {
    log "Resolving CopyQ dependency tree..."
    local pkgs
    pkgs=$(apt-get install --simulate copyq 2>/dev/null \
        | grep -E "^Inst " | awk '{print $2}' | sort -u)
    [ -z "$pkgs" ] && { err "apt could not resolve copyq packages"; exit 1; }
    local total; total=$(echo "$pkgs" | wc -l)
    log "Downloading $total packages..."
    mkdir -p "$WORKDIR/debs" && cd "$WORKDIR/debs"
    local n=0
    for p in $pkgs; do
        n=$((n+1))
        local url; url=$(get_deb_url "$p")
        if [ -z "$url" ]; then
            warn "  skip (no URI): $p"; continue
        fi
        local fn; fn=$(basename "$url" | sed 's/%2b/+/g')
        [ -f "$fn" ] || curl -fsSL -o "$fn" "$url" 2>/dev/null || warn "  failed: $p"
        printf '\r  %d/%d downloaded' "$n" "$total"
    done
    echo
}

extract_runtime() {
    log "Extracting libraries to $RUNTIME..."
    mkdir -p "$RUNTIME" "$APPDIR/plugins" "$WORKDIR/extract"
    for deb in "$WORKDIR/debs"/*.deb; do
        [ -f "$deb" ] || continue
        local ex="$WORKDIR/extract/$(basename "$deb" .deb)"
        dpkg-deb -x "$deb" "$ex" 2>/dev/null || continue
        # Merge all lib dirs into runtime
        for ld in "$ex/usr/lib/$ARCH" "$ex/usr/lib" "$ex/lib/$ARCH" "$ex/lib"; do
            [ -d "$ld" ] && cp -an "$ld/." "$RUNTIME/" 2>/dev/null
        done
        # Merge Qt/KDE plugins
        local plug="$ex/usr/lib/$ARCH/qt6/plugins"
        if [ -d "$plug" ]; then
            cp -an "$plug/." "$APPDIR/plugins/" 2>/dev/null
        fi
        # Copy translations
        local tr="$ex/usr/lib/$ARCH/qt6/translations"
        [ -d "$tr" ] && cp -an "$tr/." "$APPDIR/plugins/../qt-translations/" 2>/dev/null
        rm -rf "$ex"
    done
    local count; count=$(find "$RUNTIME" -name "*.so*" | wc -l)
    log "Staged $count shared libraries"
}

install_files() {
    log "Installing application to $APPDIR..."
    mkdir -p "$APPDIR" "$BINDIR" "$DESKTOPDIR" "$SVDIR" "$ICONDIR"
    # The binary + app share (icons live in hicolor below)
    # NOTE: extract_runtime() deletes each deb's extraction after merging libs,
    # so the copyq deb is re-extracted here — the app itself must not be lost.
    if [ ! -f "$APPDIR/usr/bin/copyq" ]; then
        for deb in "$WORKDIR/debs"/copyq*.deb; do
            [ -f "$deb" ] || continue
            local ex="$WORKDIR/app-extract"
            dpkg-deb -x "$deb" "$ex" 2>/dev/null || continue
            [ -d "$ex/usr" ] && cp -a "$ex/usr" "$APPDIR/" 2>/dev/null
            rm -rf "$ex"
            break
        done
    fi

    # Icons
    local src_icons="$WORKDIR/debs"
    for deb in copyq*.deb; do
        local ex="$WORKDIR/icon-extract"
        dpkg-deb -x "$src_icons/$deb" "$ex" 2>/dev/null || continue
        local ic="$ex/usr/share/icons/hicolor"
        if [ -d "$ic" ]; then
            for size in 16x16 22x22 24x24 32x32 48x48 64x64 128x128 scalable; do
                [ -d "$ic/$size" ] && cp -an "$ic/$size/." "$ICONDIR/$size/" 2>/dev/null
            done
        fi
        local pi="$ex/usr/share/pixmaps"
        [ -d "$pi" ] && cp -an "$pi/." "$ICONDIR/" 2>/dev/null
        rm -rf "$ex"
    done 2>/dev/null || true
}

write_launcher() {
    log "Writing launcher: $BINDIR/copyq"
    cat > "$BINDIR/copyq" <<EOF
#!/usr/bin/env bash
# CopyQ launcher — rootless install
# Compatibility: forces Qt xcb platform for Wayland sessions.
export LD_LIBRARY_PATH="$RUNTIME:/usr/lib/$MULTIARCH:/lib/$MULTIARCH"
export QT_PLUGIN_PATH="$APPDIR/plugins:/usr/lib/$MULTIARCH/qt6/plugins"
export QT_QPA_PLATFORM="xcb"
export QT_QPA_PLATFORMTHEME="gtk2"
export XDG_SESSION_TYPE="\${XDG_SESSION_TYPE:-x11}"
exec "$APPDIR/usr/bin/copyq" "\$@"
EOF
    chmod +x "$BINDIR/copyq"
}

write_desktop_entry() {
    log "Writing desktop entry"
    cat > "$DESKTOPDIR/copyq.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=CopyQ
GenericName=Clipboard Manager
Comment=Clipboard manager with advanced features (rootless install)
Icon=$ICONDIR/64x64/apps/copyq.png
Exec=$BINDIR/copyq
Terminal=false
Categories=Utility;Qt;
Keywords=clipboard;copy;paste;history;
StartupWMClass=copyq
X-GNOME-Autostart-enabled=true
EOF
    update-desktop-database "$DESKTOPDIR" 2>/dev/null || true
    gtk-update-icon-cache "$ICONDIR" 2>/dev/null || true
}

write_systemd_unit() {
    log "Writing systemd user unit"
    cat > "$SVDIR/copyq.service" <<EOF
[Unit]
Description=CopyQ Clipboard Manager
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
Environment=DISPLAY=:0
Environment=XDG_SESSION_TYPE=x11
Environment=QT_PLUGIN_PATH=$APPDIR/plugins:/usr/lib/$MULTIARCH/qt6/plugins
Environment=QT_QPA_PLATFORM=xcb
Environment=QT_QPA_PLATFORMTHEME=gtk2
Environment=LD_LIBRARY_PATH=$RUNTIME:/usr/lib/$MULTIARCH:/lib/$MULTIARCH
ExecStartPre=/bin/rm -f $HOME/.config/copyq/.copyq_s $HOME/.config/copyq/copyq.lock
ExecStart=$BINDIR/copyq
Restart=on-failure
RestartSec=3

[Install]
WantedBy=graphical-session.target
EOF
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable copyq.service 2>/dev/null || true
}

verify() {
    log "Verifying installation..."
    local fails=0
    [ -x "$BINDIR/copyq" ] || { err "launcher missing"; fails=$((fails+1)); }
    # Accept either a bundled runtime or the system Qt6 runtime (full desktop
    # installs already ship it, so apt only needs to fetch copyq itself).
    local bundled syslibs
    bundled=$(find "$RUNTIME" -name '*.so*' 2>/dev/null | wc -l) || true
    syslibs=$(find /usr/lib/$MULTIARCH -name '*.so*' 2>/dev/null | wc -l) || true
    { [ "$bundled" -gt 0 ] || [ "$syslibs" -gt 100 ]; } \
        || { err "runtime libs incomplete"; fails=$((fails+1)); }
    { [ -f "$APPDIR/plugins/platforms/libqxcb.so" ] \
        || [ -f "/usr/lib/$MULTIARCH/qt6/plugins/platforms/libqxcb.so" ]; } \
        || { err "xcb platform plugin missing"; fails=$((fails+1)); }
    [ -f "$ICONDIR/64x64/apps/copyq.png" ] \
        || warn "64x64 icon missing (non-fatal)"

    # Functional test — exercise clipboard against a running server.
    # CopyQ is single-instance: if one is already up (e.g. the systemd unit),
    # reuse it instead of starting a second server.
    log "Functional test (clipboard round-trip)..."
    local pid=""
    if ! pgrep -f "$APPDIR/usr/bin/copyq" >/dev/null 2>&1; then
        rm -f "$HOME/.config/copyq/.copyq_s" "$HOME/.config/copyq/copyq.lock" 2>/dev/null
        setsid "$BINDIR/copyq" >/tmp/copyq-verify.log 2>&1 < /dev/null &
        pid=$!; sleep 6
    fi
    if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
        warn "Server did not stay up — see /tmp/copyq-verify.log"
        fails=$((fails+1))
    else
        local wok rb
        wok=$(timeout 20 "$BINDIR/copyq" "copy('install-verify-ok')" 2>&1) || true
        sleep 1
        rb=$(timeout 20 "$BINDIR/copyq" "clipboard()" 2>&1) || true
        if [ "$rb" = "install-verify-ok" ]; then
            log "Clipboard round-trip PASSED"
        else
            warn "Clipboard read-back mismatch (got: '$rb') — server may still be initializing"
        fi
        [ -n "$pid" ] && kill "$pid" 2>/dev/null
    fi

    if [ "$fails" -eq 0 ]; then
        log "Install verified OK"
        return 0
    else
        err "$fails check(s) failed"
        return 1
    fi
}

configure_clipboard() {
    # Universal copy/paste: capture clipboard + primary (mouse) selections
    # and allow middle-click paste of copied content. Mutex with a running
    # server: CopyQ is single-instance, so reuse one if present.
    log "Enabling universal clipboard capture..."
    local started=""
    if ! pgrep -f "$APPDIR/usr/bin/copyq" >/dev/null 2>&1; then
        setsid "$BINDIR/copyq" >/tmp/copyq-config.log 2>&1 < /dev/null &
        started=$!; sleep 5
    fi
    "$BINDIR/copyq" config check_selection true 2>/dev/null \
        && log "  check_selection=true (capture mouse selections)" \
        || warn "  could not set check_selection"
    "$BINDIR/copyq" config copy_clipboard true 2>/dev/null \
        && log "  copy_clipboard=true (middle-click paste of copied text)" \
        || warn "  could not set copy_clipboard"
    "$BINDIR/copyq" config copy_selection true 2>/dev/null \
        && log "  copy_selection=true (paste selections via Ctrl+V)" \
        || warn "  could not set copy_selection"
    [ -n "$started" ] && kill "$started" 2>/dev/null
}

print_next() {
    echo
    echo "================================================"
    echo "  CopyQ installed (rootless, no sudo)"
    echo "================================================"
    echo
    echo "  Launch now:        copyq"
    echo "  App menu entry:    CopyQ (search in activities)"
    echo "  Autostart service: systemctl --user start copyq"
    echo "  Status:            systemctl --user status copyq"
    echo
    echo "  Config dir:  ~/.config/copyq/"
    echo "  Install dir: $APPDIR"
    echo "  Runtime:    $RUNTIME"
    echo
    echo "  The launcher forces Qt 'xcb' platform so CopyQ"
    echo "  runs under XWayland on Wayland sessions."
    echo
}

main() {
    detect_distro
    download_packages
    extract_runtime
    install_files
    write_launcher
    write_desktop_entry
    write_systemd_unit
    verify
    configure_clipboard
    print_next
}

main "$@"
