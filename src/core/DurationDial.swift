import Foundation

public struct DurationDial: Equatable, Sendable {
    public let fullTurnMinutes: Double
    public let minSeconds: Double
    public let maxSeconds: Double
    public let dragStepSeconds: Double

    public init(
        fullTurnMinutes: Double = 60,
        minSeconds: Double = 10,
        maxSeconds: Double = 3_599,
        dragStepSeconds: Double = 5
    ) {
        self.fullTurnMinutes = max(1, fullTurnMinutes)
        self.minSeconds = max(1, minSeconds)
        self.maxSeconds = max(self.minSeconds, maxSeconds)
        self.dragStepSeconds = max(1, dragStepSeconds)
    }

    public func fraction(forSeconds seconds: TimeInterval) -> Double {
        let turn = fullTurnMinutes * 60
        guard seconds < turn else { return 1 }
        return min(max(seconds / turn, 0), 1)
    }

    public func seconds(forFraction fraction: Double) -> TimeInterval {
        let raw = min(max(fraction, 0), 1) * fullTurnMinutes * 60
        let snapped = (raw / dragStepSeconds).rounded() * dragStepSeconds
        return clamp(seconds: snapped)
    }

    public func clamp(seconds: TimeInterval) -> TimeInterval {
        min(max(seconds, minSeconds), maxSeconds)
    }

    public var minMinutes: Double { minSeconds / 60 }
    public var maxMinutes: Double { maxSeconds / 60 }

    /// Settings fields hold whole minutes, but the upper bound stays exact: 60
    /// in settings gives 59:59 on the timer instead of being cut to 59:00.
    public func clamp(minutes: Double) -> Double {
        let whole = minutes.rounded()
        return whole * 60 >= maxSeconds ? maxMinutes : max(whole, minMinutes)
    }

    /// Stored durations brought back inside the dial's range — for settings
    /// saved before the upper bound got smaller.
    public func clamp(intervals: IntervalSettings) -> IntervalSettings {
        var clamped = intervals
        clamped.workMinutes = clamp(seconds: intervals.workMinutes * 60) / 60
        clamped.shortBreakMinutes = clamp(seconds: intervals.shortBreakMinutes * 60) / 60
        clamped.longBreakMinutes = clamp(seconds: intervals.longBreakMinutes * 60) / 60
        return clamped
    }
}
