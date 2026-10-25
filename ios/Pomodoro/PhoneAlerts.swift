import ActivityKit
import Foundation
import Observation
import PomodoroConfig
import PomodoroCore

/// What shows the timer with the app closed: notifications scheduled ahead,
/// so that they ring on time, and the Lock Screen timer.
@MainActor
@Observable
final class PhoneAlerts: TimerAlerts {
    private static let lockScreenKey = "ShowOnLockScreen"

    let ringWhileClosed = true
    /// The Live Activity. iPhone only, so not in Settings, which the Mac shares.
    private(set) var showOnLockScreen: Bool
    /// Switched off in iOS Settings, as opposed to never asked.
    private(set) var notificationsDenied = false
    private(set) var liveActivitiesDenied = false

    @ObservationIgnored private let notifier = Notifier()
    @ObservationIgnored private let lockScreen: LockScreenTimer
    @ObservationIgnored private let sound: SoundPlayer
    /// What the timer last showed: a switch or a permission here shows it again.
    @ObservationIgnored private var last: (engine: PomodoroEngine, settings: Settings)?

    init(sound: SoundPlayer, ring: RingConfig) {
        self.sound = sound
        lockScreen = LockScreenTimer(ring: ring)
        showOnLockScreen = UserDefaults.standard.object(forKey: Self.lockScreenKey) as? Bool ?? true
    }

    /// With the app open the timer rings by itself; the notification's banner comes silent.
    func finished(_ phase: Phase, next: Phase, settings: Settings) {}

    func changed(_ engine: PomodoroEngine, settings: Settings) {
        last = (engine, settings)
        notifier.schedule(engine, sound: settings.sound, file: sound.notificationSound)
        lockScreen.show(engine.state, enabled: showOnLockScreen)
    }

    func setShowOnLockScreen(_ on: Bool) {
        showOnLockScreen = on
        UserDefaults.standard.set(on, forKey: Self.lockScreenKey)
        if let last { lockScreen.show(last.engine.state, enabled: on) }
    }

    /// Asked when the timer first starts, not at launch: that is when a
    /// notification is first due. iOS itself asks only once.
    func askForNotifications() async {
        guard last?.settings.sound.notificationsEnabled ?? false, await notifier.status() == .notDetermined else { return }
        await notifier.requestPermission()
        await refreshPermissions()
        if let last { changed(last.engine, settings: last.settings) }
    }

    /// After a return to the app: either may have been switched in iOS Settings.
    func refreshPermissions() async {
        notificationsDenied = await notifier.status() == .denied
        liveActivitiesDenied = !ActivityAuthorizationInfo().areActivitiesEnabled
    }
}
