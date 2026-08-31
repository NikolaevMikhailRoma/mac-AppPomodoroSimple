import Foundation

/// Окно настроек: рамка, полоса вкладок и сетка строк формы.
public struct SettingsWindowConfig: Codable, Equatable, Sendable {
    public var width = 540.0
    public var height = 400.0
    /// Отступ рамки от краёв окна.
    public var boxMargin = 20.0
    /// Отступ содержимого внутри рамки.
    public var boxPadding = 24.0
    /// Верх рамки. Полоса вкладок сидит на этой линии, наполовину заходя внутрь.
    public var boxTop = 42.0
    public var rowHeight = 27.0
    /// Зазор между подписью строки и её управлением.
    public var rowSpacing = 8.0
    /// Ширина выпадающих списков — общая, чтобы они стояли в одну линию.
    public var controlWidth = 119.0
    /// Ширина числовых полей со степпером.
    public var fieldWidth = 48.0
    /// Зазор между полем, степпером и подписью единиц.
    public var stepperSpacing = 6.0
    public var sliderWidth = 200.0
    public var sectionTopPadding = 22.0
    public var sectionBottomPadding = 12.0
    public var tabBarHeight = 22.0
    /// На сколько выделение вкладки меньше самой полосы, чтобы фон оставался виден.
    public var tabInset = 2.0
    /// Боковой отступ внутри вкладки — им же задаётся её ширина.
    public var tabPadding = 8.0
    public var tabDividerWidth = 1.0
    public var tabDividerHeight = 12.0
    public var tabBackground = "#333333"
    public var tabSelectedFill = "#666666"
    public var tabDivider = "#2B2B2B"
    public var tabTextColor = "#E0E0E0"
    public var tabTextSize = 13.0
    public var cornerRadius = 4.0
    /// Насколько скругление вложенного прямоугольника меньше внешнего: у концентрических
    /// скруглений радиусы должны отличаться на толщину зазора, иначе углы не совпадут.
    public var innerCornerDelta = 1.0
    public var borderWidth = 1.0
    public var background = "#303132"
    public var boxBackground = "#373738"
    public var boxBorder = "#505051"
    public var labelColor = "#D1D1D1"
    public var labelSize = 15.0
    public var sectionHeaderColor = "#8C8C8C"
    public var sectionHeaderSize = 13.0

    public init() {}
}
