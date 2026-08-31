import AppKit
import SwiftUI
import PomodoroCore
import PomodoroConfig

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
        window.isReleasedWhenClosed = false
        window.backgroundColor = Theme.color(metrics.background, fallback: .windowBackgroundColor)
        window.center()
        window.contentView = NSHostingView(rootView: SettingsView(store: store, config: config))
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
