import Foundation

/// Maps a position on the ring to a duration and back.
///
/// One full turn of the ring equals `fullTurnMinutes`. The geometry lives here
/// rather than in the view so it can be tested, and so the view is left with
/// nothing but drawing.
public struct DurationDial: Equatable, Sendable {
    public let fullTurnMinutes: Double
    public let minMinutes: Double
    public let maxMinutes: Double
    public let stepMinutes: Double

    public init(
        fullTurnMinutes: Double = 60,
        minMinutes: Double = 1,
        maxMinutes: Double = 180,
        stepMinutes: Double = 1
    ) {
        self.fullTurnMinutes = max(1, fullTurnMinutes)
        self.minMinutes = max(0, minMinutes)
        self.maxMinutes = max(minMinutes, maxMinutes)
        self.stepMinutes = max(0.01, stepMinutes)
    }

    /// Fraction of a turn (0…1, clockwise from twelve o'clock) for a duration.
    /// Durations longer than one turn stay pinned at the top of the dial.
    public func fraction(forSeconds seconds: TimeInterval) -> Double {
        let minutes = seconds / 60
        guard minutes < fullTurnMinutes else { return 1 }
        return min(max(minutes / fullTurnMinutes, 0), 1)
    }

    /// Duration for a fraction of a turn, snapped to `stepMinutes` and clamped.
    public func seconds(forFraction fraction: Double) -> TimeInterval {
        let raw = min(max(fraction, 0), 1) * fullTurnMinutes
        let snapped = (raw / stepMinutes).rounded() * stepMinutes
        return clamp(minutes: snapped) * 60
    }

    /// Keeps a typed or nudged value inside the allowed range.
    public func clamp(minutes: Double) -> Double {
        min(max(minutes, minMinutes), maxMinutes)
    }

    public func clamp(seconds: TimeInterval) -> TimeInterval {
        clamp(minutes: seconds / 60) * 60
    }
}
