import Foundation

/// Formatting and parsing of the `mm:ss` string shown in the middle of the ring
/// and in the menu bar. Kept here so the editable timer has one definition of
/// what counts as valid input.
public enum TimeFormat {

    /// Seconds to `mm:ss`, or `h:mm:ss` past an hour.
    public static func string(from seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    /// Parses what the user typed over the digits.
    ///
    /// Accepts `"25"` (minutes), `"25:30"` (minutes and seconds) and
    /// `"1:05:00"` (hours, minutes, seconds). Returns nil for anything else,
    /// which the caller treats as "keep the old value".
    public static func seconds(from text: String) -> TimeInterval? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ":")
        guard (1...3).contains(parts.count) else { return nil }

        var numbers: [Int] = []
        for part in parts {
            guard let n = Int(part), n >= 0 else { return nil }
            numbers.append(n)
        }

        switch numbers.count {
        case 1: return TimeInterval(numbers[0] * 60)
        case 2: return TimeInterval(numbers[0] * 60 + numbers[1])
        default: return TimeInterval(numbers[0] * 3600 + numbers[1] * 60 + numbers[2])
        }
    }
}
