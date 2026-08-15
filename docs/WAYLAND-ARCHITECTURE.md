# Wayland Clipboard Architecture: A Deep Technical Dive

> Why clipboard managers are broken on GNOME Wayland, how the XWayland bridge works,
> and what this means for Ubuntu 26.04 LTS.

---

## Table of Contents

1. [X11 Clipboard Model](#1-x11-clipboard-model)
2. [Wayland Clipboard Model](#2-wayland-clipboard-model)
3. [Why GNOME Mutter Does NOT Implement wl-data-control](#3-why-gnome-mutter-does-not-implement-wl-data-control)
4. [XWayland Bridge Architecture](#4-xwayland-bridge-architecture)
5. [Clipboard Flow Diagram](#5-clipboard-flow-diagram)
6. [Compositor Comparison Matrix](#6-compositor-comparison-matrix)
7. [Why This Matters for Ubuntu 26.04 LTS](#7-why-this-matters-for-ubuntu-2604-lts)
8. [The GNOME Extension Dead End for Flatpak](#8-the-gnome-extension-dead-end-for-flatpak)
9. [XDG Desktop Portal Clipboard vs wl-data-control](#9-xdg-desktop-portal-clipboard-vs-wl-data-control)
10. [The QT_QPA_PLATFORM=xcb Trade-off](#10-the-qt_qpa_platformxcb-trade-off)
11. [CopyQ v17 and Future Native Wayland](#11-copyq-v17-and-future-native-wayland)
12. [Future Outlook](#12-future-outlook)
13. [References](#13-references)

---

## 1. X11 Clipboard Model

### Selection-Based Architecture

The X11 clipboard system, introduced in 1984 with the X Window System, is built on a **selection-based model**. Unlike a centralized clipboard daemon, X11 treats the clipboard as a distributed property of the X server itself. There is no single "clipboard owner" — instead, the X server mediates ownership through an **ownership model**.

### CLIPBOARD vs PRIMARY vs SECONDARY

X11 defines three separate selection atoms:

| Selection | Trigger | Typical Use | Persistent? |
|---|---|---|---|
| **PRIMARY** | Mouse highlight (no click) | Quick paste with middle-click | Lost when selection changes |
| **CLIPBOARD** | Explicit Ctrl+C / Edit > Copy | Traditional clipboard operations | Persists until overwritten |
| **SECONDARY** | Rarely used | Application-specific (e.g., Excel fill) | Varies by app |

### How X11 Clipboard Transfer Works

```
1. App A copies text -> calls XSetSelectionOwner(CLIPBOARD, my_window)
2. X server records: "my_window owns CLIPBOARD"
3. App B pastes -> calls XConvertSelection(CLIPBOARD, "UTF8_STRING")
4. X server sends SelectionRequest event to App A's window
5. App A responds with SelectionNotify + actual data via XChangeProperty
6. App B reads the property from the X server -> paste complete
```

**Key point:** The data is transferred **on-demand** (lazy conversion). The clipboard owner doesn't push data — the paste requester pulls it. This is why clipboard data is lost when the owning app exits.

### Any Application Can Monitor

This is the critical difference from Wayland. On X11:

- **Any** client can call `XSetSelectionOwner()` to observe or intercept clipboard changes
- **Any** client can call `XConvertSelection()` to read clipboard contents
- There is **no permission model** — no compositor gatekeeping, no focus requirement
- A clipboard manager registers itself as an intermediary and simply never surrenders ownership

This design made clipboard managers trivially easy to implement (CopyQ, GPaste, Parcellite, etc.) but also enabled:

- Keyloggers reading clipboard content silently
- Spyware capturing passwords copied from password managers
- Any background process monitoring all copy/paste activity

---

## 2. Wayland Clipboard Model

### Compositor-Gated Access

Wayland was designed from the ground up with a fundamentally different security model. The Wayland protocol specification places the **compositor** as the sole authority over all input, output, and inter-client communication:

- **Clients never talk directly to each other** — all communication goes through the compositor
- **Clients never see each other's windows or surfaces** — no window IDs, no cross-app queries
- **Input events are only sent to the focused surface** — no global input grab
- **Clipboard content is only accessible by the focused client and the compositor**

### Per-Surface Clipboard Ownership

In Wayland, clipboard ownership is tied to the **seat** and the **surface** that last offered data:

```
1. App A (focused) copies -> sends wl_data_device.set_selection(offer, serial)
2. Compositor records: "App A's seat owns the selection"
3. App B (now focused) pastes -> sends wl_data_device.receive(mime_type, fd)
4. Compositor forwards the receive request to App A
5. App A writes the data to the provided file descriptor
6. App B reads from the fd -> paste complete
```

**Critical difference from X11:** Only the **focused** surface can request clipboard content. A background clipboard manager has no protocol-level mechanism to receive clipboard change notifications or request clipboard content.

### Privacy-by-Design

The Wayland clipboard model implements several privacy protections:

1. **No passive monitoring**: An unfocused app cannot listen for clipboard changes
2. **No silent reading**: An app must explicitly request data and the compositor can audit/log this
3. **Per-session isolation**: Each Wayland session has its own clipboard — no cross-session leakage
4. **Data offer model**: The compositor acts as a proxy, forwarding MIME type offers without exposing the data itself until a receive request

### The wl-data-control Protocol

The `wl-data-control` protocol (unstable, `zwp_data_control_manager_v1`) was proposed to allow clipboard managers to function on Wayland. It provides:

- `zwp_data_control_device_v1.data_device` — access to the selection without focus
- `zwp_data_control_device_v1.selection` — notification of selection changes

This protocol is what KDE's KWin, wlroots-based compositors (Sway, Hyprland), and others implement. **GNOME's mutter deliberately does not.**

---

## 3. Why GNOME Mutter Does NOT Implement wl-data-control

### The Privacy Decision

GNOME's design philosophy prioritizes user privacy and security. The `wl-data-control` protocol, while useful for clipboard managers, creates a mechanism that can be exploited:

> Any application with access to the `wl-data-control` protocol can silently monitor all clipboard activity, defeating the privacy protections that Wayland was designed to provide.

### Primary Source: GitHub Issue hluk/CopyQ#2811

This is documented extensively in the CopyQ issue tracker:

- **Issue**: [hluk/CopyQ#2811 — Clipboard doesn't work on Wayland (GNOME)](https://github.com/hluk/CopyQ/issues/2811)
- The CopyQ maintainer (hluk) and GNOME developers have discussed this at length
- GNOME's position: implementing `wl-data-control` would be a privacy regression
- CopyQ's position: without `wl-data-control`, clipboard managers are fundamentally broken on GNOME

### GNOME's Stated Position

From the GNOME/mutter side, the arguments against `wl-data-control` include:

1. **It undermines Wayland's security model** — the protocol essentially re-creates the X11 "any app can read clipboard" problem
2. **No granular permissions** — `wl-data-control` is all-or-nothing; there's no way to grant clipboard read access to only "trusted" managers
3. **Alternative approaches exist** — GNOME Shell extensions, D-Bus APIs, and the XWayland bridge are "sufficient" workarounds
4. **The XDG Desktop Portal** provides a more controlled mechanism via the `Clipboard` portal, though it requires user confirmation dialogs

### Why This Matters

This is not a bug — it is a **deliberate architectural decision**. It means:

- No amount of CopyQ configuration will make native Wayland clipboard monitoring work on GNOME
- The only workaround on GNOME is to use the XWayland bridge (which may not capture all events)
- Users who need native clipboard management on Wayland must use KDE, Sway, Hyprland, or other compositors that implement `wl-data-control`

---

## 4. XWayland Bridge Architecture

### What Is XWayland?

XWayland is a compatibility layer built into most Wayland compositors (including GNOME's mutter) that runs an X11 server alongside the Wayland compositor. It allows X11 applications to run unmodified on Wayland by:

1. Translating X11 protocol requests into Wayland protocol requests
2. Providing an X11 display (`:0` or similar) that X11 apps connect to
3. Bridging input events, clipboard data, and window management

### How Mutter Bridges Clipboard Content

The clipboard bridge is the key mechanism that makes CopyQ work on GNOME Wayland:

```
┌─────────────────────────────────────────────────────────────┐
│                    GNOME mutter compositor                   │
│                                                             │
│  ┌──────────────────────┐    ┌──────────────────────────┐  │
│  │  Wayland Clipboard   │    │   XWayland X11 Server   │  │
│  │     State Machine    │◄──►│   Clipboard Bridge       │  │
│  │                      │    │                          │  │
│  │  - wl_data_source    │    │  - CLIPBOARD selection  │  │
│  │  - wl_data_offer     │    │  - PRIMARY selection    │  │
│  │  - seat tracking     │    │  - SelectionNotify      │  │
│  └──────────────────────┘    └──────────────────────────┘  │
│           ▲                              ▲                  │
│           │                              │                  │
│    Wayland apps                   X11 / XWayland apps       │
└─────────────────────────────────────────────────────────────┘
```

### Bridge Behavior Details

When a **native Wayland app** copies data:

1. The app calls `wl_data_device.set_selection()` on the Wayland protocol
2. Mutter's Wayland clipboard state machine records the new selection
3. Mutter's XWayland bridge detects the selection change
4. The bridge creates a corresponding X11 selection owner in the XWayland server
5. X11 apps (including CopyQ running in XWayland) see the new CLIPBOARD selection

When an **XWayland app** copies data:

1. The app calls `XSetSelectionOwner(CLIPBOARD)` on the XWayland X server
2. The XWayland bridge detects the ownership change
3. The bridge creates a `wl_data_source` and calls `wl_data_device.set_selection()` on the Wayland side
4. Native Wayland apps can then paste the data

### Known Limitations

The bridge is **not bi-directionally perfect**:

- **CLIPBOARD selection**: Generally well-bridged in both directions
- **PRIMARY selection**: May not be bridged consistently (middle-click behavior varies)
- **MIME type translation**: Complex MIME types (e.g., `image/png` with multiple representations) may lose fidelity
- **Large data**: The bridge uses temporary files internally; very large clipboard content may fail or timeout
- **Timing**: There can be a brief window where a clipboard change is visible on one side but not yet bridged to the other
- **Security**: GNOME has discussed adding confirmation dialogs for XWayland clipboard access, which would break CopyQ

---

## 5. Clipboard Flow Diagram

### Native Wayland App → CopyQ via XWayland Bridge

```mermaid
sequenceDiagram
    participant User
    participant WaylandApp as Native Wayland App<br/>(Firefox, GNOME Terminal)
    participant Mutter as GNOME mutter<br/>(Wayland Compositor)
    participant XWayland as XWayland Bridge<br/>(X11 Compatibility)
    participant CopyQ as CopyQ 16.0.0<br/>(Flatpak, XWayland mode)

    User->>WaylandApp: Selects text, presses Ctrl+C
    WaylandApp->>Mutter: wl_data_device.set_selection(offer)
    Note over Mutter: Records new clipboard owner<br/>(Wayland side)

    Mutter->>XWayland: Bridge: translate selection to X11
    Note over XWayland: XSetSelectionOwner(CLIPBOARD)<br/>on XWayland X server

    XWayland->>CopyQ: SelectionClear + SelectionNotify events
    Note over CopyQ: CopyQ detects clipboard change<br/>via X11 protocol

    CopyQ->>XWayland: XConvertSelection(CLIPBOARD, UTF8_STRING)
    XWayland->>Mutter: Bridge: forward request to Wayland owner
    Mutter->>WaylandApp: wl_data_offer.receive(UTF8_STRING, fd)
    WaylandApp->>Mutter: Writes data to fd
    Mutter->>XWayland: Bridge: forward data to X11 side
    XWayland->>CopyQ: SelectionNotify with data
    Note over CopyQ: Clipboard item stored in history

    User->>CopyQ: Presses Ctrl+Alt+V (GNOME shortcut)
    CopyQ->>User: Shows clipboard history menu
```

### Why Some Events Are Missed

```mermaid
flowchart TD
    A[App copies data] --> B{App type?}
    B -->|Native Wayland| C[wl_data_device.set_selection]
    B -->|XWayland app| D[XSetSelectionOwner on XWayland]
    B -->|Snap/Flatpak sandboxed| E{Portal permission?}

    C --> F[Mutter records selection]
    F --> G{Bridge active?}
    G -->|Yes| H[XWayland X11 clipboard updated]
    G -->|No / Delay| I[CopyQ misses event ❌]
    H --> J[CopyQ captures via X11 ✅]

    D --> J

    E -->|Granted| F
    E -->|Denied| K[Clipboard not shared ❌]

    style I fill:#f66,color:white
    style K fill:#f66,color:white
    style J fill:#6c6,color:white
```

---

## 6. Compositor Comparison Matrix

### wl-data-control Support

| Compositor | Based On | wl-data-control v1 | Clipboard Manager Support | Notes |
|---|---|---|---|---|
| **GNOME (mutter)** | Clutter/Mutter | **No** ❌ | XWayland bridge only | Privacy-by-design decision |
| **KDE Plasma (kwin)** | Qt/KWayland | **Yes** ✅ | Full native support | Implemented since KDE 5.20+ |
| **Sway** | wlroots | **Yes** ✅ | Full native support | Works with wl-clipboard, Clipman |
| **Hyprland** | Custom (wlroots-like) | **Yes** ✅ | Full native support | Works with wl-clipboard |
| **wlroots (generic)** | — | **Yes** ✅ | Full native support | Available to all wlroots compositors |
| **COSMIC (System76)** | Smithay | **Planned** | TBA | Under active development |
| **Miri** | Mir | **Partial** | Limited | Uses different API surface |

### GNOME vs KDE vs Sway vs Hyprland — Detailed Comparison

| Feature | GNOME (mutter) | KDE Plasma (kwin) | Sway | Hyprland |
|---|---|---|---|---|
| **Wayland support** | Production (default) | Production (default) | Production (default) | Production (default) |
| **XWayland** | Yes, built-in | Yes, built-in | Yes, built-in | Yes, built-in |
| **wl-data-control** | No (by design) | Yes | Yes | Yes |
| **Native clipboard manager** | No | Yes (Klipper built-in) | Yes (wl-clipboard + manager) | Yes (wl-clipboard + manager) |
| **XWayland clipboard bridge** | Yes | Yes | Yes | Yes |
| **CopyQ compatibility** | Partial (XWayland) | Full (native) | Full (native) | Full (native) |
| **Privacy model** | Strict (no passive monitoring) | Moderate (clipboard manager can read) | Moderate | Moderate |
| **Default on Ubuntu** | **Yes (26.04 LTS)** | No | No | No |
| **Custom shortcuts for 3rd-party** | Via GNOME Settings / gsettings | Via KDE System Settings | Via sway config | Via hyprland config |

### Why CopyQ Works Differently on Each

```mermaid
graph LR
    subgraph GNOME Wayland
        A1[Wayland App] -->|set_selection| B1[mutter]
        B1 -->|bridge| C1[XWayland]
        C1 -->|X11 selection| D1[CopyQ via XWayland]
        style B1 fill:#f96,color:white
    end

    subgraph KDE / Sway / Hyprland
        A2[Wayland App] -->|set_selection| B2[Compositor]
        B2 -->|wl-data-control| D2[CopyQ via Native Wayland]
        style B2 fill:#6c6,color:white
    end

    style D1 fill:#fc0,color:black
    style D2 fill:#6c6,color:white
```

On GNOME, CopyQ must take the indirect path through the XWayland bridge. On KDE, Sway, and Hyprland, CopyQ can use `wl-data-control` directly for native, reliable clipboard monitoring.

---

## 7. Why This Matters for Ubuntu 26.04 LTS

### First Wayland-Only LTS

Ubuntu 26.04 LTS ("Resolute Raccoon") is a **watershed release**:

- **No Xorg session option on the login screen** — Wayland is the only graphical session
- Previous LTS releases (20.04, 22.04, 24.04) all offered Xorg as a fallback
- Users who relied on Xorg for clipboard managers, global hotkeys, or screen recording can no longer switch back

### GNOME 50

Ubuntu 26.04 ships with **GNOME 50**, which continues the mutter policy of not implementing `wl-data-control`. The GNOME Shell team has shown no indication of changing this stance for GNOME 50 or the foreseeable future.

### Impact on Users

| User Scenario | Impact |
|---|---|
| Using CopyQ on Xorg (previous LTS) | Worked perfectly — X11 clipboard model allows monitoring |
| Using CopyQ on Ubuntu 26.04 LTS | Only works via XWayland bridge — some events may be missed |
| Using Klipper (KDE) on Xorg | Worked perfectly |
| Using Klipper on KDE Wayland | Still works perfectly (KDE implements wl-data-control) |
| Using xdotool on Ubuntu 26.04 LTS | Does not work at all — X11 input injection blocked on Wayland |

### No Going Back

Unlike previous LTS releases where users could select "Ubuntu on Xorg" from the login screen:

- Ubuntu 26.04 **removes the Xorg session entirely**
- The Xorg packages (`xserver-xorg`, `xserver-xorg-core`) may still be installable but are not configured or supported
- Even if you install Xorg packages manually, GNOME 50's session configuration does not include an Xorg variant

This means the XWayland bridge workaround described in this repo is not just a convenience — it's the **only viable approach** for running CopyQ on Ubuntu 26.04 LTS.

### Enterprise Impact

For organizations deploying Ubuntu 26.04 LTS at scale:

- **Clipboard managers are a common productivity tool** — many enterprise users depend on multi-item clipboard history
- **The XWayland bridge approach is a workaround, not a fix** — it may have edge cases that don't appear in testing
- **GNOME's stance may change in future releases**, but there's no timeline or commitment
- **The Flatpak approach** (CopyQ 16.0.0 from Flathub) provides the most portable and maintainable solution

---

## 8. The GNOME Extension Dead End for Flatpak

### CopyQ's Own GNOME Shell Extension

CopyQ ships a GNOME Shell extension called **"CopyQ Clipboard Monitor"** that provides native clipboard monitoring on GNOME Wayland — without needing XWayland or `wl-data-control`. The extension works by listening to GNOME Shell's internal `Meta.Display` clipboard-changed signal and forwarding clipboard content to CopyQ via D-Bus.

This is the same mechanism used by other GNOME-compatible clipboard managers (Clipman, GPaste, Clyp), as documented in [COMPATIBILITY-MATRIX.md](COMPATIBILITY-MATRIX.md) section 2.

### Why It Cannot Work in Flatpak

The critical limitation, documented on the [CopyQ known-issues page](https://copyq.readthedocs.io/en/latest/known-issues.html):

> It will not work when running CopyQ as a Flatpak or AppImage because the extension **cannot be registered with the GNOME Shell from a sandboxed environment**.

GNOME Shell extensions must be installed into `~/.local/share/gnome-shell/extensions/` or `/usr/share/gnome-shell/extensions/` — directories that are **outside** the Flatpak sandbox. Even if the extension files were bundled inside the Flatpak, the extension registration process requires:

1. **Filesystem access** to the GNOME Shell extensions directory (blocked by sandbox)
2. **GNOME Shell restart** or `gnome-extensions enable` command (requires host access)
3. **D-Bus communication** with `org.gnome.Shell.Extensions` (blocked by sandbox)

### Impact on Our Approach

This means the XWayland bridge is the **only viable approach** for running CopyQ as a Flatpak on GNOME Wayland. There is no alternative path — not the GNOME Shell extension, not the clipboard portal (see Section 9), and not native Wayland (see Section 10).

| Installation Method | GNOME Extension | XWayland Bridge | Native Wayland |
|---|---|---|---|
| **Flatpak** | ❌ Cannot register | ✅ Our approach | ❌ No wl-data-control on GNOME |
| **PPA / deb** | ✅ Can install extension | ✅ Fallback | ❌ No wl-data-control on GNOME |
| **AppImage** | ❌ Cannot register | ✅ Possible | ❌ No wl-data-control on GNOME |

### For PPA/deb Users

If you installed CopyQ via PPA (v13.0.0) or a native `.deb` package, the GNOME Shell extension **can** work as an alternative to XWayland:

```bash
# Install the CopyQ GNOME Shell extension
# (Extension files are typically in /usr/share/copyq/extensions/)
cp /usr/share/copyq/extensions/gnome-shell/copyq@hluk.com/* \
    ~/.local/share/gnome-shell/extensions/copyq@hluk.com/

# Enable via GNOME Extensions app or CLI
gnome-extensions enable copyq@hluk.com
```

However, GNOME Shell extensions are fragile — they can break on every GNOME update due to internal API changes.

---

## 9. XDG Desktop Portal Clipboard vs wl-data-control

### The Clipboard Portal (xdg-desktop-portal 1.18+)

The XDG Desktop Portal **Clipboard portal** was added in version 1.18 (September 2023) as an extension of the **Remote Desktop portal**. Its primary design goal:

> Enable clipboard sharing between a local desktop session and a **remote desktop session**.

This is fundamentally different from `wl-data-control`, which is designed for **local clipboard managers**.

### Architecture Comparison

```
wl-data-control (for clipboard managers):
    Clipboard Manager App ←→ Compositor ←→ Focused App
    (Direct protocol, no user confirmation, background monitoring)

XDG Clipboard Portal (for remote desktop):
    Remote Desktop Client ←→ Portal Service ←→ Compositor ←→ Local App
    (Requires user confirmation, request-response model, not for monitoring)
```

### Why the Clipboard Portal Doesn't Help CopyQ

| Aspect | wl-data-control | XDG Clipboard Portal |
|---|---|---|
| **Design purpose** | Local clipboard management | Remote desktop clipboard sharing |
| **Monitoring model** | Passive, continuous | Request-response, per-action |
| **User confirmation** | Not required | Required (dialog popup) |
| **Background operation** | Yes (daemon) | No (interactive) |
| **GNOME implementation** | ❌ Not implemented | ⚠️ Partial (via mutter internals) |
| **Flatpak override** | N/A | `--permission=clipboard=yes` |

### The Flatpak `--permission=clipboard=yes` Misconception

Some guides suggest using `flatpak override --permission=clipboard=yes` to grant CopyQ clipboard access on Wayland. This flag attempts to use the XDG Clipboard Portal, but:

1. **The portal is for remote desktop, not clipboard managers** — it expects a remote desktop session to be active
2. **It requires user confirmation for every clipboard access** — impractical for continuous monitoring
3. **It cannot provide passive clipboard change notifications** — the portal only responds to explicit requests

### GitLab GNOME MR#53: Clipboard Control in Portal

GNOME has [Merge Request #53 on xdg-desktop-portal-gnome](https://gitlab.gnome.org/GNOME/xdg-desktop-portal-gnome/-/merge_requests/53) that adds clipboard control capabilities. This work leverages mutter's internal clipboard methods, but:

- It's focused on **remote desktop use cases**, not clipboard managers
- It would still require **user interaction** per clipboard access
- There's no indication this will evolve into a `wl-data-control` replacement for managers

### Bottom Line

The XDG Desktop Portal Clipboard is **not a path forward** for clipboard managers on GNOME. It solves a different problem. For CopyQ on GNOME Wayland, the options remain:

1. **XWayland bridge** (our approach) — works now, with documented limitations
2. **GNOME Shell extension** — works but not in Flatpak, fragile across GNOME versions
3. **wl-data-control in GNOME** — would be the ideal solution, but GNOME has explicitly declined

---

## 10. The QT_QPA_PLATFORM=xcb Trade-off

### Why We Set This Variable

Setting `QT_QPA_PLATFORM=xcb` forces CopyQ (a Qt6 application) to use the X11/XCB backend instead of the native Wayland backend. This is essential for clipboard monitoring on GNOME Wayland because:

- CopyQ running on native Wayland cannot access the clipboard (GNOME has no `wl-data-control`)
- CopyQ running via XWayland's X11 bridge *can* access the clipboard through the X11 selection mechanism

The CopyQ documentation itself confirms: [copyq.readthedocs.io](https://copyq.readthedocs.io/)

> Setting `QT_QPA_PLATFORM=xcb` is the recommended workaround for clipboard monitoring on GNOME Wayland.


### Issue #3587: When XWayland Mode Breaks

CopyQ issue [#3587](https://github.com/hluk/CopyQ/issues/3587) documents a critical edge case:

> Setting `QT_QPA_PLATFORM=xcb` **can actually break clipboard monitoring** in some XWayland implementations.

The CopyQ official docs warn:

> It can cause clipboard monitoring to fail when the main window is closed, X11 connection errors, and other issues **depending on the XWayland implementation**.

### What Happens (Root Cause)

When CopyQ runs with `QT_QPA_PLATFORM=xcb`, it connects to the XWayland X server via the XCB library. The X11 connection has specific lifecycle behavior:

```
CopyQ Main Window OPEN:
    CopyQ → XCB → XWayland X Server → Mutter Bridge → Wayland Clipboard ✅
    (X11 connection active, SelectionNotify events flowing)

CopyQ Main Window CLOSED (not just minimized):
    CopyQ → XCB → XWayland X Server → [Connection may drop] ❌
    (Qt may close the X11 display connection when last window is destroyed)
    (Clipboard monitoring stops because SelectionNotify events are no longer received)

CopyQ RUNNING with window MINIMIZED:
    CopyQ → XCB → XWayland X Server → Mutter Bridge → Wayland Clipboard ✅
    (X11 connection persists because window still exists)
```

The issue is that Qt's XCB platform plugin may tear down the X11 display connection when the **last top-level window is closed** — even if CopyQ's clipboard monitor thread is still running and needs that connection.

### When This Occurs

| Condition | Clipboard Monitoring Works? |
|---|---|
| CopyQ main window visible | ✅ Yes |
| CopyQ minimized to tray | ✅ Yes (window still exists) |
| CopyQ window closed via window manager close button | ❌ May stop (X11 connection drops) |
| CopyQ running with `copyq --start` (no window) | ⚠️ Depends on Qt version |
| CopyQ restarted after close | ✅ Yes (fresh connection) |

### Mitigation Strategies

**1. Keep CopyQ minimized, not closed:**

Use the tray icon or GNOME shortcut (`Ctrl+Alt+V`) to hide the window instead of closing it. The window still exists; it's just not visible.

**2. Use a restart wrapper script:**

```bash
#!/bin/bash
# ~/.local/bin/copyq-watchdog.sh
# Monitors CopyQ clipboard capture and restarts if stale

LAST_ITEM=""
while true; do
    CURRENT=$(copyq read 0 2>/dev/null)
    if [ "$CURRENT" != "$LAST_ITEM" ] && [ -n "$CURRENT" ]; then
        LAST_ITEM="$CURRENT"
    fi
    
    # If no clipboard update for 60 seconds, restart
    if [ -z "$CURRENT" ]; then
        copyq exit 2>/dev/null
        sleep 1
        flatpak run com.github.hluk.copyq &
    fi
    
    sleep 60
done
```

**3. Set CopyQ to run with tray icon only (no initial window):**

```bash
flatpak run com.github.hluk.copyq --start-managed  # Or configure in Preferences > History
```

### See Also

- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) Section 8 for full diagnosis and resolution steps
- CopyQ ReadTheDocs [known-issues page](https://copyq.readthedocs.io/en/latest/known-issues.html)

---

## 11. CopyQ v17 and Future Native Wayland

### Current State: Native Wayland Works on Some Compositors

CopyQ **already supports native Wayland** clipboard monitoring — but only on compositors that implement `wl-data-control` or the related `wlr-data-control-unstable-v1` protocol. From the CopyQ documentation:

> CopyQ supports both X11 and Wayland display servers, though Wayland requires running with the `QT_QPA_PLATFORM=xcb` environment variable for **full clipboard** support on some desktop environments.

| Desktop Environment | Native Wayland Clipboard | Protocol Used | Status |
|---|---|---|---|
| **KDE Plasma** | ✅ Full support | `wl-data-control` | Works without XWayland |
| **Sway** | ✅ Full support | `wlr-data-control-unstable-v1` | Works without XWayland |
| **Hyprland** | ✅ Full support | `wlr-data-control-unstable-v1` | Works without XWayland |
| **wlroots-based (any)** | ✅ Full support | `wlr-data-control-unstable-v1` | Works without XWayland |
| **GNOME (mutter)** | ❌ No support | N/A | **Blocked** — mutter doesn't implement wl-data-control |

On KDE, Sway, and Hyprland, you can run CopyQ with `QT_QPA_PLATFORM=wayland` and it will monitor the clipboard natively. The XWayland workaround is **only needed for GNOME**.

### Wine's March 2025 wl_data_device Merge

A significant development in the broader Wayland clipboard ecosystem: **Wine merged native `wl_data_device` support in March 2025**. This means:

- Wine applications can now use the Wayland clipboard protocol directly (without XWayland)
- The merge demonstrates that the Wayland clipboard protocols are maturing and gaining adoption
- It puts additional pressure on GNOME to reconsider `wl-data-control` implementation

This is relevant to CopyQ because it shows momentum toward native Wayland clipboard support across the ecosystem.

### Three Possible Paths Forward for GNOME

| Path | Likelihood | Timeline | Impact |
|---|---|---|---|
| **(a) GNOME implements wl-data-control** | Low (near-term), Medium (long-term) | 2027+? | CopyQ native Wayland on GNOME — ideal solution |
| **(b) CopyQ finds portal-based approach** | Medium | 2026+ | Could use XDG portal with some UX compromises |
| **(c) XWayland bridge continues** | ✅ Current state | Indefinite | Works now but with documented limitations |

### Path (a): GNOME Implements wl-data-control

GNOME has discussed `wl-data-control v2` with a permission model (see Section 12: Future Outlook). Key indicators to watch:

- **GNOME mutter merge requests** on [GitLab](https://gitlab.gnome.org/GNOME/mutter) — search for "data-control" or "clipboard"
- **GNOME design discussions** on [GNOME Discourse](https://discourse.gnome.org/)
- **Wayland protocol standardization** in [wayland-protocols](https://gitlab.freedesktop.org/wayland/wayland-protocols)

If GNOME implements a permission-gated version, CopyQ would need to be updated to request clipboard access through the new API. Users would likely see a one-time "Allow CopyQ to access clipboard?" dialog.

### Path (b): Portal-Based Approach

CopyQ could potentially use the XDG Desktop Portal's clipboard capabilities (see Section 9), but this would require:

1. A change in the portal's design to support **passive monitoring** (currently request-only)
2. GNOME to implement clipboard notifications in the portal backend
3. A UX model that doesn't require per-action confirmation

This would be a significant architectural change to both the portal and CopyQ.

### Path (c): XWayland Bridge (Current)

The XWayland bridge approach works today and will continue to work as long as:

1. GNOME continues to ship XWayland (guaranteed for the foreseeable future — too many X11 apps exist)
2. The XWayland clipboard bridge remains functional (see Issue #3587, Section 10)
3. CopyQ continues to support the Qt XCB backend

This is the approach documented in this repository and remains the recommended solution for Ubuntu 26.04 LTS.

### How to Test for Future Native Wayland

```bash
# Test CopyQ with native Wayland (no XWayland)
QT_QPA_PLATFORM=wayland copyq

# If this works on GNOME, wl-data-control has been implemented!
# You'll see clipboard items appearing in CopyQ's history.

# Verify which backend CopyQ is using:
copyq --version
# Look for "Using: wayland" or "Using: xcb" in debug output
```

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) Section 11 for a complete monitoring guide.

---

## 12. Future Outlook

### wl-data-control v2

The Wayland community has discussed a v2 of the data control protocol with improvements:

- **Permission model**: Granular per-app clipboard access control (not just all-or-nothing)
- **Auditing**: Clipboard access logging and notification to the user
- **Scope limitation**: Read-only monitoring vs. write access as separate permissions

However, this is still in the **discussion/proposal phase** and has not been formally standardized. Even if adopted, GNOME would need to choose to implement it.

### GNOME Discussion Threads

Key discussion threads to follow:

- **GNOME mutter merge requests**: [GitLab GNOME/mutter](https://gitlab.gnome.org/GNOME/mutter) — search for "data-control" or "clipboard"
- **CopyQ issue tracker**: [hluk/CopyQ#2811](https://github.com/hluk/CopyQ/issues/2811) — ongoing tracking of Wayland support
- **GNOME design discussions**: [GNOME Discourse](https://discourse.gnome.org/) — search for "clipboard manager wayland"
- **Ubuntu Discourse**: [Ubuntu 26.04 Roadmap](https://discourse.ubuntu.com/t/ubuntu-26-04-lts-the-roadmap/72740)
- **Wayland protocols repo**: [wayland-protocols](https://gitlab.freedesktop.org/wayland/wayland-protocols) — protocol standardization

### Potential Future Scenarios

| Scenario | Likelihood | Impact on CopyQ |
|---|---|---|
| GNOME implements wl-data-control v2 with permissions | Low (near-term), Medium (long-term) | Native Wayland clipboard monitoring would work |
| XDG Desktop Portal Clipboard gains wide adoption | Medium | CopyQ could use the portal API (with user confirmation) |
| GNOME adds XWayland clipboard access restrictions | Medium | Current workaround may break, requiring new approach |
| Ubuntu adds a custom GNOME patch for clipboard | Very Low | Would be an Ubuntu-specific divergence from upstream GNOME |
| CopyQ implements a GNOME Shell extension for clipboard | Medium | Could bypass the protocol limitation entirely |

### The XDG Desktop Portal Approach

An alternative to `wl-data-control` is the **XDG Desktop Portal Clipboard portal**, which provides:

- User-confirmed clipboard access (a dialog appears asking for permission)
- Controlled by the compositor's portal implementation
- Already available on GNOME via `xdg-desktop-portal-gnome`

The downside: every clipboard access would require a user confirmation, which is impractical for a clipboard manager that needs to capture every copy event silently.

---

## 13. References

### Primary Sources

- [hluk/CopyQ#2811 — Clipboard doesn't work on Wayland (GNOME)](https://github.com/hluk/CopyQ/issues/2811)
- [Wayland Protocol Specification](https://wayland.freedesktop.org/)
- [wl-data-control protocol (unstable)](https://gitlab.freedesktop.org/wayland/wayland-protocols/-/blob/main/unstable/data-control/data-control-unstable-v1.xml)
- [GNOME mutter source](https://gitlab.gnome.org/GNOME/mutter)

### Ubuntu-Specific

- [Ubuntu 26.04 Release Notes](https://documentation.ubuntu.com/release-notes/26.04/)
- [Ubuntu 26.04 Roadmap](https://discourse.ubuntu.com/t/ubuntu-26-04-lts-the-roadmap/72740)
- [CopyQ PPA (v13.0.0)](https://launchpad.net/~hluk/+archive/ubuntu/copyq)
- [CopyQ Flathub (v16.0.0)](https://flathub.org/en/apps/com.github.hluk.copyq)

### Community Discussions

- [GNOME Discourse — Clipboard on Wayland](https://discourse.gnome.org/)
- [Reddit r/gnome — Wayland clipboard](https://www.reddit.com/r/gnome/)
- [Arch Wiki — Wayland](https://wiki.archlinux.org/title/Wayland)

---

*Last updated: 2025 · Applies to Ubuntu 26.04 LTS, GNOME 50, CopyQ 16.0.0 (Flatpak)*
