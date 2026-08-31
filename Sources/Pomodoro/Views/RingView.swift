import SwiftUI
import PomodoroCore

/// The dial. Draws only — every number it needs is handed to it.
///
/// The arc is the remaining time measured against a full turn of the dial
/// (60 minutes by default), so a 25-minute timer starts as a bit under half a
/// circle and shrinks to nothing, the way a kitchen timer does.
struct RingView: View {

    let fraction: Double          // 0…1 of a full turn
    let color: Color
    let trackColor: Color
    let diameter: Double
    let lineWidth: Double
    let handleDiameter: Double
    /// The drag handle only appears when the duration can actually be changed.
    let showsHandle: Bool
    /// Reports where the user dragged to, as a fraction of a turn.
    let onDrag: (Double) -> Void

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(fraction, 0.0001))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))   // start at twelve o'clock

            if showsHandle {
                Circle()
                    .strokeBorder(color, lineWidth: lineWidth * 0.7)
                    .background(Circle().fill(trackColor))
                    .frame(width: handleDiameter, height: handleDiameter)
                    .offset(y: -diameter / 2)
                    .rotationEffect(.degrees(fraction * 360))
            }
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(showsHandle ? dragGesture : nil)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let center = CGPoint(x: diameter / 2, y: diameter / 2)
                onDrag(Self.fraction(of: value.location, around: center))
            }
    }

    /// Angle of a point around the centre, as a clockwise fraction of a turn
    /// starting from twelve o'clock.
    static func fraction(of point: CGPoint, around center: CGPoint) -> Double {
        let dx = point.x - center.x
        let dy = point.y - center.y
        // atan2(dx, -dy) puts zero at the top and grows clockwise.
        var angle = atan2(dx, -dy)
        if angle < 0 { angle += 2 * .pi }
        return angle / (2 * .pi)
    }
}
