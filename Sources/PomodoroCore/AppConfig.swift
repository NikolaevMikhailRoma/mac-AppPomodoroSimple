import Foundation

/// The contents of `config.json` — the tuning knobs that are not worth a
/// settings screen: colours, sizes, ranges, defaults.
///
/// Every field has a fallback, so a missing or half-written config file
/// degrades to the built-in defaults instead of failing to launch. Colours are
/// plain hex strings here; turning them into real colours is the UI layer's job.
public struct AppConfig: Codable, Equatable, Sendable {
    public var menuBar: MenuBarConfig
    public var popover: PopoverConfig
    public var ring: RingConfig
    public var dial: DialConfig
    public var defaults: IntervalSettings

    public init(
        menuBar: MenuBarConfig = MenuBarConfig(),
        popover: PopoverConfig = PopoverConfig(),
        ring: RingConfig = RingConfig(),
        dial: DialConfig = DialConfig(),
        defaults: IntervalSettings = IntervalSettings()
    ) {
        self.menuBar = menuBar
        self.popover = popover
        self.ring = ring
        self.dial = dial
        self.defaults = defaults
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppConfig()
        menuBar = c.value(.menuBar, or: d.menuBar)
        popover = c.value(.popover, or: d.popover)
        ring = c.value(.ring, or: d.ring)
        dial = c.value(.dial, or: d.dial)
        defaults = c.value(.defaults, or: d.defaults)
    }

    /// Decodes a config file, falling back to defaults on any problem.
    public static func decode(_ data: Data) -> AppConfig {
        (try? JSONDecoder().decode(AppConfig.self, from: data)) ?? AppConfig()
    }
}

/// The menu bar deliberately has no colour of its own: the digits use the
/// system label colour, so they stay legible in light and dark and invert
/// correctly while the item is clicked. Phase colour lives on the ring only.
public struct MenuBarConfig: Codable, Equatable, Sendable {
    public var fontSize: Double
    /// Keeps the width steady as the digits change.
    public var monospacedDigits: Bool

    public init(
        fontSize: Double = 13,
        monospacedDigits: Bool = true
    ) {
        self.fontSize = fontSize
        self.monospacedDigits = monospacedDigits
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = MenuBarConfig()
        fontSize = c.value(.fontSize, or: d.fontSize)
        monospacedDigits = c.value(.monospacedDigits, or: d.monospacedDigits)
    }
}

public struct PopoverConfig: Codable, Equatable, Sendable {
    public var width: Double
    public var height: Double
    public var backgroundColor: String
    public var secondaryTextColor: String

    public init(
        width: Double = 260,
        height: Double = 300,
        backgroundColor: String = "#2F2F2F",
        secondaryTextColor: String = "#9B9B9B"
    ) {
        self.width = width
        self.height = height
        self.backgroundColor = backgroundColor
        self.secondaryTextColor = secondaryTextColor
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PopoverConfig()
        width = c.value(.width, or: d.width)
        height = c.value(.height, or: d.height)
        backgroundColor = c.value(.backgroundColor, or: d.backgroundColor)
        secondaryTextColor = c.value(.secondaryTextColor, or: d.secondaryTextColor)
    }
}

public struct RingConfig: Codable, Equatable, Sendable {
    public var diameter: Double
    public var lineWidth: Double
    public var handleDiameter: Double
    public var trackColor: String
    public var workColor: String
    public var breakColor: String
    public var timeFontSize: Double

    public init(
        diameter: Double = 170,
        lineWidth: Double = 6,
        handleDiameter: Double = 18,
        trackColor: String = "#4A4A4A",
        workColor: String = "#E5484D",
        breakColor: String = "#30A46C",
        timeFontSize: Double = 42
    ) {
        self.diameter = diameter
        self.lineWidth = lineWidth
        self.handleDiameter = handleDiameter
        self.trackColor = trackColor
        self.workColor = workColor
        self.breakColor = breakColor
        self.timeFontSize = timeFontSize
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = RingConfig()
        diameter = c.value(.diameter, or: d.diameter)
        lineWidth = c.value(.lineWidth, or: d.lineWidth)
        handleDiameter = c.value(.handleDiameter, or: d.handleDiameter)
        trackColor = c.value(.trackColor, or: d.trackColor)
        workColor = c.value(.workColor, or: d.workColor)
        breakColor = c.value(.breakColor, or: d.breakColor)
        timeFontSize = c.value(.timeFontSize, or: d.timeFontSize)
    }
}

public struct DialConfig: Codable, Equatable, Sendable {
    public var fullTurnMinutes: Double
    public var minMinutes: Double
    public var maxMinutes: Double
    public var stepMinutes: Double

    public init(
        fullTurnMinutes: Double = 60,
        minMinutes: Double = 1,
        maxMinutes: Double = 180,
        stepMinutes: Double = 1
    ) {
        self.fullTurnMinutes = fullTurnMinutes
        self.minMinutes = minMinutes
        self.maxMinutes = maxMinutes
        self.stepMinutes = stepMinutes
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = DialConfig()
        fullTurnMinutes = c.value(.fullTurnMinutes, or: d.fullTurnMinutes)
        minMinutes = c.value(.minMinutes, or: d.minMinutes)
        maxMinutes = c.value(.maxMinutes, or: d.maxMinutes)
        stepMinutes = c.value(.stepMinutes, or: d.stepMinutes)
    }

    public var dial: DurationDial {
        DurationDial(
            fullTurnMinutes: fullTurnMinutes,
            minMinutes: minMinutes,
            maxMinutes: maxMinutes,
            stepMinutes: stepMinutes
        )
    }
}
