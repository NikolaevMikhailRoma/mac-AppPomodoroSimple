import Foundation
import PomodoroCore

/// The popover under the menu bar icon.
///
/// The vertical rhythm is set so that every height and spacer adds up to
/// `height`. Change one and recompute the rest, or the content drifts.
public struct PopoverConfig: Codable, Equatable, Sendable {
    public var width = 256.0
    public var height = 335.0
    public var padding = 14.0
    /// The close button's inset from the window edge, not from the content edge.
    public var closeButtonInset = 24.0
    public var headerHeight = 22.0
    /// The smallest gap between the phase name and the close button.
    public var headerSpacing = 8.0
    public var headerToRing = 39.0
    public var ringToFooter = 28.0
    public var footerHeight = 22.0
    /// The width of the footer's side slots: skip on the left, the gear on the
    /// right. Equal slots keep `Today N` exactly centred.
    public var footerSideWidth = 44.0
    /// The gap between the word `Today` and the number.
    public var counterSpacing = 6.0
    public var background = "#252525"
    public var textSecondary = "#C8C8C8"
    public var textDim = "#646464"

    public init() {}
}

/// The ring at the centre of the popover and everything drawn inside it.
public struct RingConfig: Codable, Equatable, Sendable {
    public var diameter = 196.0
    public var lineWidth = 4.0
    /// The handle at the end of the arc. The hit area is widened outwards by
    /// half of it, or the visible circle sticks out of what catches the cursor.
    public var handleDiameter = 22.0
    public var handleLineWidth = 2.0
    public var trackColor = "#3D3D3D"
    /// The arc is lighter than the menu bar icon, as in the original.
    public var workColor = "#EC958C"
    public var breakColor = "#8CD3A2"
    /// The digits sit above the ring's centre: the play button goes below them.
    public var digitsOffset = -9.5
    public var playOffset = 57.75
    /// The limit hint goes in the gap between the digits and the play button.
    public var hintOffset = 26.0
    /// The side of the square the play/pause button fits into. Everything else
    /// in the button is a fraction of it, so the button resizes as a whole.
    public var playSide = 34.0
    public var playLineWidth = 1.0
    /// The triangle's width as a fraction of the side. 0.866 is √3/2, an
    /// equilateral one; less than that and it stretches into a narrow sliver.
    public var playTriangleRatio = 0.866
    /// Pause: bar width, bar height and the gap between bars, as fractions of the side.
    public var playBarWidthRatio = 0.26
    public var playBarHeightRatio = 0.82
    public var playGapRatio = 0.24

    public init() {}

    public func accent(for phase: Phase) -> String {
        phase == .work ? workColor : breakColor
    }
}
