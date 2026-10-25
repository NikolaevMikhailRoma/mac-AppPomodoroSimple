import Foundation
import UserNotifications
import PomodoroCore

@MainActor
final class Notifier {
    private let available = Bundle.main.bundleIdentifier != nil

    func requestPermission() {
        guard available else { return }
        Task {
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        }
    }

    func post(finished: Phase, next: Phase, enabled: Bool) {
        guard available, enabled else { return }

        let content = UNMutableNotificationContent()
        content.title = finished == .work ? "Work interval finished" : "Break finished"
        content.body = next == .work ? "Time to work." : "Time for a \(next.title.lowercased())."

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        Task { try? await UNUserNotificationCenter.current().add(request) }
    }
}
