import ActivityKit
import AppIntents
import SwiftUI

// Compiled into both the app and the Live Activity extension.

/// What the Lock Screen shows, as plain values: the extension does not link the timer.
struct TimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        /// The ring's colour for the phase, "#EC958C".
        var accent: String
        /// Set while running: the system counts down to it with the app closed.
        var endsAt: Date?
        var remaining: TimeInterval
    }
}

/// Pause and resume on the Lock Screen. iOS runs it in the app's process,
/// starting the app in the background if needed; the extension never does.
struct ToggleTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause or resume the timer"

    func perform() async throws -> some IntentResult {
        await TimerIntentHandler.toggle()
        return .result()
    }
}
