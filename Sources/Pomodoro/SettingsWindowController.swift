import AppKit
import SwiftUI
import PomodoroCore

/// Owns the Settings window. Kept alive between openings so the window
/// remembers its position and the selected tab.
@MainActor
final class SettingsWindowController {

    /// Wide enough that "Notifications & Sounds" fits on one segment.
    static let size = CGSize(width: 520, height: 360)

    private let window: NSWindow

    init(store: SettingsStore, config: AppConfig) {
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false     // reopened, not rebuilt
        window.center()
        window.contentView = NSHostingView(rootView: SettingsView(store: store, config: config))
    }

    func show() {
        // An .accessory app is not frontmost, so the window would open behind
        // whatever the user is looking at.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
