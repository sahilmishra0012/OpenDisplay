import SwiftUI

struct MainView: View {
    @StateObject private var manager = DisplayManager()
    @StateObject private var profiles = ProfileManager.shared
    @State private var selectedTab = 0
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("OpenDisplay").font(.headline)
                Spacer()
                Button(action: { manager.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(manager.displays.isEmpty ? 0 : 360))
                }.buttonStyle(.borderless)
                Button(action: { NSApp.terminate(nil) }) {
                    Image(systemName: "xmark.circle")
                }.buttonStyle(.borderless)
            }.padding(.horizontal).padding(.top, 12).padding(.bottom, 6)

            // Tabs
            HStack(spacing: 2) {
                ForEach(Array([
                    ("display", "Displays"),
                    ("rectangle.on.rectangle", "Arrange"),
                    ("moon.fill", "Night Shift"),
                    ("rectangle.split.2x1", "Windows"),
                    ("square.stack", "Profiles"),
                    ("gearshape", "Settings")
                ].enumerated()), id: \.offset) { i, item in
                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedTab = i } }) {
                        VStack(spacing: 2) {
                            Image(systemName: item.0).font(.system(size: 13))
                            Text(item.1).font(.system(size: 8))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(selectedTab == i ? Color.accentColor.opacity(0.2) : Color.clear)
                        .foregroundColor(selectedTab == i ? .accentColor : .secondary)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)

            Divider().padding(.top, 6)

            ScrollView {
                Group {
                    switch selectedTab {
                    case 0: DisplaysTab(manager: manager)
                    case 1: ArrangeTab(manager: manager)
                    case 2: NightShiftTab(manager: manager)
                    case 3: WindowTilingTab()
                    case 4: ProfilesTab(manager: manager)
                    case 5: SettingsTab(manager: manager)
                    default: EmptyView()
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .id(selectedTab) // force transition on tab change
            }
            .animation(.easeInOut(duration: 0.25), value: selectedTab)
        }
        .frame(width: 400, height: 600)
        .scaleEffect(appeared ? 1 : 0.95)
        .opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.spring(duration: 0.3)) { appeared = true } }
    }
}

// MARK: - Displays Tab

struct DisplaysTab: View {
    @ObservedObject var manager: DisplayManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(manager.displays.enumerated()), id: \.element.id) { index, display in
                DisplayCard(display: display, manager: manager)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .animation(.spring(duration: 0.4).delay(Double(index) * 0.08), value: manager.displays.count)
            }
        }.padding()
    }
}

// MARK: - Arrange Tab

struct ArrangeTab: View {
    @ObservedObject var manager: DisplayManager
    var body: some View {
        DisplayArrangementView(manager: manager).padding()
    }
}

struct DisplayCard: View {
    let display: DisplayInfo
    @ObservedObject var manager: DisplayManager

    @State private var brightness: Double = 50
    @State private var contrast: Double = 50
    @State private var volume: Double = 50
    @State private var sharpness: Double = 50
    @State private var selectedMode: DisplayMode?
    @State private var ddcAvailable = false
    @State private var softDim: Double = 1.0
    @State private var overlayDim: Double = 0.0
    @State private var colorTemp: Double = 6500
    @State private var showAdvanced = false
    @State private var showInfo = false
    @State private var selectedInput: DDCInputSource = .hdmi1
    @State private var hdrNits: Double = 500
    @State private var isDisconnected = false
    @StateObject private var hdrManager = HDRBrightnessManager()

