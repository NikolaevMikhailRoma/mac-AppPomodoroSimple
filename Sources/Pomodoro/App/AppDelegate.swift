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
        // Длительности из конфига действуют только на первом запуске:
        // дальше настройки пользователя лежат в UserDefaults и имеют приоритет.
        settingsStore = SettingsStore(fallback: Settings(intervals: config.intervals))
        timer = TimerController(config: config, settings: settingsStore.settings)
        settingsWindow = SettingsWindowController(store: settingsStore, config: config)

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
