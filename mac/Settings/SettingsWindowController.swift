import AppKit
import SwiftUI
import PomodoroCore
import PomodoroConfig
import PomodoroUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    let window: NSWindow
    private let loginItem: LoginItem
    private weak var sync: SyncServer?
    private let onClose: () -> Void

    init(timer: PomodoroTimer, loginItem: LoginItem, config: AppConfig, sync: SyncServer? = nil,
         tab: SettingsTab = .general, onClose: @escaping () -> Void = {}) {
        self.loginItem = loginItem
        self.sync = sync
        self.onClose = onClose
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
        super.init()
        window.delegate = self
        let settings = Binding(get: { timer.settings }, set: { timer.update($0) })
        window.contentView = NSHostingView(
            rootView: SettingsView(settings: settings, sound: timer.sound, config: config, tab: tab) {
                GeneralTab(settings: settings, loginItem: loginItem, metrics: metrics)
            } soundNotes: {
                EmptyView()
            } devices: {
                if let sync { DevicesTab(sync: sync, metrics: metrics) }
            }
            .frame(width: metrics.width, height: metrics.height)
        )
    }

    func show() {
        loginItem.refresh()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // A pairing QR must not stay valid behind a closed window.
        sync?.endPairing()
        onClose()
    }
}