    private let gammaDimmer = GammaDimmer()
    private let overlayDimmer = OverlayDimmer()
    private let softDisconnect = DisplaySoftDisconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: display.isBuiltIn ? "laptopcomputer" : "display")
                Text(display.name).font(.subheadline.bold())
                Spacer()
                Button(action: { showInfo.toggle() }) {
                    Image(systemName: "info.circle")
                }.buttonStyle(.borderless)
                Button(action: { showAdvanced.toggle() }) {
                    Image(systemName: "slider.horizontal.3")
                }.buttonStyle(.borderless)
            }

            // Display info
            if showInfo {
                DisplayInfoPanel(display: display)
            }

            // Resolution picker
            let modes = manager.parsedModes(for: display)
            if !modes.isEmpty {
                Picker("Resolution", selection: $selectedMode) {
                    ForEach(modes) { m in Text(m.label).tag(Optional(m)) }
                }
                .onChange(of: selectedMode) { _, m in if let m { manager.setMode(m, for: display.id) } }
            }

            // Refresh rate
            let rates = manager.refreshRates(for: display)
            if rates.count > 1 {
                HStack {
                    Text("Refresh Rate").font(.caption)
                    Spacer()
                    ForEach(rates, id: \.self) { rate in
                        Button("\(Int(rate))Hz") {
                            if let mode = modes.first(where: { $0.refreshRate == rate && $0.width == (selectedMode?.width ?? 0) }) {
                                manager.setMode(mode, for: display.id)
                            }
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                    }
                }
            }

            // DDC controls
            if !display.isBuiltIn {
                if ddcAvailable {
                    DDCSlider(icon: "sun.max", label: "Brightness", value: $brightness, command: .brightness, displayID: display.id)
                    DDCSlider(icon: "circle.lefthalf.filled", label: "Contrast", value: $contrast, command: .contrast, displayID: display.id)
                    DDCSlider(icon: "speaker.wave.2", label: "Volume", value: $volume, command: .volume, displayID: display.id)

                    // Input switching
                    HStack {
                        Text("Input").font(.caption)
                        Picker("", selection: $selectedInput) {
                            ForEach(DDCInputSource.allCases) { src in Text(src.label).tag(src) }
                        }.onChange(of: selectedInput) { _, src in
                            DDCControl.write(command: .inputSource, value: src.rawValue, for: display.id)
                        }
                    }

                    // Power
                    HStack {
                        Text("Power").font(.caption); Spacer()
                        ForEach(DDCPowerMode.allCases) { mode in
                            Button(mode.label) {
                                DDCControl.write(command: .powerMode, value: mode.rawValue, for: display.id)
                            }.buttonStyle(.bordered).controlSize(.small)
                        }
                    }
                } else {
                    Text("DDC not available (HDMI port doesn't support DDC on Apple Silicon)")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Use software dimming below, or connect via USB-C/Thunderbolt for DDC.")
                        .font(.caption2).foregroundStyle(.secondary)
                    // Show software brightness as fallback
                    HStack {
                        Image(systemName: "sun.max")
                        Text("Brightness").font(.caption).frame(width: 70, alignment: .leading)
                        Slider(value: $softDim, in: 0...1, step: 0.01)
                            .onChange(of: softDim) { _, v in gammaDimmer.setDimming(factor: v, for: display.id) }
                        Text("\(Int(softDim * 100))%").frame(width: 36).font(.caption)
                    }
                }
            }

            // Software dimming (all displays)
            if showAdvanced {
                Divider()
                Text("Software Controls").font(.caption.bold())

                HStack {
                    Image(systemName: "moon")
                    Text("Gamma Dim").font(.caption).frame(width: 70, alignment: .leading)
                    Slider(value: $softDim, in: 0...1, step: 0.01)
                        .onChange(of: softDim) { _, v in gammaDimmer.setDimming(factor: v, for: display.id) }
                    Text("\(Int(softDim * 100))%").frame(width: 36).font(.caption)
                }

                HStack {
                    Image(systemName: "square.filled.on.square")
                    Text("Overlay Dim").font(.caption).frame(width: 70, alignment: .leading)
                    Slider(value: $overlayDim, in: 0...1, step: 0.01)
                        .onChange(of: overlayDim) { _, v in overlayDimmer.setDimming(opacity: v, for: display.id) }
                    Text("\(Int(overlayDim * 100))%").frame(width: 36).font(.caption)
                }

                HStack {
                    Image(systemName: "thermometer.medium")
                    Text("Color Temp").font(.caption).frame(width: 70, alignment: .leading)
                    Slider(value: $colorTemp, in: 1000...10000, step: 100)
                        .onChange(of: colorTemp) { _, v in gammaDimmer.setColorTemperature(Int(v), brightness: softDim, for: display.id) }
                    Text("\(Int(colorTemp))K").frame(width: 46).font(.caption)
                }

                if ddcAvailable {
                    DDCSlider(icon: "diamond", label: "Sharpness", value: $sharpness, command: .sharpness, displayID: display.id)
                }

                Button("Reset Gamma") { gammaDimmer.resetGamma(for: display.id); softDim = 1.0; colorTemp = 6500 }
                    .controlSize(.small)

                // HDR/XDR brightness
                if hdrManager.isHDRCapable {
                    Divider()
                    Text("XDR/HDR Brightness").font(.caption.bold())
                    HStack {
                        Image(systemName: "sun.max.trianglebadge.exclamationmark")
                        Slider(value: $hdrNits, in: 100...hdrManager.maxNits, step: 10)
                            .onChange(of: hdrNits) { _, v in hdrManager.setHDRBrightness(nits: v, for: display.id) }
                        Text("\(Int(hdrNits)) nits").frame(width: 60).font(.caption)
                    }
                    Button("Reset to SDR") { hdrManager.resetToSDR(for: display.id); hdrNits = 500 }
                        .controlSize(.small)
                }
            }

            // Soft disconnect
            if !display.isBuiltIn {
                Divider()
                Button(isDisconnected ? "Reconnect Display" : "Soft Disconnect") {
                    if isDisconnected { softDisconnect.reconnect(display.id) }
                    else { softDisconnect.disconnect(display.id) }
                    isDisconnected.toggle()
                }.controlSize(.small)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.5))
        .cornerRadius(10)
        .onAppear { loadDDCValues() }
    }

    private func loadDDCValues() {
        if let current = display.currentMode {
            selectedMode = manager.parsedModes(for: display).first { $0.id == current.ioDisplayModeID }
        }
        hdrManager.checkHDRCapability(for: display.id)
        guard !display.isBuiltIn else { return }
        if let v = DDCControl.read(command: .brightness, for: display.id) {
            brightness = Double(v.current); ddcAvailable = true
            if let c = DDCControl.read(command: .contrast, for: display.id) { contrast = Double(c.current) }
            if let vol = DDCControl.read(command: .volume, for: display.id) { volume = Double(vol.current) }
            if let s = DDCControl.read(command: .sharpness, for: display.id) { sharpness = Double(s.current) }
            if let inp = DDCControl.read(command: .inputSource, for: display.id),
               let src = DDCInputSource(rawValue: UInt16(inp.current)) { selectedInput = src }
        }
    }
}

