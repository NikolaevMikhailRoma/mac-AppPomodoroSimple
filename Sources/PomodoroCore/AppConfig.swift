import Foundation

public struct AppConfig: Codable, Equatable, Sendable {
    public var menuBar: MenuBarConfig
    public var popover: PopoverConfig
    public var ring: RingConfig
    public var fonts: FontsConfig
    public var settingsWindow: SettingsWindowConfig
    public var dial: DialConfig
    public var defaults: IntervalSettings

    public init(
        menuBar: MenuBarConfig = MenuBarConfig(),
        popover: PopoverConfig = PopoverConfig(),
        ring: RingConfig = RingConfig(),
        fonts: FontsConfig = FontsConfig(),
        settingsWindow: SettingsWindowConfig = SettingsWindowConfig(),
        dial: DialConfig = DialConfig(),
        defaults: IntervalSettings = IntervalSettings()
    ) {
        self.menuBar = menuBar
        self.popover = popover
        self.ring = ring
        self.fonts = fonts
        self.settingsWindow = settingsWindow
        self.dial = dial
        self.defaults = defaults
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppConfig()
        menuBar = c.value(.menuBar, or: d.menuBar)
        popover = c.value(.popover, or: d.popover)
        ring = c.value(.ring, or: d.ring)
        fonts = c.value(.fonts, or: d.fonts)
        settingsWindow = c.value(.settingsWindow, or: d.settingsWindow)
        dial = c.value(.dial, or: d.dial)
        defaults = c.value(.defaults, or: d.defaults)
    }

    public static func decode(_ data: Data) -> AppConfig {
        (try? JSONDecoder().decode(AppConfig.self, from: data)) ?? AppConfig()
    }
}

public struct FontToken: Codable, Equatable, Sendable {
    public var name: String
    public var size: Double

    public init(name: String, size: Double) {
        self.name = name
        self.size = size
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = FontToken(name: "HelveticaNeue-Light", size: 13)
        name = c.value(.name, or: d.name)
        size = c.value(.size, or: d.size)
    }
}

public struct FontsConfig: Codable, Equatable, Sendable {
    public var digits: FontToken
    public var counter: FontToken
    public var phase: FontToken

    public init(
        digits: FontToken = FontToken(name: "HelveticaNeue-Thin", size: 55),
        counter: FontToken = FontToken(name: "HelveticaNeue-Light", size: 20),
        phase: FontToken = FontToken(name: "HelveticaNeue-Light", size: 15)
    ) {
        self.digits = digits
        self.counter = counter
        self.phase = phase
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = FontsConfig()
        digits = c.value(.digits, or: d.digits)
        counter = c.value(.counter, or: d.counter)
        phase = c.value(.phase, or: d.phase)
    }
}

public struct MenuBarConfig: Codable, Equatable, Sendable {
    public var fontSize: Double
    public var fontWeight: String
    public var monospacedDigits: Bool
    public var icon: MenuBarIconConfig

    public init(
        fontSize: Double = 14,
        fontWeight: String = "regular",
        monospacedDigits: Bool = true,
        icon: MenuBarIconConfig = MenuBarIconConfig()
    ) {
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.monospacedDigits = monospacedDigits
        self.icon = icon
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = MenuBarConfig()
        fontSize = c.value(.fontSize, or: d.fontSize)
        fontWeight = c.value(.fontWeight, or: d.fontWeight)
        monospacedDigits = c.value(.monospacedDigits, or: d.monospacedDigits)
        icon = c.value(.icon, or: d.icon)
    }
}

public struct MenuBarIconConfig: Codable, Equatable, Sendable {
    public var symbolName: String
    public var size: Double
    public var weight: String
    public var workColor: String
    public var breakColor: String
    public var idleColor: String

    public init(
        symbolName: String = "timer",
        size: Double = 15,
        weight: String = "light",
        workColor: String = "#E62621",
        breakColor: String = "#30A46C",
        idleColor: String = "#9B9B9B"
    ) {
        self.symbolName = symbolName
        self.size = size
        self.weight = weight
        self.workColor = workColor
        self.breakColor = breakColor
        self.idleColor = idleColor
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = MenuBarIconConfig()
        symbolName = c.value(.symbolName, or: d.symbolName)
        size = c.value(.size, or: d.size)
        weight = c.value(.weight, or: d.weight)
        workColor = c.value(.workColor, or: d.workColor)
        breakColor = c.value(.breakColor, or: d.breakColor)
        idleColor = c.value(.idleColor, or: d.idleColor)
    }
}

