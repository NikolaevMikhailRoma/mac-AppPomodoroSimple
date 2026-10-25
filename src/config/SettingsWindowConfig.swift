import Foundation

/// The settings window: the box, the tab bar and the grid of form rows.
public struct SettingsWindowConfig: Codable, Equatable, Sendable {
    public var width = 540.0
    public var height = 400.0
    /// The box's inset from the window edges.
    public var boxMargin = 20.0
    /// The content's inset inside the box.
    public var boxPadding = 24.0
    /// The top of the box. The tab bar sits on this line, half inside it.
    public var boxTop = 42.0
    public var rowHeight = 27.0
    /// The gap between a row's label and its control.
    public var rowSpacing = 8.0
    /// One width for every pop-up menu, so they line up.
    public var controlWidth = 119.0
    /// The width of the number fields with a stepper.
    public var fieldWidth = 48.0
    /// The gap between the field, the stepper and the unit label.
    public var stepperSpacing = 6.0
    public var sliderWidth = 200.0
    public var sectionTopPadding = 22.0
    public var sectionBottomPadding = 12.0
    public var tabBarHeight = 22.0
    /// How much smaller the selected tab is than the bar, so the bar stays visible.
    public var tabInset = 2.0
    /// The padding inside a tab, which is also what sets its width.
    public var tabPadding = 8.0
    public var tabDividerWidth = 1.0
    public var tabDividerHeight = 12.0
    public var tabBackground = "#333333"
    public var tabSelectedFill = "#666666"
    public var tabDivider = "#2B2B2B"
    public var tabTextColor = "#E0E0E0"
    public var tabTextSize = 13.0
    public var cornerRadius = 4.0
    /// How much tighter an inner rounded rectangle is than the one around it:
    /// concentric corners must differ by the width of the gap, or they do not
    /// stay parallel.
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
