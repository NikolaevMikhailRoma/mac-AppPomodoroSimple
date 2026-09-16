import Foundation
import PomodoroCore

/// Попап под значком в строке меню.
///
/// Вертикальный ритм задан так, что сумма всех высот и распорок равна `height`.
/// Меняешь одно — пересчитай остальные, иначе содержимое поедет.
public struct PopoverConfig: Codable, Equatable, Sendable {
    public var width = 256.0
    public var height = 335.0
    public var padding = 14.0
    /// Отступ крестика от правого края окна, а не от края содержимого.
    public var closeButtonInset = 24.0
    public var headerHeight = 22.0
    /// Минимальный зазор между названием фазы и крестиком.
    public var headerSpacing = 8.0
    public var headerToRing = 39.0
    public var ringToFooter = 28.0
    public var footerHeight = 22.0
    /// Ширина боковых слотов подвала: слева пропуск, справа шестерёнка. Слоты
    /// равны, поэтому «Today N» стоит ровно по центру.
    public var footerSideWidth = 44.0
    /// Зазор между словом «Today» и числом.
    public var counterSpacing = 6.0
    public var background = "#252525"
    public var textSecondary = "#C8C8C8"
    public var textDim = "#646464"

    public init() {}
}

/// Кольцо в центре попапа и всё, что нарисовано внутри него.
public struct RingConfig: Codable, Equatable, Sendable {
    public var diameter = 196.0
    public var lineWidth = 4.0
    /// Ручка на конце дуги. Зона нажатия расширена на её половину наружу —
    /// иначе видимый кружок торчит за пределы области, которая ловит курсор.
    public var handleDiameter = 22.0
    public var handleLineWidth = 2.0
    public var trackColor = "#3D3D3D"
    /// Цвет дуги светлее цвета значка в строке меню — так в оригинале.
    public var workColor = "#EC958C"
    public var breakColor = "#8CD3A2"
    /// Цифры стоят не по центру кольца, а чуть выше: под ними кнопка play.
    public var digitsOffset = -9.5
    public var playOffset = 57.75
    /// Подсказка о пределе — в зазоре между цифрами и кнопкой play.
    public var hintOffset = 26.0
    /// Сторона квадрата, в который вписана кнопка play/pause. Всё остальное
    /// в кнопке — доли от неё, поэтому кнопка меняет размер целиком.
    public var playSide = 34.0
    public var playLineWidth = 1.0
    /// Ширина треугольника в долях стороны. 0.866 — это √3/2, равносторонний;
    /// меньше — треугольник вытянется и станет узким.
    public var playTriangleRatio = 0.866
    /// Пауза: ширина штриха, его высота и зазор между штрихами, в долях стороны.
    public var playBarWidthRatio = 0.26
    public var playBarHeightRatio = 0.82
    public var playGapRatio = 0.24

    public init() {}

    public func accent(for phase: Phase) -> String {
        phase == .work ? workColor : breakColor
    }
}