struct DDCSlider: View {
    let icon: String
    let label: String
    @Binding var value: Double
    let command: DDCCommand
    let displayID: CGDirectDisplayID
    @State private var displayValue: Double = 0

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(value > 0 ? .primary : .secondary)
            Slider(value: $value, in: 0...100, step: 1) { Text(label) }
                .onChange(of: value) { old, new in
                    if abs(new - old) >= 5 {
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                    }
                    SmoothDDC.transition(command: command, from: old, to: new, for: displayID)
                }
            Text("\(Int(value))%")
                .frame(width: 36).font(.caption.monospacedDigit())
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: value)
        }
    }
}

/// Smooth DDC value transitions
enum SmoothDDC {
    private static var timers: [String: Timer] = [:]

    static func transition(command: DDCCommand, from: Double, to: Double, for displayID: CGDirectDisplayID, duration: Double = 0.3) {
        let key = "\(displayID)-\(command.rawValue)"
        timers[key]?.invalidate()

        let diff = abs(to - from)
        // Skip animation for small changes or direct jumps
        if diff <= 3 {
            DDCControl.write(command: command, value: UInt16(to), for: displayID)
            return
        }

        let steps = min(Int(diff), 8)
        let interval = duration / Double(steps)
        var step = 0

        timers[key] = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            step += 1
            let progress = Double(step) / Double(steps)
            // Ease-out curve
            let eased = 1 - pow(1 - progress, 2)
            let current = from + (to - from) * eased
            DDCControl.write(command: command, value: UInt16(current), for: displayID)
            if step >= steps { timer.invalidate(); timers.removeValue(forKey: key) }
        }
    }
}

struct DisplayInfoPanel: View {
    let display: DisplayInfo

