import Foundation
import PomodoroCore

/// The shape of `config.json`.
///
/// Every default sits in the property declaration itself; there is no second
/// place to repeat it. `JSONValue.merged` keeps parsing lenient: a missing key,
/// or one with the wrong type, loses only itself.
///
/// Adding a value = a property here + a line in `Resources/config.json`.
public struct AppConfig: Codable, Equatable, Sendable {
    /// Named colours. Every colour field in the other sections takes either a
    /// name from here or a literal `#RRGGBB` — see `JSONValue.resolvingPalette`.
    public var palette = Palette.defaults
    /// Every icon in the app. These are system SF Symbols; there are no image files.
    public var icons = IconsConfig()
    public var menuBar = MenuBarConfig()
    public var popover = PopoverConfig()
    public var ring = RingConfig()
    public var fonts = FontsConfig()
    public var settingsWindow = SettingsWindowConfig()
    public var dial = DialConfig()
    /// Durations for the first launch, until the user changes them in settings.
    public var intervals = IntervalSettings()

    public init() {}

    /// Parses the file over the defaults and resolves palette names. An
    /// unreadable file gives the defaults whole.
    public static func decode(_ data: Data) -> AppConfig {
        let fallback = AppConfig()
        guard let baseData = try? JSONEncoder().encode(fallback),
              let base = try? JSONDecoder().decode(JSONValue.self, from: baseData),
              let user = try? JSONDecoder().decode(JSONValue.self, from: data),
              let resolved = try? JSONEncoder().encode(
                  JSONValue.resolvingPalette(JSONValue.merged(base, user))
              ),
              let config = try? JSONDecoder().decode(AppConfig.self, from: resolved)
        else { return fallback }
        return config
    }

    /// `config.json` ships as a resource of this target. A missing file gives the defaults.
    public static func load() -> AppConfig {
        guard let url = resourceBundle?.url(forResource: "config", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return AppConfig() }
        return decode(data)
    }

    /// Not `Bundle.module`: it looks in the root of the `.app`, where the
    /// signature won't let the bundle sit, then in the build machine's `.build`,
    /// and otherwise calls `fatalError`. So the app worked only where it was built.
    ///
    /// Looked for in `Contents/Resources` of the `.app`, next to the executable
    /// (`swift run`) and next to the test bundle (`swift test`).
    private static let resourceBundle: Bundle? = {
        let name = "Pomodoro_PomodoroConfig.bundle"
        let places = [
            Bundle.main.resourceURL,
            Bundle.main.bundleURL,
            Bundle(for: BundleToken.self).bundleURL.deletingLastPathComponent(),
        ]
        return places.lazy
            .compactMap { $0.flatMap { Bundle(url: $0.appendingPathComponent(name)) } }
            .first
    }()
}

private final class BundleToken {}

/// The palette is a plain dictionary, so a new colour is one line of JSON and
/// no Swift at all. The defaults here give the app a full set of colours even
/// with no file.
public enum Palette {
    public static let defaults: [String: String] = [
        // Phase colours. The menu bar icon is saturated and the ring arc is
        // lighter, as in the original; neither is derived from the other.
        "work": "#E62621",
        "workSoft": "#EC958C",
        "break": "#30A46C",
        "breakSoft": "#8CD3A2",
        // Timer stopped.
        "idle": "#9B9B9B",
    ]
}

/// An icon: system symbol name, size and weight. One type for every use —
/// menu bar, gear, skip, close.
public struct IconConfig: Codable, Equatable, Sendable {
    public var symbol: String
    public var size: Double
    public var weight: String

    public init(symbol: String, size: Double, weight: String = "regular") {
        self.symbol = symbol
        self.size = size
        self.weight = weight
    }
}

public struct IconsConfig: Codable, Equatable, Sendable {
    /// Menu bar. The weight is measured off the original: regular is a pixel thicker.
    public var menuBar = IconConfig(symbol: "timer", size: 15, weight: "light")
    /// The gear in the popover footer.
    public var settings = IconConfig(symbol: "gearshape", size: 18, weight: "ultralight")
    /// Left of the popover footer, opposite the gear: straight to the next interval.
    public var skip = IconConfig(symbol: "forward.end", size: 18, weight: "ultralight")
    /// The cross in the popover header: stops the timer and resets the phase.
    public var reset = IconConfig(symbol: "xmark.circle", size: 22, weight: "ultralight")

    public init() {}
}

/// A font as the config states it: PostScript name and size.
public struct FontToken: Codable, Equatable, Sendable {
    public var name: String
    public var size: Double

    public init(name: String = "HelveticaNeue-Light", size: Double = 13) {
        self.name = name
        self.size = size
    }
}

/// Popover fonts. The menu bar and the settings window take the system font
/// and set only a size, so they need no entries of their own.
public struct FontsConfig: Codable, Equatable, Sendable {
    public var digits = FontToken(name: "HelveticaNeue-Thin", size: 55)
    /// `Today N` in the footer.
    public var counter = FontToken(name: "HelveticaNeue-Light", size: 20)
    /// `Max 59:59` under the digits when the typed value is over the limit.
    public var hint = FontToken(name: "HelveticaNeue-Light", size: 13)
    /// The phase name in the header.
    public var phase = FontToken(name: "HelveticaNeue-Light", size: 15)

    public init() {}
}

/// The range and step of the round time dial.
public struct DialConfig: Codable, Equatable, Sendable {
    public var fullTurnMinutes = 60.0
    public var minSeconds = 1.0
    /// 59:59. An hour and over reads as 1:00:00 — one character wider, and the
    /// digits stop fitting inside the ring.
    public var maxSeconds = 3_599.0
    /// The drag step. One point of arc is about 5.8 seconds, so anything finer
    /// than 5 stops being repeatable. Typed input is not rounded.
    public var dragStepSeconds = 5.0

    public init() {}

    public var dial: DurationDial {
        DurationDial(
            fullTurnMinutes: fullTurnMinutes,
            minSeconds: minSeconds,
            maxSeconds: maxSeconds,
            dragStepSeconds: dragStepSeconds
        )
    }
}
