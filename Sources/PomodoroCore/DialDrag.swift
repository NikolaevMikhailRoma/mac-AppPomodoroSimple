import Foundation

/// Перетаскивание ручки кольца с упором на двенадцати часах, как у настоящего
/// регулятора: дойдя до нуля или до полного круга, ручка останавливается и не
/// перескакивает на другой конец, куда бы ни ушёл курсор.
public struct DialDrag: Equatable, Sendable {
    /// Скачок больше полукруга за одно движение — это курсор перешёл через
    /// двенадцать часов, а не пользователь провёл полкруга за один кадр.
    private static let wrapThreshold = 0.5
    /// Насколько близко к ручке нужно попасть курсором, чтобы взять её, а не
    /// переставить. Упёршуюся ручку курсор забирает с того же расстояния.
    public static let grabDistance = 0.05

    public private(set) var fraction: Double
    /// 0 или 1, пока ручка стоит в упоре.
    private var stop: Double?

    public init(startingAt fraction: Double) {
        self.fraction = min(max(fraction, 0), 1)
    }

    /// Положение ручки для курсора в `raw` (доля оборота от двенадцати часов).
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

    /// Расстояние по кругу: 0.98 и 0.02 отстоят на 0.04, а не на 0.96.
    public static func distance(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b).truncatingRemainder(dividingBy: 1)
        return min(d, 1 - d)
    }
}