    var body: some View {
        let edid = EDIDReader.read(for: display.id)
        VStack(alignment: .leading, spacing: 2) {
            Text("ID: \(display.id)").font(.caption2)
            Text("Vendor: \(display.vendorNumber) / Model: \(display.modelNumber)").font(.caption2)
            if let e = edid {
                Text("EDID: \(e.manufacturerID) — \(e.displayName ?? "N/A")").font(.caption2)
                Text("Year: \(e.yearOfManufacture) — Size: \(e.maxHorizontalSize)×\(e.maxVerticalSize) cm").font(.caption2)
            }
            Text("Rotation: \(Int(display.rotation))°").font(.caption2)
            if let m = display.currentMode {
                Text("Native: \(m.pixelWidth)×\(m.pixelHeight) px").font(.caption2)
            }
            if let profile = ColorProfileManager.currentProfile(for: display.id) {
                Text("Color: \(profile)").font(.caption2)
            }
        }
        .padding(6).background(.ultraThinMaterial).cornerRadius(6)
    }
}

// MARK: - Night Shift Tab

struct NightShiftTab: View {
    @ObservedObject var manager: DisplayManager
    @StateObject private var scheduler = NightShiftScheduler()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Enable Night Shift", isOn: Binding(
                get: { scheduler.enabled },
                set: { newVal in
                    if newVal { scheduler.start(displays: manager.displays.map(\.id)) }
                    else { scheduler.stop() }
                }
            ))

            HStack {
                Text("Start").frame(width: 40)
                Picker("", selection: $scheduler.startHour) {
                    ForEach(0..<24, id: \.self) { h in Text("\(h):00").tag(h) }
                }
            }
            HStack {
                Text("End").frame(width: 40)
                Picker("", selection: $scheduler.endHour) {
                    ForEach(0..<24, id: \.self) { h in Text("\(h):00").tag(h) }
                }
            }
            HStack {
                Text("Warmth")
                Slider(value: .init(get: { Double(scheduler.warmthKelvin) },
                                    set: { scheduler.warmthKelvin = Int($0) }),
                       in: 1800...5000, step: 100)
                Text("\(scheduler.warmthKelvin)K").frame(width: 50)
            }
        }.padding()
    }
}

// MARK: - Profiles Tab

struct ProfilesTab: View {
    @ObservedObject var manager: DisplayManager
    @StateObject private var profiles = ProfileManager.shared
    @State private var newProfileName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Profile name", text: $newProfileName)
                Button("Save Current") {
                    guard !newProfileName.isEmpty, let d = manager.displays.first else { return }
                    let mode = d.currentMode
                    let profile = ProfileManager.DisplayProfile(
                        name: newProfileName,
                        brightness: DDCControl.read(command: .brightness, for: d.id).map { Double($0.current) },
                        contrast: DDCControl.read(command: .contrast, for: d.id).map { Double($0.current) },
                        volume: DDCControl.read(command: .volume, for: d.id).map { Double($0.current) },
                        resolutionModeID: mode?.ioDisplayModeID
                    )
                    profiles.saveProfile(profile)
                    newProfileName = ""
                }.disabled(newProfileName.isEmpty)
            }

            Divider()

            ForEach(profiles.profiles) { profile in
                HStack {
                    VStack(alignment: .leading) {
                        Text(profile.name).font(.subheadline.bold())
                        Text([
                            profile.brightness.map { "Br: \(Int($0))" },
                            profile.contrast.map { "Ct: \(Int($0))" },
                            profile.volume.map { "Vol: \(Int($0))" }
                        ].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Apply") { applyProfile(profile) }.controlSize(.small)
                    Button(role: .destructive) { profiles.deleteProfile(named: profile.name) } label: {
                        Image(systemName: "trash")
                    }.controlSize(.small)
                }
            }

            if profiles.profiles.isEmpty {
                Text("No saved profiles").font(.caption).foregroundStyle(.secondary)
            }
        }.padding()
    }

    private func applyProfile(_ profile: ProfileManager.DisplayProfile) {
        guard let d = manager.displays.first else { return }
        if let b = profile.brightness { DDCControl.write(command: .brightness, value: UInt16(b), for: d.id) }
        if let c = profile.contrast { DDCControl.write(command: .contrast, value: UInt16(c), for: d.id) }
        if let v = profile.volume { DDCControl.write(command: .volume, value: UInt16(v), for: d.id) }
        if let modeID = profile.resolutionModeID,
           let mode = manager.parsedModes(for: d).first(where: { $0.id == modeID }) {
            manager.setMode(mode, for: d.id)
        }
    }
}

// MARK: - Window Tiling Tab

