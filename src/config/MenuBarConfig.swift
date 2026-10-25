import Foundation

/// The digits and icon in the menu bar. The icon itself is described in
/// `icons.menuBar`; what lives here is what depends on the timer's state.
///
/// The numbers are measured pixel by pixel on a screenshot with this app and the
/// original side by side in one menu bar — see `docs/manifest.md` §11.
public struct MenuBarConfig: Codable, Equatable, Sendable {
    public var fontSize = 14.0
    public var fontWeight = "regular"
    /// Monospaced digits are wider than proportional ones and match the original
    /// slightly worse, but without them the item's width jumps every second and
    /// the neighbouring menu bar icons shift about. A deliberate trade.
    public var monospacedDigits = true
    public var workColor = "#E62621"
    public var breakColor = "#30A46C"
    public var idleColor = "#9B9B9B"

    public init() {}
}
