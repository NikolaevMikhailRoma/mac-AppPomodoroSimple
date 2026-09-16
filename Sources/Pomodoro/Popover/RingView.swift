import SwiftUI
import PomodoroCore
import PomodoroConfig

struct RingView: View {
    let turnFraction: Double
    let ring: RingConfig
    let color: Color
    let trackColor: Color
    let backgroundColor: Color
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
        // Центр ручки лежит на границе кадра, поэтому её внешняя половина
        // оказалась бы вне зоны нажатия. Расширяем зону наружу на этот радиус.
        .contentShape(Circle().inset(by: -ring.handleDiameter / 2))
        .gesture(dragGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let center = CGPoint(x: ring.diameter / 2, y: ring.diameter / 2)
                let raw = Self.turnFraction(of: value.location, around: center)

                guard var current = drag else {
                    // Нажатие у ручки берёт её как есть, не сдвигая время;
                    // нажатие в другом месте кольца ставит ручку туда.
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

    /// Угол от центра, отсчитанный от двенадцати часов по часовой стрелке.
    /// Работает и для точек вне окружности — на этом держится захват за ручку.
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

/// Play и pause в одной кнопке. Все размеры внутри — доли от `ring.playSide`,
/// поэтому кнопка меняется целиком, одним числом в конфиге.
struct TransportButton: View {
    let isRunning: Bool
    let ring: RingConfig
    let color: Color
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
                        .stroke(
                            color,
                            style: StrokeStyle(lineWidth: ring.playLineWidth, lineJoin: .round)
                        )
                        .frame(width: side * ring.playTriangleRatio, height: side)
                }
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isRunning ? "Pause" : "Start")
    }

    private var bar: some View {
        RoundedRectangle(cornerRadius: ring.playLineWidth)
            .stroke(color, lineWidth: ring.playLineWidth)
            .frame(width: side * ring.playBarWidthRatio, height: side * ring.playBarHeightRatio)
    }
}