struct WindowTilingTab: View {
    @State private var edgeSnapping = false
    private let tiler = WindowTiler.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Window Tiling").font(.subheadline.bold())
            Text("Drag windows to screen edges to snap, or use the grid buttons below.")
                .font(.caption).foregroundStyle(.secondary)

            Toggle("Edge Snapping", isOn: $edgeSnapping)
                .onChange(of: edgeSnapping) { _, on in
                    if on { tiler.startEdgeSnapping() } else { tiler.stopEdgeSnapping() }
                }

            Divider()
            Text("Quick Layouts").font(.caption.bold())

            HStack(spacing: 8) {
                TileButton(icon: "rectangle.lefthalf.filled", label: "Left") { tileFront(.left) }
                TileButton(icon: "rectangle.righthalf.filled", label: "Right") { tileFront(.right) }
                TileButton(icon: "arrow.up.left.and.arrow.down.right", label: "Max") { tileFront(.maximize) }
                TileButton(icon: "rectangle.center.inset.filled", label: "Center") { tileFront(.center) }
            }

            HStack(spacing: 8) {
                TileButton(icon: "rectangle.inset.topleft.filled", label: "Top L") { tileFront(.topLeft) }
                TileButton(icon: "rectangle.inset.topright.filled", label: "Top R") { tileFront(.topRight) }
                TileButton(icon: "rectangle.inset.bottomleft.filled", label: "Bot L") { tileFront(.bottomLeft) }
                TileButton(icon: "rectangle.inset.bottomright.filled", label: "Bot R") { tileFront(.bottomRight) }
            }

            HStack(spacing: 8) {
                TileButton(icon: "rectangle.split.1x2.fill", label: "Top") { tileFront(.top) }
                TileButton(icon: "rectangle.split.1x2.fill", label: "Bottom") { tileFront(.bottom) }
                TileButton(icon: "square.grid.2x2", label: "Quarters") { tileGrid(cols: 2, rows: 2) }
            }

            Divider()
            Text("Grid Tile All Windows").font(.caption.bold())

            HStack(spacing: 8) {
                TileButton(icon: "rectangle.split.2x1", label: "2 cols") { tileGrid(cols: 2, rows: 1) }
                TileButton(icon: "rectangle.split.3x1", label: "3 cols") { tileGrid(cols: 3, rows: 1) }
                TileButton(icon: "square.grid.2x2", label: "2×2") { tileGrid(cols: 2, rows: 2) }
                TileButton(icon: "square.grid.3x2", label: "3×2") { tileGrid(cols: 3, rows: 2) }
            }

            Button("Auto-tile all visible windows") {
                tileAllVisible()
            }.controlSize(.small)

