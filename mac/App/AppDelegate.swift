import AppKit
import PomodoroCore
import PomodoroConfig

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let config = AppConfig.load()
    private let loginItem = LoginItem()
    private var timer: PomodoroTimer!
    private var statusItem: StatusItemController!
    /// Made when opened and let go when closed: most of the time nobody looks at it.
    private var settingsWindow: SettingsWindowController?
    private var sync: SyncServer!

    func applicationDidFinishLaunching(_ notification: Notification) {
        timer = PomodoroTimer(intervals: config.intervals, dial: config.dial.dial,
                              sound: SoundPlayer(), alerts: Notifier(), isHub: true)
        Theme.applyAppearance(timer.settings.general.appearance)
        sync = SyncServer(devices: PairedDevices())
        sync.currentState = { [weak self] in self?.timer.state }
        sync.onState = { [weak self] state in self?.timer.receive(state) }
        timer.onStateChange = { [weak self] state in self?.sync.broadcast(state) }
        sync.currentIntervals = { [weak self] in
            self.map { ($0.timer.settings.intervals, $0.timer.settings.intervalsChangedAt) }
        }
        sync.onIntervals = { [weak self] intervals, changedAt in self?.timer.receiveIntervals(intervals, changedAt: changedAt) }
        timer.onIntervalsChange = { [weak self] intervals, changedAt in self?.sync.intervalsChanged(intervals, changedAt: changedAt) }
        #if DEBUG
        if CommandLine.arguments.contains("--pair") { sync.beginPairing() }
        #endif
        statusItem = StatusItemController(
            timer: timer,
            config: config,
            openSettings: { [weak self] in self?.showSettings() }
        )
    }

    private func showSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(timer: timer, loginItem: loginItem, config: config, sync: sync) {
                // After the close has run: the window is still in use until then.
                DispatchQueue.main.async { [weak self] in self?.settingsWindow = nil }
            }
        }
        settingsWindow?.show()
    }
}
