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

extension Color {
    /// "#RRGGBB" or "#RRGGBBAA"; anything else is white.
    init(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6 || text.count == 8, let value = UInt64(text, radix: 16) else {
            self = .white
            return
        }
        let alpha = text.count == 8
        let channel = { (shift: UInt64) in Double((value >> shift) & 0xFF) / 255 }
        self.init(
            .sRGB,
            red: channel(alpha ? 24 : 16),
            green: channel(alpha ? 16 : 8),
            blue: channel(alpha ? 8 : 0),
            opacity: alpha ? channel(0) : 1
        )
    }
}