            Divider()
            Text("Requires Accessibility permission: System Settings → Privacy & Security → Accessibility")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding()
    }

    /// Find the best target app for tiling (not OpenDisplay)
    private func targetApp() -> NSRunningApplication? {
        if let app = AppDelegate.lastActiveApp, app.isTerminated == false { return app }
        // Fallback: find first regular app with windows that isn't us
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != "com.opendisplay.app" }
            .first { app in
                let ref = AXUIElementCreateApplication(app.processIdentifier)
                var wins: CFTypeRef?
                return AXUIElementCopyAttributeValue(ref, kAXWindowsAttribute as CFString, &wins) == .success
                    && (wins as? [AXUIElement])?.isEmpty == false
            }
    }

    private func tileFront(_ position: WindowTiler.TilePosition) {
        guard let screen = NSScreen.main?.visibleFrame, let app = targetApp() else { return }
        let frame = position.frame(in: screen)

        let appRef = AXUIElementCreateApplication(app.processIdentifier)
        var windowRef: CFTypeRef?

        if AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &windowRef) != .success {
            var windowsRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                  let windows = windowsRef as? [AXUIElement], let first = windows.first else { return }
            windowRef = first
        }

        let win = windowRef as! AXUIElement
        var pos = CGPoint(x: frame.origin.x, y: NSScreen.screens[0].frame.height - frame.maxY)
        var size = CGSize(width: frame.width, height: frame.height)
        if let pv = AXValueCreate(.cgPoint, &pos) { AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, pv) }
        if let sv = AXValueCreate(.cgSize, &size) { AXUIElementSetAttributeValue(win, kAXSizeAttribute as CFString, sv) }
    }

    private func tileGrid(cols: Int, rows: Int) {
        guard let app = targetApp() else { return }

        let appRef = AXUIElementCreateApplication(app.processIdentifier)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement], let screen = NSScreen.main?.visibleFrame else { return }

        let grid = WindowTiler.GridLayout(columns: cols, rows: rows)
        let frames = grid.frames(in: screen, count: windows.count)
        for (i, win) in windows.enumerated() where i < frames.count {
            // Stagger animations for a cascade effect
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                animateWindow(win, to: frames[i])
            }
        }
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }

    private func tileAllVisible() {
        guard let screen = NSScreen.main?.visibleFrame else { return }
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        var allWindows: [AXUIElement] = []
        for app in apps {
            let appRef = AXUIElementCreateApplication(app.processIdentifier)
            var winsRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &winsRef) == .success,
               let wins = winsRef as? [AXUIElement] { allWindows.append(contentsOf: wins) }
        }
        guard !allWindows.isEmpty else { return }
        let cols = Int(ceil(sqrt(Double(allWindows.count))))
        let rows = Int(ceil(Double(allWindows.count) / Double(cols)))
        let grid = WindowTiler.GridLayout(columns: cols, rows: rows)
        let frames = grid.frames(in: screen, count: allWindows.count)
        for (i, win) in allWindows.enumerated() where i < frames.count {
            var pos = CGPoint(x: frames[i].origin.x, y: NSScreen.screens[0].frame.height - frames[i].maxY)
            var size = CGSize(width: frames[i].width, height: frames[i].height)
            if let pv = AXValueCreate(.cgPoint, &pos) { AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, pv) }
            if let sv = AXValueCreate(.cgSize, &size) { AXUIElementSetAttributeValue(win, kAXSizeAttribute as CFString, sv) }
        }
    }

    /// Animate a window to a target frame in steps
    private func animateWindow(_ window: AXUIElement, to frame: NSRect, steps: Int = 6, duration: Double = 0.15) {
        // Read current position/size
        var curPos = CGPoint.zero
        var curSize = CGSize.zero
        if var posRef: CFTypeRef? = nil,
           AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success {
            AXValueGetValue(posRef as! AXValue, .cgPoint, &curPos)
        }
        if var sizeRef: CFTypeRef? = nil,
           AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success {
            AXValueGetValue(sizeRef as! AXValue, .cgSize, &curSize)
        }

        let targetPos = CGPoint(x: frame.origin.x, y: NSScreen.screens[0].frame.height - frame.maxY)
        let targetSize = CGSize(width: frame.width, height: frame.height)

        let interval = duration / Double(steps)
        for step in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(step)) {
                let t = Double(step) / Double(steps)
                let ease = 1 - pow(1 - t, 3) // ease-out cubic

                var pos = CGPoint(
                    x: curPos.x + (targetPos.x - curPos.x) * ease,
                    y: curPos.y + (targetPos.y - curPos.y) * ease
                )
                var size = CGSize(
                    width: curSize.width + (targetSize.width - curSize.width) * ease,
                    height: curSize.height + (targetSize.height - curSize.height) * ease
                )
                if let pv = AXValueCreate(.cgPoint, &pos) { AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pv) }
                if let sv = AXValueCreate(.cgSize, &size) { AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sv) }
            }
        }
    }
}

struct TileButton: View {
    let icon: String; let label: String; let action: () -> Void
    var body: some View {
        Button { action() } label: {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.title3)
                Text(label).font(.caption2)
            }.frame(maxWidth: .infinity).padding(.vertical, 6)
        }
        .buttonStyle(.bordered).controlSize(.small)
    }
}

struct GridButton: View {
    let cols: Int; let rows: Int; let label: String
    @State private var pressed = false
    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.15)) { pressed = true }
            WindowTiler.shared.tileWindows(columns: cols, rows: rows)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(duration: 0.15)) { pressed = false }
            }
        } label: { Text(label) }
        .buttonStyle(.bordered).controlSize(.small)
        .scaleEffect(pressed ? 0.9 : 1)
    }
}

// MARK: - Settings Tab

