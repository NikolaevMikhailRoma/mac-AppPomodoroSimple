import Foundation

/// Dragging the ring handle with a stop at twelve o'clock, the way a real dial
/// behaves: having reached zero or a full turn the handle stays there instead of
/// jumping to the other end, wherever the cursor goes.
public struct DialDrag: Equatable, Sendable {
    /// A jump of more than half a turn in one move means the cursor crossed
    /// twelve o'clock, not that the user swept half the dial in a single frame.
    private static let wrapThreshold = 0.5
    /// How close the cursor has to land to pick the handle up rather than move
    /// it there. A handle resting against a stop is picked up from the same
    /// distance.
    public static let grabDistance = 0.05

    public private(set) var fraction: Double
    /// 0 or 1 while the handle rests against a stop.
    private var stop: Double?

    public init(startingAt fraction: Double) {
        self.fraction = min(max(fraction, 0), 1)
    }

    /// Where the handle goes for a cursor at `raw`, a turn fraction measured
    /// clockwise from twelve o'clock.
    public mutating func move(to raw: Double) -> Double {
        if let stop {
            guard Self.distance(raw, stop) < Self.grabDistance else { return fraction }
            self.stop = nil
        }
        if abs(raw - fraction) > Self.wrapThreshold {
            let end: Double = fraction < 0.5 ? 0 : 1
            stop = end
            fraction = end
        } else {
            fraction = raw
        }
        return fraction
    }

    /// Distance around the circle: 0.98 and 0.02 are 0.04 apart, not 0.96.
    public static func distance(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b).truncatingRemainder(dividingBy: 1)
        return min(d, 1 - d)
    }
}