public struct PopoverConfig: Codable, Equatable, Sendable {
    public var width: Double
    public var height: Double
    public var padding: Double
    public var closeButtonInset: Double
    public var headerHeight: Double
    public var headerToRing: Double
    public var ringToFooter: Double
    public var footerHeight: Double
    public var background: String
    public var textSecondary: String
    public var textDim: String

    public init(
        width: Double = 256,
        height: Double = 335,
        padding: Double = 14,
        closeButtonInset: Double = 24,
        headerHeight: Double = 22,
        headerToRing: Double = 39,
        ringToFooter: Double = 28,
        footerHeight: Double = 22,
        background: String = "#252525",
        textSecondary: String = "#C8C8C8",
        textDim: String = "#646464"
    ) {
        self.width = width
        self.height = height
        self.padding = padding
        self.closeButtonInset = closeButtonInset
        self.headerHeight = headerHeight
        self.headerToRing = headerToRing
        self.ringToFooter = ringToFooter
        self.footerHeight = footerHeight
        self.background = background
        self.textSecondary = textSecondary
        self.textDim = textDim
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PopoverConfig()
        width = c.value(.width, or: d.width)
        height = c.value(.height, or: d.height)
        padding = c.value(.padding, or: d.padding)
        closeButtonInset = c.value(.closeButtonInset, or: d.closeButtonInset)
        headerHeight = c.value(.headerHeight, or: d.headerHeight)
        headerToRing = c.value(.headerToRing, or: d.headerToRing)
        ringToFooter = c.value(.ringToFooter, or: d.ringToFooter)
        footerHeight = c.value(.footerHeight, or: d.footerHeight)
        background = c.value(.background, or: d.background)
        textSecondary = c.value(.textSecondary, or: d.textSecondary)
        textDim = c.value(.textDim, or: d.textDim)
    }
}

public struct RingConfig: Codable, Equatable, Sendable {
    public var diameter: Double
    public var lineWidth: Double
    public var handleDiameter: Double
    public var handleLineWidth: Double
    public var trackColor: String
    public var workColor: String
    public var breakColor: String
    public var digitsOffset: Double
    public var playOffset: Double
    public var playSide: Double
    public var playLineWidth: Double
    public var closeButtonSize: Double

    public init(
        diameter: Double = 196,
        lineWidth: Double = 4,
        handleDiameter: Double = 22,
        handleLineWidth: Double = 2,
        trackColor: String = "#3D3D3D",
        workColor: String = "#EC958C",
        breakColor: String = "#8CD3A2",
        digitsOffset: Double = -9.5,
        playOffset: Double = 57.75,
        playSide: Double = 34,
        playLineWidth: Double = 1,
        closeButtonSize: Double = 22
    ) {
        self.diameter = diameter
        self.lineWidth = lineWidth
        self.handleDiameter = handleDiameter
        self.handleLineWidth = handleLineWidth
        self.trackColor = trackColor
        self.workColor = workColor
        self.breakColor = breakColor
        self.digitsOffset = digitsOffset
        self.playOffset = playOffset
        self.playSide = playSide
        self.playLineWidth = playLineWidth
        self.closeButtonSize = closeButtonSize
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = RingConfig()
        diameter = c.value(.diameter, or: d.diameter)
        lineWidth = c.value(.lineWidth, or: d.lineWidth)
        handleDiameter = c.value(.handleDiameter, or: d.handleDiameter)
        handleLineWidth = c.value(.handleLineWidth, or: d.handleLineWidth)
        trackColor = c.value(.trackColor, or: d.trackColor)
        workColor = c.value(.workColor, or: d.workColor)
        breakColor = c.value(.breakColor, or: d.breakColor)
        digitsOffset = c.value(.digitsOffset, or: d.digitsOffset)
        playOffset = c.value(.playOffset, or: d.playOffset)
        playSide = c.value(.playSide, or: d.playSide)
        playLineWidth = c.value(.playLineWidth, or: d.playLineWidth)
        closeButtonSize = c.value(.closeButtonSize, or: d.closeButtonSize)
    }

    public func accent(for phase: Phase) -> String {
        phase == .work ? workColor : breakColor
    }
}

public struct SettingsWindowConfig: Codable, Equatable, Sendable {
    public var width: Double
    public var height: Double
    public var boxMargin: Double
    public var boxPadding: Double
    public var rowHeight: Double
    public var controlWidth: Double
    public var tabBarHeight: Double
    public var tabBackground: String
    public var tabSelectedFill: String
    public var tabDivider: String
    public var tabTextColor: String
    public var tabTextSize: Double
    public var cornerRadius: Double
    public var windowBackground: String
    public var boxBackground: String
    public var boxBorder: String
    public var labelColor: String
    public var sectionHeaderColor: String
    public var labelSize: Double
    public var sectionHeaderSize: Double

