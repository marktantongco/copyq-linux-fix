# CopyQ Linux Fix — Clipboard Manager for Ubuntu 26.04 LTS (Wayland-Only)

### Flatpak Installer + GNOME Extension + Diagnostics + GitHub Pages

[![Ubuntu 26.04](https://img.shields.io/badge/Ubuntu-26.04%20LTS-E95420?logo=ubuntu)](https://ubuntu.com/download)
[![GNOME 50](https://img.shields.io/badge/GNOME-50-4A86CF?logo=gnome)](https://www.gnome.org/)
[![Wayland](https://img.shields.io/badge/Wayland-Only-6DA4E3)](https://wayland.freedesktop.org/)
[![CopyQ 16.0.0](https://img.shields.io/badge/CopyQ-16.0.0-green)](https://github.com/hluk/CopyQ)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## The Problem

Ubuntu 26.04 LTS is the **first Ubuntu LTS to ship GNOME 50 on Wayland-only** — there is no Xorg session on the login screen. This breaks most clipboard managers because:

1. **GNOME's mutter compositor does not implement `wl-data-control`** — no third-party app can monitor clipboard events on native Wayland (privacy-by-design decision)
2. **CopyQ's Flatpak build cannot register GNOME Shell extensions** from the sandbox — the native Wayland clipboard monitoring method (GNOME Shell extension) does not work with Flatpak installations
3. **The XWayland bridge workaround still works** — but requires correct configuration

This repo provides a **modular 7-step installer** that handles all of this automatically.

---

## Two Installation Paths

CopyQ v14.0.0+ supports clipboard monitoring on GNOME via a dedicated GNOME Shell extension. However, this extension **cannot be installed from the Flatpak sandbox** ([CopyQ official docs](https://copyq.readthedocs.io/en/latest/known-issues.html)). This creates two distinct paths:

| | Path A: Flatpak + XWayland Bridge | Path B: PPA/deb + GNOME Extension |
|---|---|---|
| **How** | Forces CopyQ through XWayland to monitor the X11 clipboard bridge | Installs CopyQ as a system package; extension monitors clipboard via D-Bus |
| **Compatibility** | Any GNOME version with XWayland (GNOME 40+) | GNOME 46+ only; breaks on GNOME major updates |
| **Clipboard capture** | Text and images from most apps | All clipboard content including PRIMARY selection |
| **Memory** | ~120–160MB (Flatpak runtime + X11 client libs) | ~60–80MB (shared system libraries) |
| **Stability** | XWayland is a 40-year stable ABI | GNOME extension depends on internal, undocumented APIs |
| **Status** | **Default — works today** | Advanced — requires `--native` flag |

### Quick Start (Default: Flatpak + XWayland)

```bash
git clone https://github.com/marktantongco/copyq-linux-fix.git
cd copyq-linux-fix
chmod +x install.sh scripts/*.sh
./install.sh
# Log out and back in, then press Ctrl+Alt+V to toggle CopyQ
```

### Advanced: Native Wayland via PPA

```bash
./install.sh --native
# This installs CopyQ from the hluk PPA instead of Flatpak,
# enabling the GNOME Shell extension for true native clipboard monitoring.
# Requires sudo. The PPA version must be v14.0.0+ for extension support.
```

### Rootless Installer (No Sudo, No Flatpak)

```bash
curl -fsSL "https://raw.githubusercontent.com/marktantongco/copyq-linux-fix/main/install-copyq.sh" -o /tmp/install-copyq.sh && chmod +x /tmp/install-copyq.sh && /tmp/install-copyq.sh
systemctl --user enable --now copyq
```

---

## How It Works

### Architecture (Default: Flatpak + XWayland Bridge)

```
Native Wayland App (Firefox, GNOME Terminal, VS Code)
    | clipboard event
    v
GNOME Mutter (Wayland compositor)
    | bridges clipboard to XWayland for compatibility
    v
XWayland X11 Server (auto-started, always present on GNOME)
    | X11 CLIPBOARD selection
    v
CopyQ 16.0.0 (Flatpak, QT_QPA_PLATFORM=xcb)
    | Monitors X11 clipboard
    v
Clipboard history captured
```

**Key insight:** CopyQ is the only app forced through XWayland. Everything else runs native Wayland for best performance. The XWayland bridge translates clipboard events from Wayland to X11, which CopyQ can monitor.

### Architecture (Native: PPA + GNOME Extension)

```
Any App (copy action)
    | clipboard event
    v
GNOME Mutter
    | Meta.Selection owner-changed signal
    v
CopyQ GNOME Shell Extension (copyq-clipboard-monitor@hluk.github.com)
    | D-Bus signal
    v
CopyQ (native Wayland, system package)
    | Stores clipboard content
    v
Clipboard history captured
```

### Why the GNOME Extension Does Not Work with Flatpak

From [CopyQ's official documentation](https://copyq.readthedocs.io/en/latest/known-issues.html):

> "The GNOME extension is only available when CopyQ is installed on the system (e.g. from a package manager). It will **not** work when running CopyQ as a **Flatpak or AppImage** because the extension cannot be registered with the GNOME Shell from a sandboxed environment."

GNOME Shell extensions must be installed to `~/.local/share/gnome-shell/extensions/` and loaded by the gnome-shell process itself. Flatpak sandboxes cannot write to the host's GNOME extension directory or register extensions with the running shell. This is a fundamental Flatpak security constraint, not a bug.

---

## Installer Breakdown (7 Steps)

| Step | Script | Action |
|---|---|---|
| 1 | `scripts/01-check-system.sh` | Pre-flight: OS version, Wayland session, GNOME Shell version, Flatpak, Flathub, network, existing CopyQ version, old v1.x override detection |
| 2 | `scripts/02-install-copyq.sh` | Install/update CopyQ v16.0.0+ from Flathub (or PPA if `--native`) |
| 3 | `scripts/03-install-gnome-extension.sh` | Install CopyQ GNOME Shell extension to host filesystem (downloaded from GitHub or extracted from Flatpak sandbox) |
| 4 | `scripts/04-configure-flatpak.sh` | Apply Flatpak override: Wayland socket, D-Bus access for GNOME Shell, portal shortcuts (`COPYQ_USE_PORTAL=1`), XWayland forcing (default path only) |
| 5 | `scripts/05-setup-shortcuts.sh` | GNOME 48+: XDG GlobalShortcuts portal (native Wayland). GNOME <48: gsettings custom keybindings (legacy fallback) |
| 6 | `scripts/06-enable-autostart.sh` | XDG autostart entry + CopyQ built-in autostart preference |
| 7 | `scripts/07-post-install-check.sh` | Color-coded verification: CopyQ version, Flatpak override, GNOME extension, environment, shortcuts |

### Installer Modes

```bash
./install.sh                # Full installation (default: Flatpak + XWayland bridge)
./install.sh --native      # Full installation (PPA/deb + GNOME extension)
./install.sh --dry-run      # Preview without making changes
./install.sh --diagnose     # Run diagnostics only
./install.sh --uninstall    # Remove all configuration (keeps CopyQ app)
./install.sh --help         # Show usage
```

---

## Project Structure

```
copyq-linux-fix/
├── README.md                              # This file
├── LICENSE                                # MIT license
├── install.sh                           # Unified installer orchestrator (v2.0.1)
├── install-copyq.sh                     # Rootless .deb extractor (standalone, no sudo)
│
├── scripts/
│   ├── 01-check-system.sh               # Pre-flight diagnostics
│   ├── 02-install-copyq.sh              # Flatpak/PPA install
│   ├── 03-install-gnome-extension.sh     # GNOME Shell extension installer
│   ├── 04-configure-flatpak.sh         # Flatpak overrides + permissions
│   ├── 05-setup-shortcuts.sh           # Global shortcut registration
│   ├── 06-enable-autostart.sh          # Autostart configuration
│   ├── 07-post-install-check.sh        # Verification suite
│   ├── diagnose.sh                     # Standalone diagnostic tool
│   └── uninstall.sh                    # Full removal script
│
├── config/
│   ├── environment.d/
│   │   └── wayland.conf                # System-wide Wayland env vars (GTK, Qt, SDL, Electron)
│   ├── flatpak-overrides/
│   │   └── com.github.hluk.copyq     # Flatpak override (D-Bus, sockets, portal)
│   └── autostart/
│       └── com.github.hluk.copyq.desktop  # XDG autostart entry
│
├── docs/
│   ├── WAYLAND-ARCHITECTURE.md          # X11 vs Wayland clipboard deep-dive
│   ├── COMPATIBILITY-MATRIX.md          # 32-app compatibility table
│   └── TROUBLESHOOTING.md               # 11-section diagnostic guide
│
└── index.html                           # GitHub Pages landing page
```

---

## Configuration Files

### `config/environment.d/wayland.conf`

Loaded by systemd at login. Sets toolkit backends for **all** GUI apps system-wide:

```ini
GDK_BACKEND=wayland                    # GTK apps -> native Wayland
QT_QPA_PLATFORM=wayland;xcb            # Qt apps -> Wayland first, X11 fallback
SDL_VIDEODRIVER=wayland                # SDL apps -> Wayland
ELECTRON_OZONE_PLATFORM_HINT=wayland  # Electron apps -> Wayland
MOZ_ENABLE_WAYLAND=1                   # Firefox -> Wayland
```

**Note:** CopyQ is NOT affected by these variables when using the Flatpak override (which sets its own environment). These are general-purpose defaults for other applications.

### `config/flatpak-overrides/com.github.hluk.copyq`

Per-application Flatpak override. Currently configures native Wayland mode with portal shortcuts:

```ini
[Context]
filesystems=xdg-config/gtk-3.0:ro;xdg-config/gtk-4.0:ro;xdg-config/kdeglobals:ro
sockets=wayland
dbus=session    talk=org.gnome.Shell;org.gnome.Shell.Screenshot;org.gnome.Shell.Extensions.CopyQClipboardMonitor

[Environment]
COPYQ_USE_PORTAL=1
```

**For the default (XWayland bridge) path**, the installer adds `QT_QPA_PLATFORM=xcb` and `GDK_BACKEND=x11` to the `[Environment]` section and changes `sockets=wayland;x11`. See `docs/TROUBLESHOOTING.md` Section 1 for details.

---

## Clipboard on Wayland: Why This Is Hard

### X11 Clipboard (1984–present)

Any application could monitor the clipboard at any time. Convenient for clipboard managers but a privacy nightmare — keyloggers and spyware could trivially read everything you copy.

### Wayland Clipboard on GNOME

Only the focused app and the compositor can read the clipboard. GNOME's mutter does NOT implement `wl-data-control`, so no third-party clipboard manager can monitor clipboard events natively. This is an intentional privacy decision.

### Available Workarounds

| Method | How | Works on GNOME? | Limitations |
|---|---|---|---|
| **XWayland bridge** | Force CopyQ through X11 compat layer | Yes (default path) | ~3–5ms latency per event, Issue #3587 |
| **GNOME Shell extension** | Monitor Meta.Selection via D-Bus | Yes (PPA/deb only) | Cannot work from Flatpak sandbox |
| **XDG Clipboard Portal** | Remote desktop portal extension | Partial (remote desktop only) | Not designed for clipboard managers |

### Compositor Comparison

| Compositor | `wl-data-control` | Native Clipboard Manager | CopyQ Mode |
|---|---|---|---|
| **GNOME (mutter)** | No | XWayland bridge or GNOME extension | Special configuration needed |
| KDE Plasma (kwin) | Yes | Yes | Native Wayland, no workarounds |
| Sway / wlroots | Yes | Yes | Native Wayland via `wlr-data-control` |
| Hyprland | Yes | Yes | Native Wayland via `wlr-data-control` |

See [`docs/WAYLAND-ARCHITECTURE.md`](docs/WAYLAND-ARCHITECTURE.md) for the full technical deep-dive.

---

## Alternatives to CopyQ on GNOME Wayland

If you don't need CopyQ's advanced features (scripting, tabs, image support, item editing), simpler alternatives exist that work out of the box on GNOME Wayland:

| Manager | Type | Install | Features | GNOME 50 | Downloads |
|---|---|---|---|---|---|
| **Clipboard Indicator** | GNOME Extension | [extensions.gnome.org/779](https://extensions.gnome.org/extension/779/clipboard-indicator) | History, search, favorites, cache size limit | Yes (MetaSelection) | 2M+ |
| **GNOME Clipboard History** | GNOME Extension | [extensions.gnome.org/4839](https://extensions.gnome.org/extension/4839/clipboard-history) | History, search, pinned items, keyboard navigation | Yes (MetaSelection) | 500K+ |
| **GPaste** | Daemon + Extension | `sudo apt install gpaste` | History, search, DBus API | Yes (daemon) | Mature |
| **Clipman** | GNOME Extension | [extensions.gnome.org/9407](https://extensions.gnome.org/extension/9407/clipman-clipboard-monitor) | History, registry integration | Yes (MetaSelection) | Moderate |
| **CopyQ** (this repo) | Full App | This repo | Scripting, tabs, search, images, editing, sync | Via XWayland/extension | N/A |

**When to use CopyQ over the alternatives:**

- You need **image clipboard support** (copy/paste screenshots, images from GIMP)
- You need **scripting** (automate clipboard manipulation with Lua/Python/JavaScript)
- You need **tabs** (organize clipboard history by context: work, personal, code)
- You need **item editing** (modify clipboard content before pasting)
- You need **full-text search** across clipboard history
- You need **command-line interface** for integration with other tools

**When to use Clipboard Indicator instead:**

- You just need basic clipboard history with search
- You want zero-configuration installation from GNOME Extensions
- You don't want to deal with Flatpak, XWayland, or D-Bus configuration

---

## Application Compatibility

### Key Applications

| App | Native Wayland | Clipboard Reaches CopyQ | Notes |
|---|---|---|---|
| Firefox | Yes | Yes | Default on Ubuntu 26.04 |
| Google Chrome | Yes | Yes | Ozone/Wayland backend |
| GNOME Terminal | Yes | Yes | VTE/GTK4 native |
| VS Code | Yes | Yes | Electron Ozone |
| LibreOffice | Yes | Yes | Native Wayland since v7.6+ |
| VS Code (Snap) | Yes | Partial | Snap sandbox may restrict clipboard portal |
| **CopyQ** | **Forced XWayland** | **Monitors X11 bridge** | **Deliberate configuration** |
| Wine | No (X11 only) | Yes | Already X11, auto-bridged |
| Steam | Partial | Yes | Proton via XWayland |
| Telegram | Yes | Yes | Qt6 native Wayland |
| Discord/Slack | Yes | Yes | Electron Ozone |

### Broken on Wayland

| Tool | Status | Replacement |
|---|---|---|
| `xdotool` | Completely broken (uses X11 XTest) | `ydotool` (kernel uinput) |
| `xsel`/`xclip` | Only works for XWayland apps | `wl-copy`/`wl-paste` (native Wayland) |

See [`docs/COMPATIBILITY-MATRIX.md`](docs/COMPATIBILITY-MATRIX.md) for the full 32-app table with toolkit details.

---

## Troubleshooting

### Common Issues

| Problem | Likely Cause | Solution |
|---|---|---|
| CopyQ doesn't capture clipboard | Not running via XWayland (or extension not loaded) | Run `./scripts/diagnose.sh` and check override |
| Global hotkeys not working | Portal not configured or GNOME <48 | Check `COPYQ_USE_PORTAL=1` in override; use gsettings fallback |
| CopyQ window blank/transparent | Rendering issue with platform backend | `flatpak override --user com.github.hluk.copyq --env=GDK_BACKEND=x11` |
| Clipboard stops when window closed | [Issue #3587](https://github.com/hluk/CopyQ/issues/3587) — XWayland bug | Keep CopyQ minimized, not closed; or use `--start` flag |
| Extension not visible after install | GNOME Shell hasn't restarted | Log out and back in (or restart GNOME Shell with Alt+F2 -> r) |
| CopyQ not starting at login | Autostart disabled or service crashed | Check `~/.config/autostart/`; re-enable in CopyQ Preferences |
| PRIMARY selection not captured | XWayland doesn't bridge all selection types | Known limitation; use native Wayland path (PPA) if needed |
| `copy()` scripting command fails | Wayland blocks keyboard simulation | Use CopyQ's Wayland Support command (Preferences > Items) |

### Diagnostic Tool

```bash
# Run standalone diagnostics
./scripts/diagnose.sh

# Or via the installer
./install.sh --diagnose
```

See [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) for the full 11-section diagnostic guide.

---

## Version History

### v2.0.1 (Current) — Bug Fix Release

Fixed 5 critical bugs found during system audit:

- **FIX**: Flatpak override D-Bus key typo (`alk=` → `talk=`) — D-Bus access to GNOME Shell was completely broken
- **FIX**: gsettings JSON missing closing `]` bracket — legacy shortcut registration (GNOME <48) silently failed
- **FIX**: Non-existent `flatpak copy-files` subcommand in extension installer — replaced with `flatpak run --command=sh` extraction
- **FIX**: `X-GNOME-Autostart-Delay=3` in autostart template — deprecated in GNOME 50, removed
- **FIX**: grep pattern in `04-configure-flatpak.sh` matched typo instead of intended key

### v2.0.0 — Native Wayland Rewrite

- Added GNOME Shell extension installation (Step 3)
- Switched from XWayland bridge to native Wayland mode as default
- Added `COPYQ_USE_PORTAL=1` for GlobalShortcuts portal support
- Added GNOME 48+ version detection for shortcut strategy selection
- Updated all 7 installer scripts for v2.0 architecture

**Note:** v2.0.0's default Flatpak + GNOME extension approach has a known architectural limitation: the GNOME Shell extension cannot be registered from the Flatpak sandbox ([CopyQ official docs](https://copyq.readthedocs.io/en/latest/known-issues.html)). The XWayland bridge remains the reliable default for Flatpak installations.

### v1.4.0 — Emil Kowalski Motion System

- Spring easings, orchestrated stagger, magnetic hover, animated counters
- Parallax, ripple taps, flow arrow animations on landing page

### v1.3.0 — Impeccable Design Upgrade

- Refined color system, glow borders, scroll progress indicator
- Staggered reveals, premium typography on landing page

### v1.2.0 — Research & Documentation

- ydotool integration, Issue #3587 documentation
- Clipboard portal analysis, modular installer scripts

### v1.0.0 — Initial Release

- XWayland bridge approach, Flatpak installer
- GitHub Pages landing page, core documentation

---

## Uninstall

### Flatpak Installation

```bash
./install.sh --uninstall
# Removes: extension, override, autostart, shortcuts, env config
# Keeps: CopyQ Flatpak app (remove separately with: flatpak uninstall com.github.hluk.copyq)
```

### Rootless Installation

```bash
systemctl --user disable --now copyq 2>/dev/null
rm -rf ~/Applications/copyq ~/.local/lib/copyq-runtime
rm -f ~/.local/bin/copyq ~/.local/share/applications/copyq.desktop
rm -f ~/.config/systemd/user/copyq.service
rm -rf ~/.config/copyq
```

---

## GitHub Pages

This repo includes a GitHub Pages landing page at [`index.html`](index.html) with interactive architecture diagrams, feature showcases, and installation instructions.

**Live site:** https://marktantongco.github.io/copyq-linux-fix/

---

## Known Issues & Limitations

- **[Issue #3587](https://github.com/hluk/CopyQ/issues/3587):** Closing CopyQ's main window may stop clipboard monitoring under XWayland. Workaround: minimize instead of close, or use `copyq --start`.
- **[Issue #3539](https://github.com/hluk/CopyQ/issues/3539):** Flatpak installations require manual GNOME extension installation to the host filesystem.
- **PRIMARY selection:** The XWayland bridge may not reliably forward X11 PRIMARY selection (middle-click). Use the PPA/native path if you need this.
- **`copy()` scripting command:** Fails on Wayland because keyboard simulation (Ctrl+C) is blocked by the compositor. Use CopyQ's built-in Wayland Support command instead.
- **GNOME Shell extension fragility:** The extension depends on GNOME's internal Meta.Selection API, which can change between major GNOME releases.

---

## References

- [CopyQ](https://github.com/hluk/CopyQ) — Lukas Holecek (upstream)
- [CopyQ Known Issues](https://copyq.readthedocs.io/en/latest/known-issues.html) — Official documentation (confirms Flatpak extension limitation)
- [CopyQ Flathub](https://flathub.org/en/apps/com.github.hluk.copyq) — Flatpak v16.0.0
- [CopyQ PPA](https://launchpad.net/~hluk/+archive/ubuntu/copyq) — System package (v13.0.0, may lack extension support)
- [Clipboard Indicator](https://extensions.gnome.org/extension/779/clipboard-indicator) — 2M+ downloads, simplest GNOME clipboard manager
- [GNOME Clipboard History](https://extensions.gnome.org/extension/4839/clipboard-history) — Modern rewrite by SUPERCILEX
- [Wayland Protocol](https://wayland.freedesktop.org/) — Official Wayland specification
- [Ubuntu 26.04 Release Notes](https://documentation.ubuntu.com/release-notes/26.04/)

---

## License

Installer scripts and documentation are [MIT](LICENSE). CopyQ itself is GPLv3 — see [hluk/CopyQ](https://github.com/hluk/CopyQ).
