import Foundation

/// Цифры и значок в строке меню. Сам значок описан в `icons.menuBar` — здесь
/// только то, что зависит от состояния таймера.
///
/// Числа замерены попиксельно на скриншоте, где наше приложение и оригинал стоят
/// в одной строке меню, — см. `docs/manifest.md` §11.
public struct MenuBarConfig: Codable, Equatable, Sendable {
    public var fontSize = 14.0
    public var fontWeight = "regular"
    /// Моноширинные цифры шире пропорциональных и попадают в оригинал чуть хуже,
    /// но без них ширина элемента прыгает на каждой секунде и соседние значки
    /// в строке меню ездят. Обмен сознательный.
    public var monospacedDigits = true
    public var workColor = "#E62621"
    public var breakColor = "#30A46C"
    public var idleColor = "#9B9B9B"

    public init() {}
}
