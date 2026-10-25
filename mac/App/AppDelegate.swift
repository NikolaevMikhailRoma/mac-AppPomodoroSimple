import AppKit
import PomodoroCore
import PomodoroConfig

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsStore: SettingsStore!
    private var timer: TimerController!
    private var statusItem: StatusItemController!
    private var settingsWindow: SettingsWindowController!
    private var sync: SyncServer!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let config = AppConfig.load()
        // The durations from the config apply on the first launch only: after
        // that the user's settings live in UserDefaults and take precedence.
        settingsStore = SettingsStore(fallback: Settings(intervals: config.intervals))
        // Durations saved earlier may be longer than today's upper bound.
        settingsStore.settings.intervals = config.dial.dial.clamp(intervals: settingsStore.settings.intervals)
        timer = TimerController(config: config, settings: settingsStore.settings)
        sync = SyncServer(devices: PairedDevices())
        sync.currentState = { [weak self] in self?.timer.engine.state }
        sync.onState = { [weak self] state in self?.timer.receive(state) }
        timer.onStateChange = { [weak self] state in self?.sync.broadcast(state) }
        sync.currentIntervals = { [weak self] in
            self.map { ($0.settingsStore.settings.intervals, $0.settingsStore.settings.intervalsChangedAt) }
        }
        let dial = config.dial.dial
        sync.onIntervals = { [weak self] intervals, changedAt in
            guard let store = self?.settingsStore,
                  SyncRules.shouldAdoptIntervals(local: store.settings.intervalsChangedAt, remote: changedAt, receiverIsMac: true)
            else { return }
            store.adoptIntervals(dial.clamp(intervals: intervals), changedAt: changedAt)
        }
        #if DEBUG
        if CommandLine.arguments.contains("--pair") { sync.beginPairing() }
        #endif
        settingsWindow = SettingsWindowController(store: settingsStore, loginItem: LoginItem(), config: config, sync: sync)

        settingsStore.onChange = { [weak self] settings in
            self?.timer.apply(settings)
            self?.sync.intervalsChanged(settings.intervals, changedAt: settings.intervalsChangedAt)
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
