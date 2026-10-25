import PomodoroCore
@preconcurrency import UserNotifications

/// The end-of-interval alerts. Nothing runs a closed app, so they are
/// scheduled ahead: the running interval's end and, with auto-start, the ends
/// of the intervals after it. The sound comes with them.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func status() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestPermission() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func schedule(_ engine: PomodoroEngine, sound: SoundSettings, file: (String) -> UNNotificationSound) {
        center.removeAllPendingNotificationRequests()
        guard sound.notificationsEnabled else { return }
        var future = engine
        for index in 0..<PomodoroTimer.endsAhead {
            guard future.runState == .running, let endsAt = future.state.endsAt else { return }
            let finished = future.phase
            _ = future.update(now: endsAt)
            let content = UNMutableNotificationContent()
            content.title = finished == .work ? "Work interval finished" : "Break finished"
            content.body = future.phase == .work ? "Time to work." : "Time for a \(future.phase.title.lowercased())."
            if sound.soundEnabled { content.sound = file(sound.sound(afterFinishing: finished)) }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, endsAt.timeIntervalSinceNow), repeats: false)
            center.add(UNNotificationRequest(identifier: "end-\(index)", content: content, trigger: trigger))
        }
    }

    /// With the app open it rings by itself, at its own volume: the banner comes silent.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}