struct SettingsTab: View {
    @ObservedObject var manager: DisplayManager
    @StateObject private var profiles = ProfileManager.shared
    @StateObject private var launchAtLogin = LaunchAtLogin.shared
    @StateObject private var als = AmbientLightSync()
    @StateObject private var eventWatcher = DisplayEventWatcher()
    @State private var preventSleep = false
    @State private var brightnessSync = false
    @State private var exportMessage = ""
    private let sleepPreventer = SleepPreventer()
    private let sync = BrightnessSync()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Launch at Login", isOn: $launchAtLogin.isEnabled)

            Toggle("Prevent Sleep (external displays)", isOn: $preventSleep)
                .onChange(of: preventSleep) { _, on in
                    if on { sleepPreventer.preventSleep() } else { sleepPreventer.allowSleep() }
                }

            Toggle("Sync brightness across displays", isOn: $brightnessSync)
                .onChange(of: brightnessSync) { _, on in
                    let externals = manager.displays.filter { !$0.isBuiltIn }
                    if on, let first = externals.first {
                        sync.start(source: first.id, targets: externals.dropFirst().map(\.id))
                    } else { sync.stop() }
                }

            Divider()
            Text("Ambient Light Sync").font(.subheadline.bold())

            Toggle("Sync brightness to ambient light", isOn: Binding(
                get: { als.enabled },
                set: { on in
                    if on { als.start(displays: manager.displays.filter { !$0.isBuiltIn }.map(\.id)) }
                    else { als.stop() }
                }
            ))

            if als.enabled {
                Text("Sensor: \(Int(als.sensorValue)) lux").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Text("Min").font(.caption)
                    Slider(value: $als.minBrightness, in: 0...50, step: 1)
                    Text("\(Int(als.minBrightness))%").frame(width: 36).font(.caption)
                }
                HStack {
                    Text("Max").font(.caption)
                    Slider(value: $als.maxBrightness, in: 50...100, step: 1)
                    Text("\(Int(als.maxBrightness))%").frame(width: 36).font(.caption)
                }
                HStack {
                    Text("Sensitivity").font(.caption)
                    Slider(value: $als.sensitivity, in: 0.1...3.0, step: 0.1)
                    Text(String(format: "%.1fx", als.sensitivity)).frame(width: 36).font(.caption)
                }
            }

            Divider()
            Text("Auto-Apply Profiles").font(.subheadline.bold())

            Toggle("Auto-apply on display connect", isOn: Binding(
                get: { eventWatcher.autoProfileEnabled },
                set: { on in if on { eventWatcher.start() } else { eventWatcher.stop() } }
            ))

            if eventWatcher.autoProfileEnabled {
                ForEach(manager.displays.filter { !$0.isBuiltIn }) { display in
                    HStack {
                        Text(display.name).font(.caption)
                        Picker("", selection: Binding(
                            get: { eventWatcher.displayProfileMap[display.name] ?? "" },
                            set: { eventWatcher.setAutoProfile(displayName: display.name, profileName: $0) }
                        )) {
                            Text("None").tag("")
                            ForEach(profiles.profiles) { p in Text(p.name).tag(p.name) }
                        }.controlSize(.small)
                    }
                }
            }

            Divider()
            Text("Export / Import").font(.subheadline.bold())
            HStack {
                Button("Export Settings") {
                    if let url = SettingsExporter.exportToFile() {
                        exportMessage = "Saved to \(url.lastPathComponent)"
                    }
                }.controlSize(.small)
                Button("Import Settings") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.json]
                    if panel.runModal() == .OK, let url = panel.url {
                        exportMessage = SettingsExporter.importFromFile(url: url) ? "Imported!" : "Failed"
                    }
                }.controlSize(.small)
                if !exportMessage.isEmpty {
                    Text(exportMessage).font(.caption).foregroundStyle(.secondary)
                }
            }

            Divider()
            Text("URL Scheme").font(.subheadline.bold())
            Text("opendisplay://brightness/80?display=0").font(.caption.monospaced())
            Text("opendisplay://input/hdmi1 · opendisplay://tile/left").font(.caption.monospaced())
            Text("opendisplay://profile/MyProfile").font(.caption.monospaced())

            Divider()
            Text("About").font(.subheadline.bold())
            Text("OpenDisplay — Open Source Display Manager").font(.caption)
            Text("MIT License · github.com/opendisplay").font(.caption).foregroundStyle(.secondary)

            Spacer()
        }.padding()
        .onAppear { eventWatcher.loadMapping() }
    }
}