    public init(
        width: Double = 540,
        height: Double = 400,
        boxMargin: Double = 20,
        boxPadding: Double = 24,
        rowHeight: Double = 27,
        controlWidth: Double = 119,
        tabBarHeight: Double = 22,
        tabBackground: String = "#333333",
        tabSelectedFill: String = "#666666",
        tabDivider: String = "#2B2B2B",
        tabTextColor: String = "#E0E0E0",
        tabTextSize: Double = 13,
        cornerRadius: Double = 4,
        windowBackground: String = "#303132",
        boxBackground: String = "#373738",
        boxBorder: String = "#505051",
        labelColor: String = "#D1D1D1",
        sectionHeaderColor: String = "#8C8C8C",
        labelSize: Double = 15,
        sectionHeaderSize: Double = 13
    ) {
        self.width = width
        self.height = height
        self.boxMargin = boxMargin
        self.boxPadding = boxPadding
        self.rowHeight = rowHeight
        self.controlWidth = controlWidth
        self.tabBarHeight = tabBarHeight
        self.tabBackground = tabBackground
        self.tabSelectedFill = tabSelectedFill
        self.tabDivider = tabDivider
        self.tabTextColor = tabTextColor
        self.tabTextSize = tabTextSize
        self.cornerRadius = cornerRadius
        self.windowBackground = windowBackground
        self.boxBackground = boxBackground
        self.boxBorder = boxBorder
        self.labelColor = labelColor
        self.sectionHeaderColor = sectionHeaderColor
        self.labelSize = labelSize
        self.sectionHeaderSize = sectionHeaderSize
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = SettingsWindowConfig()
        width = c.value(.width, or: d.width)
        height = c.value(.height, or: d.height)
        boxMargin = c.value(.boxMargin, or: d.boxMargin)
        boxPadding = c.value(.boxPadding, or: d.boxPadding)
        rowHeight = c.value(.rowHeight, or: d.rowHeight)
        controlWidth = c.value(.controlWidth, or: d.controlWidth)
        tabBarHeight = c.value(.tabBarHeight, or: d.tabBarHeight)
        tabBackground = c.value(.tabBackground, or: d.tabBackground)
        tabSelectedFill = c.value(.tabSelectedFill, or: d.tabSelectedFill)
        tabDivider = c.value(.tabDivider, or: d.tabDivider)
        tabTextColor = c.value(.tabTextColor, or: d.tabTextColor)
        tabTextSize = c.value(.tabTextSize, or: d.tabTextSize)
        cornerRadius = c.value(.cornerRadius, or: d.cornerRadius)
        windowBackground = c.value(.windowBackground, or: d.windowBackground)
        boxBackground = c.value(.boxBackground, or: d.boxBackground)
        boxBorder = c.value(.boxBorder, or: d.boxBorder)
        labelColor = c.value(.labelColor, or: d.labelColor)
        sectionHeaderColor = c.value(.sectionHeaderColor, or: d.sectionHeaderColor)
        labelSize = c.value(.labelSize, or: d.labelSize)
        sectionHeaderSize = c.value(.sectionHeaderSize, or: d.sectionHeaderSize)
    }
}

public struct DialConfig: Codable, Equatable, Sendable {
    public var fullTurnMinutes: Double
    public var minSeconds: Double
    public var maxSeconds: Double
    public var dragStepSeconds: Double

    public init(
        fullTurnMinutes: Double = 60,
        minSeconds: Double = 1,
        maxSeconds: Double = 10_800,
        dragStepSeconds: Double = 5
    ) {
        self.fullTurnMinutes = fullTurnMinutes
        self.minSeconds = minSeconds
        self.maxSeconds = maxSeconds
        self.dragStepSeconds = dragStepSeconds
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = DialConfig()
        fullTurnMinutes = c.value(.fullTurnMinutes, or: d.fullTurnMinutes)
        minSeconds = c.value(.minSeconds, or: d.minSeconds)
        maxSeconds = c.value(.maxSeconds, or: d.maxSeconds)
        dragStepSeconds = c.value(.dragStepSeconds, or: d.dragStepSeconds)
    }

    public var dial: DurationDial {
        DurationDial(
            fullTurnMinutes: fullTurnMinutes,
            minSeconds: minSeconds,
            maxSeconds: maxSeconds,
            dragStepSeconds: dragStepSeconds
        )
    }
}
