import Foundation

/// Maps a position on the ring to a duration and back.
///
/// One full turn of the ring equals `fullTurnMinutes`. The geometry lives here
/// rather than in the view so it can be tested, and so the view is left with
/// nothing but drawing.
///
/// Everything is in seconds. An earlier version worked in whole minutes, which
/// quietly destroyed a typed `0:10` by rounding it up to a minute.
public struct DurationDial: Equatable, Sendable {
    public let fullTurnMinutes: Double
    public let minSeconds: Double
    public let maxSeconds: Double
    /// Snap applied to dragging only. A full turn is 360° over 60 minutes, so
    /// one degree is ten seconds — a finer step than this would be below the
    /// precision of the mouse.
    public let dragStepSeconds: Double

    public init(
        fullTurnMinutes: Double = 60,
        minSeconds: Double = 10,
        maxSeconds: Double = 10_800,
        dragStepSeconds: Double = 15
    ) {
        self.fullTurnMinutes = max(1, fullTurnMinutes)
        self.minSeconds = max(1, minSeconds)
        self.maxSeconds = max(self.minSeconds, maxSeconds)
        self.dragStepSeconds = max(1, dragStepSeconds)
    }

    /// Fraction of a turn (0…1, clockwise from twelve o'clock) for a duration.
    /// Durations longer than one turn stay pinned at the top of the dial.
    public func fraction(forSeconds seconds: TimeInterval) -> Double {
        let turn = fullTurnMinutes * 60
        guard seconds < turn else { return 1 }
        return min(max(seconds / turn, 0), 1)
    }

    /// Duration for a fraction of a turn, snapped to `dragStepSeconds` and
    /// clamped. Used by the ring drag, and only by it.
    public func seconds(forFraction fraction: Double) -> TimeInterval {
        let raw = min(max(fraction, 0), 1) * fullTurnMinutes * 60
        let snapped = (raw / dragStepSeconds).rounded() * dragStepSeconds
        return clamp(seconds: snapped)
    }

    /// Keeps a typed value inside the allowed range **without** snapping it,
    /// so seconds entered by hand survive.
    public func clamp(seconds: TimeInterval) -> TimeInterval {
        min(max(seconds, minSeconds), maxSeconds)
    }

    public var minMinutes: Double { minSeconds / 60 }
    public var maxMinutes: Double { maxSeconds / 60 }

    /// Range check for the minute fields in Settings.
    public func clamp(minutes: Double) -> Double {
        clamp(seconds: minutes * 60) / 60
    }
}
