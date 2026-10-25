import Foundation

public enum TimeFormat {
    public static func string(from seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

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
