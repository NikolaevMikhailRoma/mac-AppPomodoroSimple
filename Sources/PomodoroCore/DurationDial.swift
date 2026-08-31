import Foundation

public struct DurationDial: Equatable, Sendable {
    public let fullTurnMinutes: Double
    public let minSeconds: Double
    public let maxSeconds: Double
    public let dragStepSeconds: Double

    public init(
        fullTurnMinutes: Double = 60,
        minSeconds: Double = 10,
        maxSeconds: Double = 10_800,
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

    public func clamp(minutes: Double) -> Double {
        clamp(seconds: minutes * 60) / 60
    }
}
