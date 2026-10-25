import Foundation
import UserNotifications
import PomodoroCore

/// A notification the moment an interval ends: the Mac app is always running, so nothing is scheduled ahead.
@MainActor
final class Notifier: TimerAlerts {
    let ringWhileClosed = false
    private let available = Bundle.main.bundleIdentifier != nil

    init() {
        guard available else { return }
        Task {
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        }
    }

    func finished(_ phase: Phase, next: Phase, settings: Settings) {
        guard available, settings.sound.notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = phase == .work ? "Work interval finished" : "Break finished"
        content.body = next == .work ? "Time to work." : "Time for a \(next.title.lowercased())."

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        Task { try? await UNUserNotificationCenter.current().add(request) }
    }

    func changed(_ engine: PomodoroEngine, settings: Settings) {}
}
