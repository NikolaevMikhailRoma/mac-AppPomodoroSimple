import Foundation

public enum Phase: String, Codable, CaseIterable, Sendable {
    case work
    case shortBreak
    case longBreak

    public var title: String {
        switch self {
        case .work: return "Work"
        case .shortBreak: return "Short break"
        case .longBreak: return "Long break"
        }
    }
}

public enum RunState: String, Codable, Sendable {
    case idle
    case running
    case paused
}
