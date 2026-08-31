import Foundation

/// The three kinds of interval a pomodoro cycle moves through.
public enum Phase: String, Codable, CaseIterable, Sendable {
    case work
    case shortBreak
    case longBreak

    /// True for everything that is not focused work.
    public var isBreak: Bool { self != .work }

    public var title: String {
        switch self {
        case .work: return "Work"
        case .shortBreak: return "Short break"
        case .longBreak: return "Long break"
        }
    }
}

/// Whether the countdown is currently moving.
public enum RunState: String, Codable, Sendable {
    case idle      // stopped, sitting at the full phase duration
    case running
    case paused
}
