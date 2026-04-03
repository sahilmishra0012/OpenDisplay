<p align="center">
  <img src="AppIcon.iconset/icon_256x256.png" width="128" alt="OpenDisplay"/>
</p>

<h1 align="center">OpenDisplay</h1>

<p align="center">
  <strong>Open-source macOS display manager. Free alternative to BetterDisplay.</strong>
</p>

<p align="center">
  <a href="https://github.com/sahilmishra0012/OpenDisplay/releases/latest"><img src="https://img.shields.io/github/v/release/sahilmishra0012/OpenDisplay?style=flat-square" alt="Release"></a>
  <a href="https://github.com/sahilmishra0012/OpenDisplay/blob/main/LICENSE"><img src="https://img.shields.io/github/license/sahilmishra0012/OpenDisplay?style=flat-square" alt="License"></a>
  <a href="https://github.com/sahilmishra0012/OpenDisplay/stargazers"><img src="https://img.shields.io/github/stars/sahilmishra0012/OpenDisplay?style=flat-square" alt="Stars"></a>
  <img src="https://img.shields.io/badge/macOS%2014+-blue?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/Apple%20Silicon-native-green?style=flat-square" alt="Apple Silicon">
</p>

---

## Install

**Homebrew**
```bash
brew tap sahilmishra0012/opendisplay
brew install --cask opendisplay
```

**Direct Download** — grab the [latest release](https://github.com/sahilmishra0012/OpenDisplay/releases/latest)

**Build from source**
```bash
git clone https://github.com/sahilmishra0012/OpenDisplay.git
cd OpenDisplay && swift run
```

---

## Features

**Display Control** — DDC/CI brightness, contrast, volume, sharpness, input switching, power control, resolution & refresh rate switching, display arrangement with mirroring, EDID info, soft disconnect

**Dimming & Color** — gamma dimming, overlay dimming (to black), color temperature / night shift with schedule, XDR/HDR brightness unlock (up to 1600 nits)

**Window Tiling** — edge snapping, left/right/corners/maximize, grid layouts (2×2, 3×2), auto-tile all windows

**Automation** — full CLI, URL scheme (`opendisplay://brightness/80`), display profiles with auto-apply on connect, global hotkeys, settings export/import

**System** — menu bar brightness readout, ambient light sensor sync, multi-display brightness sync, prevent sleep, launch at login, smooth animated transitions with haptic feedback

---

## CLI

```bash
opendisplay --list                          # List displays
opendisplay --display 0 --brightness 70     # Set brightness
opendisplay --display 0 --input hdmi1       # Switch input
opendisplay --display 0 --resolution 2560x1440
opendisplay --help                          # All commands
```

## URL Scheme

```
opendisplay://brightness/80?display=0
opendisplay://input/hdmi1
opendisplay://tile/left
opendisplay://profile/MyProfile
```

Works with Raycast, Shortcuts, Alfred.

---

## Known Limitations

- **HDMI on Apple Silicon** — built-in HDMI doesn't support DDC. Use USB-C/Thunderbolt for full control. Gamma dimming available as fallback.
- **DDC compatibility** — depends on monitor firmware. Some monitors only support certain features.
- **Window tiling** — requires Accessibility permission (System Settings → Privacy & Security → Accessibility).

## Contributing

PRs welcome! See open issues for ideas.

## License

MIT
