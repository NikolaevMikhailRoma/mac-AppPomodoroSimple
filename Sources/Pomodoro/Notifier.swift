import Foundation
import UserNotifications
import PomodoroCore

/// Posts a system notification when a phase ends.
///
/// `UNUserNotificationCenter` needs a real bundle identifier, which only exists
/// once the app is packaged. Running the raw executable from `swift run` has
/// none, so every call is guarded and simply does nothing there.
@MainActor
final class Notifier {

    private let available = Bundle.main.bundleIdentifier != nil
    private var askedForPermission = false

    func post(finished: Phase, next: Phase, enabled: Bool) {
        guard available, enabled else { return }
        requestPermissionOnce()

        let content = UNMutableNotificationContent()
        content.title = finished == .work ? "Work interval finished" : "Break finished"
        content.body = next == .work ? "Time to work." : "Time for a \(next.title.lowercased())."

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil          // deliver now
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func requestPermissionOnce() {
        guard !askedForPermission else { return }
        askedForPermission = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
