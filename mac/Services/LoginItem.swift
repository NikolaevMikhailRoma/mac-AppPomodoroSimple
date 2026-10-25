import AppKit
import Observation
import ServiceManagement

/// Open at login. The state is not kept here but read from the system every
/// time: the user can switch the app off in System Settings, and the checkbox
/// has to show that.
@MainActor
@Observable
final class LoginItem {
    private(set) var isEnabled = false
    /// Login at startup is switched off in System Settings → Login Items. The
    /// system will not let the app switch it back on; only that panel can.
    private(set) var isBlockedBySystem = false

    @ObservationIgnored private var activationObserver: NSObjectProtocol?

    init() {
        refresh()
        // Coming back from System Settings activates us again.
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        isBlockedBySystem = status == .requiresApproval
    }

    func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // The checkbox itself shows why: after refresh() it stands where the
            // system put it, and a hint appears when the system blocks it.
        }
        refresh()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
