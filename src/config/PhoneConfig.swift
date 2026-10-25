import Foundation

/// The phones (iPhone and Android) draw the Mac's popover and settings window
/// at their own size. The popover scales to the screen by itself; this is the
/// rest: the settings box in Mac points times `settingsScale`, and what a finger needs.
public struct PhoneConfig: Codable, Equatable, Sendable {
    /// Text, tabs and controls of the settings window, larger by this much.
    public var settingsScale = 1.1
    /// Between the screen edges and the box, and under it.
    public var margin = 16.0
    /// The content's inset inside the box: less than the Mac's, a phone is narrow.
    public var boxPadding = 16.0
    /// Above the tab bar, under the title.
    public var top = 8.0
    /// A form row; a long label wraps instead and makes the row taller.
    public var rowHeight = 44.0
    /// The smallest touch area of a button, however small it is drawn.
    public var minTouch = 44.0
    /// How far inside the ring a touch still grabs it, as a fraction of the
    /// radius. The Mac takes clicks over the whole disc; on a phone that turns
    /// every stray touch near the digits into a new duration.
    public var ringTouchBand = 0.3
    /// Switches, sliders and pickers. The Mac's take the system accent colour;
    /// this is the green one, which the phones have no setting for.
    public var tint = "#62BA46"

    public init() {}
}

extension SettingsWindowConfig {
    /// The window's sizes for a phone: text and spacing larger by
    /// `settingsScale`, then the phone's own margins and row height. Pickers and
    /// the slider keep the Mac's widths: a phone has no room for more.
    public func forPhone(_ phone: PhoneConfig) -> SettingsWindowConfig {
        let s = phone.settingsScale
        var m = self
        m.rowHeight = max(rowHeight * s, phone.rowHeight)
        m.rowSpacing *= s
        m.fieldWidth *= s
        m.stepperSpacing *= s
        m.sectionTopPadding *= s
        m.sectionBottomPadding *= s
        m.tabBarHeight *= s
        m.tabInset *= s
        m.tabPadding *= s
        m.tabDividerHeight *= s
        m.tabTextSize *= s
        m.cornerRadius *= s
        m.labelSize *= s
        m.sectionHeaderSize *= s
        m.boxMargin = phone.margin
        m.boxPadding = phone.boxPadding
        m.contentTop = m.tabBarHeight / 2 + phone.boxPadding
        m.boxTop = phone.top + m.tabBarHeight / 2
        return m
    }
}

extension RingConfig {
    /// Every length in points times `scale`; ratios and colours stay.
    public func scaled(_ scale: Double) -> RingConfig {
        var ring = self
        ring.diameter *= scale
        ring.lineWidth *= scale
        ring.handleDiameter *= scale
        ring.handleLineWidth *= scale
        ring.digitsOffset *= scale
        ring.playOffset *= scale
        ring.hintOffset *= scale
        ring.playSide *= scale
        ring.playLineWidth *= scale
        return ring
    }
}
