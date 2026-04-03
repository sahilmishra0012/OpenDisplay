import ServiceManagement
import Foundation

/// Proper launch-at-login using SMAppService (macOS 13+)
class LaunchAtLogin: ObservableObject {
    static let shared = LaunchAtLogin()

    @Published var isEnabled: Bool {
        didSet { toggle(isEnabled) }
    }

    init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    private func toggle(_ enable: Bool) {
        do {
            if enable { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            // Falls back silently — only works in a proper .app bundle
            isEnabled = SMAppService.mainApp.status == .enabled
        }
    }
}
