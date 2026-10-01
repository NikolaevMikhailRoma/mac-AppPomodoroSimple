import AppKit
import PomodoroCore
import PomodoroConfig

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsStore: SettingsStore!
    private var timer: TimerController!
    private var statusItem: StatusItemController!
    private var settingsWindow: SettingsWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let config = AppConfig.load()
        // The durations from the config apply on the first launch only: after
        // that the user's settings live in UserDefaults and take precedence.
        settingsStore = SettingsStore(fallback: Settings(intervals: config.intervals))
        // Durations saved earlier may be longer than today's upper bound.
        settingsStore.settings.intervals = config.dial.dial.clamp(intervals: settingsStore.settings.intervals)
        timer = TimerController(config: config, settings: settingsStore.settings)
        settingsWindow = SettingsWindowController(store: settingsStore, loginItem: LoginItem(), config: config)

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
