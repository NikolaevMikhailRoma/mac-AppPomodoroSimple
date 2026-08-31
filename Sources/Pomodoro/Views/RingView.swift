import SwiftUI
import PomodoroCore

/// The dial. Draws only — every number it needs is handed to it.
///
/// Matches the reference arc exactly: it starts at twelve o'clock, runs
/// clockwise, and has a flat (butt) cap, which was confirmed by scanning the
/// original at 3600 points around the circle.
struct RingView: View {

    let fraction: Double          // 0…1 of a full turn
    let color: Color
    let trackColor: Color
    /// The handle is filled with the popover's background so it punches a hole
    /// through both the arc and the track, exactly as in the reference.
    let backgroundColor: Color
    let diameter: Double
    let lineWidth: Double
    let handleDiameter: Double
    let handleLineWidth: Double
    /// Reports where the user tapped or dragged to, as a fraction of a turn.
    let onDrag: (Double) -> Void

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(fraction, 0.0001))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                .rotationEffect(.degrees(-90))   // start at twelve o'clock

            Circle()
                .fill(backgroundColor)
                .overlay(Circle().strokeBorder(color, lineWidth: handleLineWidth))
                .frame(width: handleDiameter, height: handleDiameter)
                .offset(y: -diameter / 2)
                .rotationEffect(.degrees(fraction * 360))
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(dragGesture)
    }

    /// `minimumDistance: 0` is what makes a plain tap on the dial work as well
    /// as a drag — `onChanged` fires for both.
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

/// An equilateral triangle pointing right, drawn as an outline like the
/// reference's play button. Its frame should be `side * √3/2` wide by `side`
/// tall for the sides to come out equal.
struct PlayTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

/// Play and pause in one control, both outlined at the same stroke weight so
/// the button does not change visual weight when the timer starts.
struct TransportButton: View {
    let isRunning: Bool
    let color: Color
    let side: Double
    let lineWidth: Double
    let action: () -> Void

    private var triangleWidth: Double { side * sqrt(3) / 2 }

    var body: some View {
        Button(action: action) {
            Group {
                if isRunning {
                    HStack(spacing: side * 0.24) {
                        bar
                        bar
                    }
                } else {
                    PlayTriangle()
                        .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
                        .frame(width: triangleWidth, height: side)
                }
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isRunning ? "Pause" : "Start")
    }

    private var bar: some View {
        RoundedRectangle(cornerRadius: lineWidth)
            .stroke(color, lineWidth: lineWidth)
            .frame(width: side * 0.26, height: side * 0.82)
    }
}
