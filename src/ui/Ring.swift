import PomodoroConfig
import PomodoroCore
import SwiftUI

struct RingView: View {
    let turnFraction: Double
    let ring: RingConfig
    let color: Color
    let trackColor: Color
    let backgroundColor: Color
    /// The band along the ring that takes a touch, as a fraction of the radius; nil takes the whole disc.
    let touchBand: Double?
    let onDrag: (Double) -> Void

    @State private var drag: DialDrag?

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: ring.lineWidth)

            Circle()
                .trim(from: 0, to: max(turnFraction, 0.0001))
                .stroke(color, style: StrokeStyle(lineWidth: ring.lineWidth, lineCap: .butt))
                .rotationEffect(.degrees(-90))

            Circle()
                .fill(backgroundColor)
                .overlay(Circle().strokeBorder(color, lineWidth: ring.handleLineWidth))
                .frame(width: ring.handleDiameter, height: ring.handleDiameter)
                .offset(y: -ring.diameter / 2)
                .rotationEffect(.degrees(turnFraction * 360))
        }
        .frame(width: ring.diameter, height: ring.diameter)
        // The handle is centred on the frame's edge, so its outer half would
        // fall outside the hit area. Widen that area by the same radius.
        .contentShape(Band(inner: 1 - (touchBand ?? 1), outset: ring.handleDiameter / 2), eoFill: true)
        .gesture(dragGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let center = CGPoint(x: ring.diameter / 2, y: ring.diameter / 2)
                let raw = Self.turnFraction(of: value.location, around: center)

                guard var current = drag else {
                    // A press near the handle picks it up as it is, leaving the
                    // time alone; a press elsewhere moves the handle there.
                    if DialDrag.distance(raw, turnFraction) < DialDrag.grabDistance {
                        drag = DialDrag(startingAt: turnFraction)
                    } else {
                        drag = DialDrag(startingAt: raw)
                        onDrag(raw)
                    }
                    return
                }
                let before = current.fraction
                let after = current.move(to: raw)
                drag = current
                if after != before { onDrag(after) }
            }
            .onEnded { _ in drag = nil }
    }

    /// The angle from the centre, measured clockwise from twelve o'clock. It
    /// works for points outside the circle too, which is what makes grabbing the
    /// handle possible.
    static func turnFraction(of point: CGPoint, around center: CGPoint) -> Double {
        var angle = atan2(point.x - center.x, center.y - point.y)
        if angle < 0 { angle += 2 * .pi }
        return angle / (2 * .pi)
    }
}

/// The ring's touch area: a disc with a hole, filled even-odd. No hole takes the whole disc.
private struct Band: Shape {
    let inner: Double
    let outset: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: rect.insetBy(dx: -outset, dy: -outset))
        guard inner > 0 else { return path }
        let hole = rect.width / 2 * inner
        path.addEllipse(in: CGRect(x: rect.midX - hole, y: rect.midY - hole, width: hole * 2, height: hole * 2))
        return path
    }
}

private struct PlayTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

/// Play and pause in one button. Every size inside is a fraction of
/// `ring.playSide`, so one number in the config resizes the whole button.
struct TransportButton: View {
    let isRunning: Bool
    let ring: RingConfig
    let color: Color
    let minTouch: Double
    let action: () -> Void

    private var side: Double { ring.playSide }

    var body: some View {
        Button(action: action) {
            Group {
                if isRunning {
                    HStack(spacing: side * ring.playGapRatio) {
                        bar
                        bar
                    }
                } else {
                    PlayTriangle()
                        .stroke(color, style: StrokeStyle(lineWidth: ring.playLineWidth, lineJoin: .round))
                        .frame(width: side * ring.playTriangleRatio, height: side)
                }
            }
            .frame(width: max(side, minTouch), height: max(side, minTouch))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isRunning ? "Pause" : "Start")
        .accessibilityLabel(isRunning ? "Pause" : "Start")
    }

    private var bar: some View {
        RoundedRectangle(cornerRadius: ring.playLineWidth)
            .stroke(color, lineWidth: ring.playLineWidth)
            .frame(width: side * ring.playBarWidthRatio, height: side * ring.playBarHeightRatio)
    }
}
