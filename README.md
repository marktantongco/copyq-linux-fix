# CopyQ Linux Fix — Unified Installer for Ubuntu 26.04 LTS

### Clipboard Manager + Wayland Compatibility + GitHub Pages

[![Ubuntu 26.04](https://img.shields.io/badge/Ubuntu-26.04%20LTS-orange?logo=ubuntu)](https://ubuntu.com/download)
[![GNOME 50](https://img.shields.io/badge/GNOME-50-4A86CF?logo=gnome)](https://www.gnome.org/)
[![Wayland](https://img.shields.io/badge/Wayland-Only-blue)](https://wayland.freedesktop.org/)
[![CopyQ 16.0.0](https://img.shields.io/badge/CopyQ-16.0.0-green)](https://github.com/hluk/CopyQ)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## The Big Picture

### Why This Repo Exists

Ubuntu 26.04 LTS ("Resolute Raccoon") is the **first Ubuntu LTS to ship GNOME 50 on Wayland-only** — there is no Xorg session on the login screen anymore. This is a fundamental architectural shift that breaks many tools we've relied on for decades, and **clipboard managers are one of the hardest hit**.

The core problem: **GNOME's mutter compositor deliberately does not implement the `wl-data-control` protocol** that would allow third-party clipboard managers to monitor clipboard events. This is a privacy-by-design decision — on Wayland, only the focused app and the compositor can read the clipboard.

**CopyQ** is the most powerful open-source clipboard manager available (scripting, tabs, search, editing, image support). But on Ubuntu 26.04's GNOME 50, it cannot natively monitor the clipboard. This repo provides the complete workaround.

### The Solution Architecture

```
Ubuntu 26.04 LTS (GNOME 50 / Wayland-only / No Xorg)
    |
    +-- Native Wayland Apps (Firefox, GNOME Terminal, VS Code)
    |       Protocol: wayland (clipboard: private, no API)
    |
    +-- XWayland Bridge (X11 compatibility layer, auto-started)
    |       Protocol: wayland to compositor, X11 to apps
    |       |
    |       +-- X11 Apps (Wine, old Qt5, legacy GTK2)
    |       |
    |       +-- CopyQ 16.0.0 (Flatpak, forced via XWayland)
    |           Monitors X11 clipboard bridge
    |           Clipboard portal permission granted
    |           GNOME shortcuts registered (Super+V)
    |           Autostart at login with 3s delay
```

**The key insight:** We force CopyQ through the **XWayland bridge** (not native Wayland) so it can monitor the X11 clipboard, which still receives events from most applications. Meanwhile, every other app on your system continues using native Wayland for best performance.

### What's Different About This Repo

This repo provides **two complementary installation methods** plus a full GitHub Pages documentation site:

| Method | File | Best For |
|---|---|---|
| **Rootless `.deb` extractor** | `install-copyq.sh` | Systems without sudo, containers, minimal installs |
| **Unified Flatpak installer** | `install.sh` (orchestrator) | Standard Ubuntu 26.04 desktop with Flatpak |

---

## Quick Start

### Option A: Unified Flatpak Installer (Recommended for Ubuntu 26.04)

```bash
git clone https://github.com/marktantongco/copyq-linux-fix.git
cd copyq-linux-fix
chmod +x install.sh scripts/*.sh
./install.sh
# Log out and back in, then press Super+V to toggle CopyQ
```

### Option B: Rootless Installer (No Sudo, No Flatpak)

```bash
# One-liner
curl -fsSL "https://raw.githubusercontent.com/marktantongco/copyq-linux-fix/main/install-copyq.sh" -o /tmp/install-copyq.sh && chmod +x /tmp/install-copyq.sh && /tmp/install-copyq.sh

# Start
systemctl --user enable --now copyq
```

---

## Unified Installer (Option A) — Full Breakdown

### What It Does (7 Steps)

| Step | Script | Action |
|---|---|---|
| 1 | `scripts/01-check-system.sh` | Pre-flight: OS, session, XWayland, Flatpak, disk, network |
| 2 | `scripts/02-install-copyq.sh` | Install CopyQ 16.0.0 from Flathub |
| 3 | `scripts/03-patch-environment.sh` | Apply `~/.config/environment.d/wayland.conf` |
| 4 | `scripts/04-configure-flatpak.sh` | Set Flatpak overrides (XWayland env, clipboard portal) |
| 5 | `scripts/05-setup-shortcuts.sh` | Register GNOME shortcuts: Super+V, Super+Shift+V |
| 6 | `scripts/06-enable-autostart.sh` | Create `~/.config/autostart/` entry with 3s delay |
| 7 | `scripts/07-post-install-check.sh` | Color-coded pass/fail verification report |

### Installer Modes

```bash
./install.sh                # Full installation
./install.sh --dry-run      # Preview without making changes
./install.sh --diagnose     # Run diagnostics only
./install.sh --uninstall    # Remove everything
./install.sh --help         # Show usage
```

### Package Contents

```
copyq-linux-fix/
|-- README.md                          # THIS FILE
|-- LICENSE                            # MIT license
|-- install.sh                         # Unified installer orchestrator
|-- install-copyq.sh                   # Rootless .deb extractor (standalone)
|
|-- scripts/
|   |-- 01-check-system.sh             # Pre-flight diagnostics
|   |-- 02-install-copyq.sh            # Flatpak install
|   |-- 03-patch-environment.sh        # Wayland env vars
|   |-- 04-configure-flatpak.sh        # Flatpak overrides
|   |-- 05-setup-shortcuts.sh          # GNOME shortcuts
|   |-- 06-enable-autostart.sh         # Autostart entry
|   |-- 07-post-install-check.sh       # Verification
|   |-- diagnose.sh                    # Standalone diagnostic tool
|   +-- uninstall.sh                   # Full removal
|
|-- config/
|   |-- environment.d/
|   |   +-- wayland.conf               # Toolkit env vars (GDK, Qt, SDL, Electron)
|   |-- flatpak-overrides/
|   |   +-- com.github.hluk.copyq      # CopyQ XWayland bridge override
|   +-- autostart/
|       +-- com.github.hluk.copyq.desktop  # Autostart entry
|
|-- docs/
|   |-- WAYLAND-ARCHITECTURE.md         # X11 vs Wayland deep-dive
|   |-- COMPATIBILITY-MATRIX.md         # App-by-app compat table
|   +-- TROUBLESHOOTING.md              # Detailed troubleshooting guide
|
+-- index.html                         # GitHub Pages landing page
```

---

## Configuration Files Explained

### `config/environment.d/wayland.conf`

Loaded by systemd at login. Sets toolkit backends for ALL GUI apps:

```ini
GDK_BACKEND=wayland              # GTK apps -> native Wayland
QT_QPA_PLATFORM=wayland;xcb      # Qt apps -> Wayland, fallback to X11
SDL_VIDEODRIVER=wayland          # SDL apps -> Wayland
ELECTRON_OZONE_PLATFORM_HINT=wayland  # Electron apps -> Wayland
MOZ_ENABLE_WAYLAND=1             # Firefox -> Wayland
```

### `config/flatpak-overrides/com.github.hluk.copyq`

**Overrides the above for CopyQ ONLY** — forces XWayland so clipboard monitoring works:

```ini
[Environment]
QT_QPA_PLATFORM=xcb    # CopyQ: use X11 bridge (clipboard works here)
GDK_BACKEND=x11        # CopyQ: use X11 bridge
```

This is the critical patch: CopyQ goes through XWayland while everything else stays on native Wayland.

---

## The Wayland Problem (Deep Dive)

### Clipboard on X11 (1984-2025)

Any application could monitor the clipboard at any time. Convenient but a privacy nightmare. Keyloggers and spyware could trivially read everything you copy — passwords, credit card numbers, private messages.

### Clipboard on Wayland (GNOME)

Only the focused app and the compositor can read the clipboard. **GNOME's mutter does NOT implement `wl-data-control`**, so no third-party clipboard manager can monitor clipboard events. This is by design.

### Why XWayland Bridge Works

When you copy text in Firefox (native Wayland), GNOME's mutter bridges that clipboard content to the XWayland X11 clipboard for compatibility. CopyQ, running via XWayland, monitors this bridge and captures the event. **This is not guaranteed** — some clipboard events may not be bridged — but it works for most day-to-day usage.

### Compositors That Support Clipboard Managers Natively

| Compositor | wl-data-control | Native Clipboard Manager |
|---|---|---|
| **GNOME (mutter)** | **No** | **Only via XWayland** |
| KDE Plasma (kwin) | Yes | Yes |
| Sway / wlroots | Yes | Yes |
| Hyprland | Yes | Yes |

---

## App Compatibility Matrix

| App | Native Wayland | XWayland | Notes |
|---|---|---|---|
| Firefox | Yes | — | Default in 26.04 |
| GNOME Terminal | Yes | — | Native |
| VS Code | Yes | — | Electron Ozone |
| LibreOffice | Yes | — | Since v7.6+ |
| GIMP | Yes | — | GTK3 native |
| OBS Studio | Yes | — | Wayland capture |
| **CopyQ** | **Partial** | **Full** | **Needs XWayland bridge** |
| Wine | No | Yes | X11 only |
| Steam | Partial | Yes | Proton via XWayland |
| `xdotool` | No | No | Use `ydotool` instead |

See [`docs/COMPATIBILITY-MATRIX.md`](docs/COMPATIBILITY-MATRIX.md) for the full table.

---

## Troubleshooting

| Problem | Solution |
|---|---|
| CopyQ doesn't capture from native Wayland apps | Expected — GNOME doesn't bridge all events. Use the XWayland bridge. |
| Terminal *mouse selections* don't reach CopyQ | Expected on native Wayland — mutter doesn't bridge Wayland-native selections to X11 PRIMARY (CopyQ lives on X11). Ctrl+Shift+C **clipboard** copies still reach CopyQ. This is the accepted tradeoff for running the terminal natively; force it to XWayland only if selection capture matters more. |
| Global hotkeys not working | This package registers GNOME custom shortcuts (Super+V). Check Settings > Keyboard. |
| CopyQ window blank/transparent | `flatpak override --user com.github.hluk.copyq --env=GDK_BACKEND=x11` |
| CopyQ not starting at login | Check `~/.config/autostart/`, re-enable if GNOME disabled it |
| XWayland not running | `ps aux | grep Xwayland` — should start on demand |
| After system update, CopyQ broke | Re-run `./install.sh` or `./scripts/diagnose.sh` |

See [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) for the full guide.

---

## Verify Hotkeys

This package registers two GNOME custom shortcuts: **Super+V** (CopyQ Toggle) and **Super+Shift+V** (CopyQ Menu). Super-key combos are passed through by remote-desktop clients, so they avoid the Ctrl+Alt combos that clients reserve. Here's how to verify they're registered and actually fire — including headless/scripted checks.

> **Gotcha:** GNOME Shell claims `Super+V` for `toggle-message-tray` by default,
> which makes the CopyQ grab silently fail (check `journalctl` for
> `Failed to grab accelerator ... custom0`). The installer frees it by setting
> `toggle-message-tray` to `['<Super>m']` — `Super+M` still opens the tray.

### 1. Verify the shortcuts are registered

```bash
# The custom-keybindings list should contain custom0 and custom1
gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings
# → ['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/',
#    '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/']

gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding
# → '<Super>v'

gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ binding
# → '<Super><Shift>v'
```

### 2. Verify the command side (no key needed)

Run exactly what the hotkey executes and watch for an observable effect:

```bash
# Option A (Flatpak)
flatpak run com.github.hluk.copyq --toggle   # main window should appear/hide
# Option B (rootless)
copyq toggle                                 # returns true
# The main window's X map state should flip between IsViewable/IsUnMapped:
xwininfo -root -tree | grep -i copyq
```

### 3. Simulate the key press

**X11 session** — `xdotool` works because XTEST reaches the compositor's X11 path:

```bash
xdotool key Super_L+v              # toggle
xdotool key Super_L+Shift_L+v       # menu
```

**Wayland session** — plain `xdotool` will *not* trigger compositor grabs (mutter intercepts
accelerators before XWayland sees them). Use one of:

```bash
# wtype — virtual-keyboard protocol (only if the compositor advertises it;
# GNOME mutter frequently does NOT, e.g. in headless/VM sessions)
wtype -M super v -m super                                # toggle
wtype -M super -M shift v -m shift -m super              # menu

# ydotool — injects via /dev/uinput (needs root, or membership in the 'input' group)
# Keycodes: Super=125, Shift=42, V=47
ydotool key 125:1 47:1 47:0 125:0                         # toggle
ydotool key 125:1 42:1 47:1 47:0 42:0 125:0               # menu
```

> **Reality check:** on GNOME Wayland there is no reliable user-level way to synthesize a key
> that hits compositor-level grabs. `wtype` requires the virtual-keyboard protocol (missing on
> many mutter builds), and `ydotool` requires root. If neither works on your session, the
> authoritative test is simply pressing the keys yourself — everything upstream of the keypress
> (dconf registration, `gsd-media-keys`, the CopyQ command) is verifiable with the commands above.

---

## Rootless Installer (Option B) — How It Works

The `install-copyq.sh` script downloads CopyQ's `.deb` packages and extracts them into your home directory without touching `/usr` or `/var`:

1. Runs `apt-get install --simulate copyq` to get the exact dependency list
2. Downloads each `.deb` to a temp directory
3. Extracts with `dpkg-deb -x` (pure extraction, no root)
4. Collects all `lib*.so*` into `~/.local/lib/copyq-runtime/`
5. Writes a thin launcher that sets `QT_QPA_PLATFORM=xcb` and `exec`s the real binary
6. Creates systemd user service for autostart

### Rootless File Layout

```
~/
|-- Applications/copyq/              # extracted app + binary
|-- .local/
|   |-- bin/copyq                    # launcher wrapper
|   |-- lib/copyq-runtime/           # shared libs (Qt6 + KDE6)
|   |-- share/applications/copyq.desktop
|   +-- share/icons/hicolor/.../
|-- .config/systemd/user/copyq.service
+-- .config/copyq/                   # your CopyQ config
```

---

## GitHub Pages

This repo includes a GitHub Pages landing page at [`index.html`](index.html) that serves as the visual documentation companion to this README.

**Live site:** https://marktantongco.github.io/copyq-linux-fix/

---

## Uninstall

### Option A (Flatpak):
```bash
./install.sh --uninstall
```

### Option B (Rootless):
```bash
systemctl --user disable --now copyq 2>/dev/null
rm -rf ~/Applications/copyq ~/.local/lib/copyq-runtime
rm -f ~/.local/bin/copyq ~/.local/share/applications/copyq.desktop
rm -f ~/.config/systemd/user/copyq.service
rm -rf ~/.config/copyq
```

---

## References

- [CopyQ](https://github.com/hluk/CopyQ) — Lukas Holecek
- [Ubuntu 26.04 Release Notes](https://documentation.ubuntu.com/release-notes/26.04/)
- [Ubuntu 26.04 Roadmap](https://discourse.ubuntu.com/t/ubuntu-26-04-lts-the-roadmap/72740)
- [Flathub CopyQ](https://flathub.org/en/apps/com.github.hluk.copyq)
- [CopyQ PPA](https://launchpad.net/~hluk/+archive/ubuntu/copyq)
- [Wayland Protocol](https://wayland.freedesktop.org/)

---

## License

Installer scripts are [MIT](LICENSE). CopyQ itself is GPLv3 — see [hluk/copyq](https://github.com/hluk/copyq).
