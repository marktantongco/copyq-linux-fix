# CopyQ Fix Update for Linux

Rootless installer for [CopyQ](https://github.com/hluk/copyq) on **Ubuntu 24.04 / 26.04 / Debian 12+** — works **without sudo**.

## Why this exists

On a default Ubuntu 26.04 desktop:

1. **No Qt6/KDE6 runtime installed.** CopyQ 13.0.0 depends on the entire Qt 6.10 + KDE Frameworks 6 stack. `apt install copyq` pulls ~63 packages but you need `sudo` — and many minimal/container setups don't have it.
2. **Wayland.** This distro ships a Wayland session. CopyQ is a Qt/xcb app; without a compatibility wrapper it fails to render or integrate with the tray.

This script downloads every needed `.deb`, extracts them into your home directory, and wires up a launcher that forces the Qt **xcb** platform so CopyQ runs cleanly under **XWayland**. No root, no system modifications.

---

## Quick install (copy-ready)

Run these commands one block at a time. Each block is safe to copy-paste whole.

### 1. Download the installer

```bash
cd /tmp
curl -fsSL "https://raw.githubusercontent.com/marktantongco/copyq-linux-fix/main/install-copyq.sh" -o install-copyq.sh
```

### 2. Make it executable

```bash
chmod +x /tmp/install-copyq.sh
```

### 3. Run the installer (no sudo)

```bash
/tmp/install-copyq.sh
```

This takes 1–3 minutes: it downloads ~63 Debian packages, extracts them into your home directory, writes the launcher, desktop entry, and systemd unit, then runs a clipboard round-trip verification.

### 4. Add linger so it starts without login (optional)

```bash
sudo loginctl enable-linger $USER
```

### 5. Start CopyQ now and enable autostart

```bash
systemctl --user daemon-reload
systemctl --user enable --now copyq
```

### 6. Verify it is running

```bash
systemctl --user status copyq
```

Expected: `Active: active (running)`.

### 7. Test the clipboard

```bash
copyq "copy('hello-from-copyq')"
sleep 1
copyq "clipboard()"
```

Expected output: `hello-from-copyq`.

### 8. Find it in the app menu

Press the **Super** (Windows) key, type `CopyQ`, and launch it. The tray icon appears in the system tray.

---

## Install from source

```bash
git clone https://github.com/marktantongco/copyq-linux-fix.git
cd copyq-linux-fix
./install-copyq.sh
```

The script is idempotent — re-running re-downloads and re-extracts cleanly.

---

## Requirements

- Ubuntu 24.04 / 26.04 / Debian 12+ (x86_64 or aarch64)
- `bash`, `curl`, `dpkg`, `apt-get` (all present by default)
- **No sudo needed** — everything lives under `$HOME`
- A running graphical session (X11 or Wayland)

---

## Usage

```bash
copyq                             # focus / open the main window
copyq "copy('hello')"             # write to clipboard
copyq "clipboard()"               # read clipboard
copyq "show('History')"           # open history tab
copyq menu                        # open the tray menu
```

### Service control

```bash
systemctl --user status copyq      # check status
systemctl --user restart copyq     # restart
journalctl --user -u copyq -f      # tail logs
```

---

## Compatibility / Wayland notes

The launcher forces `QT_QPA_PLATFORM=xcb`, so CopyQ runs through **XWayland** rather than native Wayland. This is intentional:

- **Clipboard** works via the X11 clipboard bridge that GNOME/KDE/Wayland compositors already provide.
- **Tray icon** (StatusNotifierItem) renders through XWayland's system-tray bridge.
- Native Qt6 Wayland platform is *not* bundled in this install (it requires additional `qt6-wayland` packages and a Wayland-era tray protocol), and CopyQ 13.0.0's tray integration is historically more stable on xcb.

If you run a pure X11 session, the xcb platform is native and needs no bridge.

### Known warnings (benign)

```
Warning: qt.qpa.services: Failed to register with host portal ...
```

This is the xdg-desktop-portal app-ID registration race under XWayland. It does **not** affect clipboard or tray functionality. It appears once at startup.

---

## File layout

```
~/
├── Applications/copyq/              # extracted app + plugins + usr/bin/copyq
│   └── usr/bin/copyq                # the real binary
├── .local/
│   ├── bin/copyq                    # launcher wrapper
│   ├── lib/copyq-runtime/           # 855 shared libs (Qt6 + KDE6 + Qt5)
│   ├── share/applications/copyq.desktop
│   └── share/icons/hicolor/.../     # 16–128px + scalable icons
├── .config/systemd/user/copyq.service
└── .config/copyq/                   # your CopyQ config + history
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `copyq` command not found | Ensure `~/.local/bin` is on your `PATH` (log out/in once) |
| `Cannot connect to server` | Start the server first: `systemctl --user start copyq` then retry |
| Tray icon missing | Check the compositor's tray (some need `gnome-shell-extension-appindicator`); the clipboard still works headless |
| Blank/transparent window | Runtime libs incomplete — re-run the installer, verify `~/.local/lib/copyq-runtime/` has >100 `.so` files |
| `error while loading shared libraries` | Extractor missed a dep; delete `~/.local/lib/copyq-runtime/` and re-run |

---

## Uninstall

```bash
systemctl --user disable --now copyq 2>/dev/null
rm -rf ~/Applications/copyq ~/.local/lib/copyq-runtime
rm -f ~/.local/bin/copyq ~/.local/share/applications/copyq.desktop
rm -f ~/.config/systemd/user/copyq.service
rm -rf ~/.config/copyq                  # removes history + config
```

---

## How it works (technical)

The script does **not** install any package via `dpkg -i`. Instead it:

1. Runs `apt-get install --simulate copyq` to get the exact dependency list for *this* OS version.
2. Downloads each `.deb` to a temp directory.
3. Extracts with `dpkg-deb -x` (pure extraction, no root, no triggers).
4. Collects all `lib*.so*` into a single `LD_LIBRARY_PATH`-able runtime dir.
5. Stages Qt plugins (`platforms/libqxcb.so`, `xcbglintegrations/`, `styles/`, `platformtheme/`) where the launcher's `QT_PLUGIN_PATH` points.
6. Writes a thin launcher that sets the environment and `exec`s the real binary.

Because nothing touches `/usr` or `/var`, the install is fully contained, requires no privilege escalation, and leaves no trace beyond the directories above.

---

## License

The installer script is [MIT](LICENSE). CopyQ itself is GPLv3 — see [hluk/copyq](https://github.com/hluk/copyq).
