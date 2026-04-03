<p align="center">
  <img src="https://img.icons8.com/sf-regular/96/display.png" width="80" alt="OpenDisplay icon"/>
</p>

<h1 align="center">OpenDisplay</h1>

<p align="center">
  <strong>Open-source macOS display manager. Free alternative to BetterDisplay.</strong>
</p>

<p align="center">
  <a href="https://github.com/sahilmishra0012/OpenDisplay/releases/latest"><img src="https://img.shields.io/github/v/release/sahilmishra0012/OpenDisplay?style=flat-square" alt="Release"></a>
  <a href="https://github.com/sahilmishra0012/OpenDisplay/blob/main/LICENSE"><img src="https://img.shields.io/github/license/sahilmishra0012/OpenDisplay?style=flat-square" alt="License"></a>
  <a href="https://github.com/sahilmishra0012/OpenDisplay/stargazers"><img src="https://img.shields.io/github/stars/sahilmishra0012/OpenDisplay?style=flat-square" alt="Stars"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/Apple%20Silicon-native-green?style=flat-square" alt="Apple Silicon">
</p>

---

## ✨ Features

### 🖥 Display Control
- **DDC/CI** — brightness, contrast, volume, sharpness via hardware (Apple Silicon + Intel)
- **Input switching** — HDMI, DisplayPort, USB-C, VGA, DVI
- **Monitor power** — on, standby, off
- **Resolution switching** — all modes including hidden HiDPI
- **Refresh rate switching** — quick buttons for available rates
- **Display arrangement** — drag-and-drop editor with mirroring
- **EDID reading** — manufacturer, model, serial, year, physical size
- **Soft disconnect** — black out a display without unplugging

### 🌙 Dimming & Color
- **Software gamma dimming** — works on all displays including built-in
- **Overlay dimming** — dim to complete black
- **Color temperature** — night shift with scheduled hours
- **XDR/HDR brightness** — unlock up to 1600 nits on supported displays

### 🪟 Window Tiling
- **Edge snapping** — drag windows to screen edges
- **Quick layouts** — left, right, top, bottom, all four corners, maximize, center
- **Grid tiling** — 2-col, 3-col, 2×2, 3×2 grids
- **Auto-tile** — arrange all visible windows automatically
- **Smooth animations** — ease-out cubic transitions with haptic feedback

### ⚡ Automation
- **CLI** — `opendisplay --brightness 80 --display 1`
- **URL scheme** — `opendisplay://brightness/80?display=0`
- **Profiles** — save/load/auto-apply on display connect
- **Global hotkeys** — brightness, contrast, volume, input switching
- **Settings export/import** — JSON backup

### 🔧 System
- **Menu bar brightness readout** — current % shown in menu bar
- **Undo** — revert last brightness/contrast/volume change
- **Ambient light sync** — auto-adjust to MacBook light sensor
- **Brightness sync** — keep multiple displays matched
- **Prevent sleep** — while external displays connected
- **Launch at login**

## 📦 Install

### Homebrew
```bash
brew tap sahilmishra0012/opendisplay
brew install --cask opendisplay
```

### Direct Download
Download the latest [DMG or ZIP](https://github.com/sahilmishra0012/OpenDisplay/releases/latest) and drag to Applications.

### Build from Source
```bash
git clone https://github.com/sahilmishra0012/OpenDisplay.git
cd OpenDisplay
swift build
swift run
```

## 🖱 CLI Usage

```bash
opendisplay --list                          # List all displays
opendisplay --display 0 --brightness 70     # Set brightness
opendisplay --display 0 --contrast 50       # Set contrast
opendisplay --display 0 --volume 30         # Set volume
opendisplay --display 0 --input hdmi1       # Switch input
opendisplay --display 0 --power off         # Power off
opendisplay --display 0 --resolution 2560x1440  # Set resolution
opendisplay --display 0 --modes             # List available modes
```

## 🔗 URL Scheme

```
opendisplay://brightness/80?display=0
opendisplay://contrast/50
opendisplay://input/hdmi1
opendisplay://volume/30
opendisplay://tile/left
opendisplay://profile/MyProfile
```

Works with Raycast, Shortcuts, Alfred, and any automation tool.

## 🏗 Architecture

```
OpenDisplay/
├── App.swift                  # Menu bar app, CLI routing, hotkeys, brightness readout
├── MainView.swift             # Tabbed UI with animations
├── DisplayManager.swift       # Display enumeration, resolution, mirroring
├── DDCBrightness.swift        # DDC/CI (Apple Silicon IOAVService + Intel I2C)
├── GammaDimmer.swift          # Software dimming & color temperature
├── OverlayDimmer.swift        # Overlay-based dimming
├── HDRBrightness.swift        # XDR/HDR brightness via Metal EDR
├── WindowTiler.swift          # Window tiling with edge snapping
├── DisplayArrangementView.swift # Visual display arrangement editor
├── NightShiftScheduler.swift  # Scheduled color temperature
├── AmbientLightSync.swift     # Ambient light sensor sync
├── BrightnessSync.swift       # Multi-display brightness sync
├── HotkeyManager.swift        # Global keyboard shortcuts
├── EDIDReader.swift           # EDID parsing
├── ColorProfileManager.swift  # Color profile management
├── ProfileManager.swift       # Display profiles & persistence
├── DisplayEventWatcher.swift  # Auto-apply on display connect
├── DisplaySoftDisconnect.swift # Soft disconnect displays
├── CLIHandler.swift           # Command-line interface
├── URLSchemeHandler.swift     # URL scheme for automation
├── NativeOSD.swift            # macOS native OSD
├── SettingsExporter.swift     # Settings export/import
└── SleepPreventer.swift       # Prevent display sleep
```

## ⚠️ Known Limitations

- **HDMI on Apple Silicon** — The built-in HDMI port on M1/M2/M3/M4 Macs doesn't support DDC. Connect via USB-C/Thunderbolt for full DDC control. Software dimming (gamma) is available as a fallback.
- **DDC compatibility** — Some monitors implement DDC/CI poorly. If a feature doesn't work, it's likely the monitor's firmware.
- **Accessibility permission** — Window tiling requires Accessibility access (System Settings → Privacy & Security → Accessibility).

## 🤝 Contributing

PRs welcome! Some ideas:
- [ ] Virtual/dummy display creation
- [ ] Keyboard shortcut configuration UI
- [ ] Localization (Chinese, Japanese, German)
- [ ] LG webOS / Samsung Tizen TV control
- [ ] Picture-in-Picture

## 📄 License

MIT — see [LICENSE](LICENSE)

---

<p align="center">
  <sub>Built with ❤️ in Swift. No Electron. No subscriptions. Just a native macOS app.</sub>
</p>
