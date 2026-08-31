import Foundation
import UserNotifications
import PomodoroCore

/// Posts a system notification when a phase ends.
///
/// Every call into `UNUserNotificationCenter` goes through its `async` form,
/// never a completion handler. A completion handler written inside a
/// `@MainActor` type inherits main-actor isolation, but the notification centre
/// calls it back on its own dispatch queue — under Swift 6 that trips the
/// executor check and kills the process with SIGTRAP. It cost one crash to
/// learn; the rule now lives in `docs/manifest.md`.
///
/// `UNUserNotificationCenter` also needs a real bundle identifier, which only
/// exists once the app is packaged. Running the raw executable from
/// `swift run` has none, so every call is guarded and simply does nothing there.
@MainActor
final class Notifier {

    private let available = Bundle.main.bundleIdentifier != nil

    /// Asked for once at launch, so the system prompt never appears at the
    /// exact moment an interval ends.
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
            trigger: nil          // deliver now
        )
        Task { try? await UNUserNotificationCenter.current().add(request) }
    }
}
