import AppKit
import PomodoroCore

/// Wires the three pieces together and hands each one only what it needs:
/// the timer knows nothing about the menu bar, and the menu bar knows nothing
/// about how time is counted.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var settingsStore: SettingsStore!
    private var timer: TimerController!
    private var statusItem: StatusItemController!
    private var settingsWindow: SettingsWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let config = AppConfig.load()
        settingsStore = SettingsStore()
        timer = TimerController(config: config, settings: settingsStore.settings)
        settingsWindow = SettingsWindowController(store: settingsStore, config: config)

        // Settings changes flow one way: store → timer, store → appearance.
        settingsStore.onChange = { [weak self] settings in
            self?.timer.apply(settings)
            Theme.applyAppearance(settings.general.appearance)
        }
        Theme.applyAppearance(settingsStore.settings.general.appearance)

        statusItem = StatusItemController(
            timer: timer,
            store: settingsStore,
            config: config,
            openSettings: { [weak self] in self?.settingsWindow.show() }
        )
    }
}
