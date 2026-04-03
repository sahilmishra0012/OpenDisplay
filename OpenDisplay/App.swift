import SwiftUI

@main
struct OpenDisplayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    static var lastActiveApp: NSRunningApplication?
    private var appObserver: Any?
    private var brightnessTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CLIHandler.handleArguments(CommandLine.arguments) {
            NSApp.terminate(nil); return
        }

        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "display", accessibilityDescription: "OpenDisplay")
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 600)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MainView())

        setupHotkeys()
        startBrightnessReadout()

        // Track active app
        appObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.activationPolicy == .regular,
                  !Self.isOurApp(app) else { return }
            AppDelegate.lastActiveApp = app
        }
        // Initialize: find the most recent non-self regular app
        AppDelegate.lastActiveApp = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !Self.isOurApp($0) }
            .first

        // URL scheme
        NSAppleEventManager.shared().setEventHandler(
            self, andSelector: #selector(handleURL(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    /// Check if a running app is OpenDisplay (works for .app bundle and swift run)
    private static func isOurApp(_ app: NSRunningApplication) -> Bool {
        let bid = app.bundleIdentifier ?? ""
        if bid == "com.opendisplay.app" { return true }
        if bid == Bundle.main.bundleIdentifier { return true }
        if app.executableURL?.lastPathComponent == "OpenDisplay" { return true }
        // When running via swift run
        if bid.contains("com.apple.dt") || app.executableURL?.path.contains("swift") == true { return true }
        return false
    }

    // MARK: - Click handling: left = popover, right = quick menu

    @objc func handleClick() {
        guard let event = NSApp.currentEvent, let button = statusItem.button else { return }
        if event.type == .rightMouseUp {
            showQuickMenu()
        } else {
            if popover.isShown { popover.performClose(nil) }
            else { popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY); NSApp.activate(ignoringOtherApps: true) }
        }
    }

    // MARK: - Right-click quick presets menu

    private func showQuickMenu() {
        let menu = NSMenu()

        // Quick brightness presets
        menu.addItem(NSMenuItem(title: "Brightness", action: nil, keyEquivalent: ""))
        for pct in [100, 75, 50, 25, 0] {
            let item = NSMenuItem(title: "  \(pct)%", action: #selector(quickBrightness(_:)), keyEquivalent: "")
            item.tag = pct
            item.target = self
            menu.addItem(item)
        }

        menu.addItem(.separator())

        // Saved profiles
        let profiles = ProfileManager.shared.profiles
        if !profiles.isEmpty {
            menu.addItem(NSMenuItem(title: "Profiles", action: nil, keyEquivalent: ""))
            for profile in profiles {
                let item = NSMenuItem(title: "  \(profile.name)", action: #selector(applyProfile(_:)), keyEquivalent: "")
                item.representedObject = profile.name
                item.target = self
                menu.addItem(item)
            }
            menu.addItem(.separator())
        }

        // Sync toggle
        let syncItem = NSMenuItem(title: "Sync All Displays", action: #selector(syncAllBrightness), keyEquivalent: "")
        syncItem.target = self
        menu.addItem(syncItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // Reset so left-click works again
    }

    @objc func quickBrightness(_ sender: NSMenuItem) {
        let value = UInt16(sender.tag)
        let mgr = DisplayManager()
        for d in mgr.displays where !d.isBuiltIn {
            SmoothTransition.setBrightness(value, for: d.id)
        }
        updateBrightnessReadout()
    }

    @objc func applyProfile(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String,
              let profile = ProfileManager.shared.profiles.first(where: { $0.name == name }) else { return }
        let mgr = DisplayManager()
        for d in mgr.displays where !d.isBuiltIn {
            if let b = profile.brightness { SmoothTransition.setBrightness(UInt16(b), for: d.id) }
            if let c = profile.contrast { SmoothTransition.setContrast(UInt16(c), for: d.id) }
            if let v = profile.volume { SmoothTransition.setVolume(UInt16(v), for: d.id) }
        }
    }

    @objc func syncAllBrightness() {
        let mgr = DisplayManager()
        let externals = mgr.displays.filter { !$0.isBuiltIn }
        guard let first = externals.first,
              let b = DDCControl.read(command: .brightness, for: first.id) else { return }
        for d in externals.dropFirst() {
            SmoothTransition.setBrightness(UInt16(b.current), for: d.id)
        }
    }

    // MARK: - Menu bar brightness readout

    private func startBrightnessReadout() {
        updateBrightnessReadout()
        brightnessTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.updateBrightnessReadout()
        }
    }

    private func updateBrightnessReadout() {
        let mgr = DisplayManager()
        guard let ext = mgr.displays.first(where: { !$0.isBuiltIn }),
              let b = DDCControl.read(command: .brightness, for: ext.id) else {
            statusItem?.button?.title = ""
            return
        }
        DispatchQueue.main.async { self.statusItem?.button?.title = " \(b.current)%" }
    }

    // MARK: - URL scheme

    @objc func handleURL(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else { return }
        URLSchemeHandler.handle(url: url)
    }

    // MARK: - Hotkeys

    private func setupHotkeys() {
        HotkeyManager.shared.onAction = { action in
            let mgr = DisplayManager()
            guard let ext = mgr.displays.first(where: { !$0.isBuiltIn }) else { return }
            switch action {
            case .brightnessUp:
                if let v = DDCControl.read(command: .brightness, for: ext.id) {
                    SmoothTransition.setBrightness(UInt16(min(v.max, v.current + v.max / 20)), for: ext.id)
                }
            case .brightnessDown:
                if let v = DDCControl.read(command: .brightness, for: ext.id) {
                    SmoothTransition.setBrightness(UInt16(max(0, v.current - v.max / 20)), for: ext.id)
                }
            case .volumeUp:
                if let v = DDCControl.read(command: .volume, for: ext.id) {
                    DDCControl.write(command: .volume, value: UInt16(min(v.max, v.current + 5)), for: ext.id)
                }
            case .volumeDown:
                if let v = DDCControl.read(command: .volume, for: ext.id) {
                    DDCControl.write(command: .volume, value: UInt16(max(0, v.current - 5)), for: ext.id)
                }
            case .volumeMute: DDCControl.write(command: .mute, value: 1, for: ext.id)
            case .contrastUp:
                if let v = DDCControl.read(command: .contrast, for: ext.id) {
                    SmoothTransition.setContrast(UInt16(min(v.max, v.current + 5)), for: ext.id)
                }
            case .contrastDown:
                if let v = DDCControl.read(command: .contrast, for: ext.id) {
                    SmoothTransition.setContrast(UInt16(max(0, v.current - 5)), for: ext.id)
                }
            case .nextInput:
                if let v = DDCControl.read(command: .inputSource, for: ext.id) {
                    DDCControl.write(command: .inputSource, value: UInt16(v.current + 1), for: ext.id)
                }
            case .toggleNightShift: break
            }
        }
    }
}
