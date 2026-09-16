import Foundation

public struct Settings: Codable, Equatable, Sendable {
    public var general: GeneralSettings
    public var intervals: IntervalSettings
    public var sound: SoundSettings

    public init(
        general: GeneralSettings = GeneralSettings(),
        intervals: IntervalSettings = IntervalSettings(),
        sound: SoundSettings = SoundSettings()
    ) {
        self.general = general
        self.intervals = intervals
        self.sound = sound
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        general = c.value(.general, or: d.general)
        intervals = c.value(.intervals, or: d.intervals)
        sound = c.value(.sound, or: d.sound)
    }
}

public enum Appearance: String, Codable, CaseIterable, Sendable {
    case auto, light, dark

    public var title: String {
        switch self {
        case .auto: return "Auto"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

public struct GeneralSettings: Codable, Equatable, Sendable {
    public var appearance: Appearance
    public var showTimerInMenuBar: Bool
    public var autoStartNextInterval: Bool

    public init(
        appearance: Appearance = .auto,
        showTimerInMenuBar: Bool = true,
        autoStartNextInterval: Bool = false
    ) {
        self.appearance = appearance
        self.showTimerInMenuBar = showTimerInMenuBar
        self.autoStartNextInterval = autoStartNextInterval
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = GeneralSettings()
        appearance = c.value(.appearance, or: d.appearance)
        showTimerInMenuBar = c.value(.showTimerInMenuBar, or: d.showTimerInMenuBar)
        autoStartNextInterval = c.value(.autoStartNextInterval, or: d.autoStartNextInterval)
    }
}

public struct IntervalSettings: Codable, Equatable, Sendable {
    public var workMinutes: Double
    public var shortBreakMinutes: Double
    public var longBreakMinutes: Double
    public var longBreakAfter: Int

    public init(
        workMinutes: Double = 25,
        shortBreakMinutes: Double = 5,
        longBreakMinutes: Double = 15,
        longBreakAfter: Int = 4
    ) {
        self.workMinutes = workMinutes
        self.shortBreakMinutes = shortBreakMinutes
        self.longBreakMinutes = longBreakMinutes
        self.longBreakAfter = longBreakAfter
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = IntervalSettings()
        workMinutes = c.value(.workMinutes, or: d.workMinutes)
        shortBreakMinutes = c.value(.shortBreakMinutes, or: d.shortBreakMinutes)
        longBreakMinutes = c.value(.longBreakMinutes, or: d.longBreakMinutes)
        longBreakAfter = c.value(.longBreakAfter, or: d.longBreakAfter)
    }

    public func duration(for phase: Phase) -> TimeInterval {
        switch phase {
        case .work: return workMinutes * 60
        case .shortBreak: return shortBreakMinutes * 60
        case .longBreak: return longBreakMinutes * 60
        }
    }
}

public struct SoundSettings: Codable, Equatable, Sendable {
    public var workCompletedSound: String
    public var breakEndedSound: String
    public var soundEnabled: Bool
    public var notificationsEnabled: Bool
    public var volume: Double

    public init(
        workCompletedSound: String = "Glass",
        breakEndedSound: String = "Ping",
        soundEnabled: Bool = true,
        notificationsEnabled: Bool = true,
        volume: Double = 0.7
    ) {
        self.workCompletedSound = workCompletedSound
        self.breakEndedSound = breakEndedSound
        self.soundEnabled = soundEnabled
        self.notificationsEnabled = notificationsEnabled
        self.volume = volume
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = SoundSettings()
        workCompletedSound = c.value(.workCompletedSound, or: d.workCompletedSound)
        breakEndedSound = c.value(.breakEndedSound, or: d.breakEndedSound)
        soundEnabled = c.value(.soundEnabled, or: d.soundEnabled)
        notificationsEnabled = c.value(.notificationsEnabled, or: d.notificationsEnabled)
        volume = c.value(.volume, or: d.volume)
    }

    public func sound(afterFinishing phase: Phase) -> String {
        phase == .work ? workCompletedSound : breakEndedSound
    }
}
