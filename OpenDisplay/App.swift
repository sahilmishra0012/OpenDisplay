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
    /// Stores last values for undo
    static var undoStack: [(command: DDCCommand, value: UInt16, displayID: CGDirectDisplayID)] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // CLI mode
        if CLIHandler.handleArguments(CommandLine.arguments) {
            NSApp.terminate(nil); return
        }

        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "display", accessibilityDescription: "OpenDisplay")
            button.action = #selector(togglePopover)
        }
        popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 600)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MainView())

        setupHotkeys()
        startBrightnessReadout()

        // Track active app changes
        appObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier,
                  app.bundleIdentifier != "com.apple.dt.Xcode",
                  !app.bundleIdentifier!.contains("swift") else { return }
            AppDelegate.lastActiveApp = app
        }
        AppDelegate.lastActiveApp = NSWorkspace.shared.runningApplications
            .first { $0.isActive && $0.activationPolicy == .regular }

        // Register URL scheme handler
        NSAppleEventManager.shared().setEventHandler(
            self, andSelector: #selector(handleURL(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc func handleURL(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else { return }
        URLSchemeHandler.handle(url: url)
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else { popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY); NSApp.activate(ignoringOtherApps: true) }
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
        guard let ext = mgr.displays.first(where: { !$0.isBuiltIn }) else {
            statusItem?.button?.title = ""
            return
        }
        if let b = DDCControl.read(command: .brightness, for: ext.id) {
            statusItem?.button?.title = " \(b.current)%"
        }
    }

    // MARK: - Undo

    static func pushUndo(command: DDCCommand, value: UInt16, displayID: CGDirectDisplayID) {
        undoStack.append((command, value, displayID))
        if undoStack.count > 20 { undoStack.removeFirst() }
    }

    @objc func undoLastChange() {
        guard let last = AppDelegate.undoStack.popLast() else { return }
        DDCControl.write(command: last.command, value: last.value, for: last.displayID)
        updateBrightnessReadout()
    }

    private func setupHotkeys() {
        HotkeyManager.shared.onAction = { action in
            let mgr = DisplayManager()
            guard let ext = mgr.displays.first(where: { !$0.isBuiltIn }) else { return }
            switch action {
            case .brightnessUp:
                if let v = DDCControl.read(command: .brightness, for: ext.id) {
                    DDCControl.write(command: .brightness, value: UInt16(min(v.max, v.current + v.max / 20)), for: ext.id)
                }
            case .brightnessDown:
                if let v = DDCControl.read(command: .brightness, for: ext.id) {
                    DDCControl.write(command: .brightness, value: UInt16(max(0, v.current - v.max / 20)), for: ext.id)
                }
            case .volumeUp:
                if let v = DDCControl.read(command: .volume, for: ext.id) {
                    DDCControl.write(command: .volume, value: UInt16(min(v.max, v.current + 5)), for: ext.id)
                }
            case .volumeDown:
                if let v = DDCControl.read(command: .volume, for: ext.id) {
                    DDCControl.write(command: .volume, value: UInt16(max(0, v.current - 5)), for: ext.id)
                }
            case .volumeMute:
                DDCControl.write(command: .mute, value: 1, for: ext.id)
            case .contrastUp:
                if let v = DDCControl.read(command: .contrast, for: ext.id) {
                    DDCControl.write(command: .contrast, value: UInt16(min(v.max, v.current + 5)), for: ext.id)
                }
            case .contrastDown:
                if let v = DDCControl.read(command: .contrast, for: ext.id) {
                    DDCControl.write(command: .contrast, value: UInt16(max(0, v.current - 5)), for: ext.id)
                }
            case .nextInput:
                if let v = DDCControl.read(command: .inputSource, for: ext.id) {
                    DDCControl.write(command: .inputSource, value: UInt16(v.current + 1), for: ext.id)
                }
            case .toggleNightShift: break // handled by NightShiftScheduler
            }
        }
    }
}
