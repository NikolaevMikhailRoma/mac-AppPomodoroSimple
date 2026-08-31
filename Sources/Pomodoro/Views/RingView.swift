import SwiftUI
import PomodoroCore

struct RingView: View {
    let turnFraction: Double
    let color: Color
    let trackColor: Color
    let backgroundColor: Color
    let diameter: Double
    let lineWidth: Double
    let handleDiameter: Double
    let handleLineWidth: Double
    let onDrag: (Double) -> Void

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(turnFraction, 0.0001))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                .rotationEffect(.degrees(-90))

            Circle()
                .fill(backgroundColor)
                .overlay(Circle().strokeBorder(color, lineWidth: handleLineWidth))
                .frame(width: handleDiameter, height: handleDiameter)
                .offset(y: -diameter / 2)
                .rotationEffect(.degrees(turnFraction * 360))
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle().inset(by: -handleDiameter / 2))
        .gesture(dragGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let center = CGPoint(x: diameter / 2, y: diameter / 2)
                onDrag(Self.turnFraction(of: value.location, around: center))
            }
    }

    static func turnFraction(of point: CGPoint, around center: CGPoint) -> Double {
        let dx = point.x - center.x
        let dy = point.y - center.y
        var angle = atan2(dx, -dy)
        if angle < 0 { angle += 2 * .pi }
        return angle / (2 * .pi)
    }
}

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
