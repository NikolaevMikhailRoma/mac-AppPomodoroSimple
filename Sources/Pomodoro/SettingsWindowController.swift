import AppKit
import SwiftUI
import PomodoroCore

/// Owns the Settings window. Kept alive between openings so the window
/// remembers its position and the selected tab.
@MainActor
final class SettingsWindowController {

    private let window: NSWindow

    init(store: SettingsStore, config: AppConfig) {
        let metrics = config.settingsWindow
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: metrics.width, height: metrics.height),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false     // reopened, not rebuilt
        window.backgroundColor = Theme.color(metrics.windowBackground, fallback: .windowBackgroundColor)
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
