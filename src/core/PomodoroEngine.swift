import Foundation

public enum EngineEvent: Equatable, Sendable {
    case phaseFinished(Phase)
    case phaseStarted(Phase)
}

/// Everything the engine knows, as plain values: what the Mac and the phone
/// send each other (docs/SYNC.md). `endsAt` is set only while running.
public struct EngineState: Equatable, Sendable {
    public var phase: Phase
    public var runState: RunState
    public var phaseDuration: TimeInterval
    public var remaining: TimeInterval
    public var endsAt: Date?
    public var completedToday: Int
    public var sinceLongBreak: Int
    /// The local date the count belongs to, "2026-10-23".
    public var day: String
    /// When the state last changed: a button, or the moment an interval ran out.
    public var changedAt: Date

    public static func initial(settings: IntervalSettings) -> EngineState {
        EngineState(
            phase: .work,
            runState: .idle,
            phaseDuration: settings.duration(for: .work),
            remaining: settings.duration(for: .work),
            endsAt: nil,
            completedToday: 0,
            sinceLongBreak: 0,
            day: "",
            changedAt: Date(timeIntervalSince1970: 0)
        )
    }
}

public struct PomodoroEngine: Equatable, Sendable {
    public var settings: IntervalSettings
    public var autoStartNextInterval: Bool

    public private(set) var state: EngineState

    public init(
        settings: IntervalSettings = IntervalSettings(),
        autoStartNextInterval: Bool = false
    ) {
        self.settings = settings
        self.autoStartNextInterval = autoStartNextInterval
        self.state = .initial(settings: settings)
    }

    public var phase: Phase { state.phase }
    public var runState: RunState { state.runState }
    public var phaseDuration: TimeInterval { state.phaseDuration }
    public var remaining: TimeInterval { state.remaining }
    public var completedToday: Int { state.completedToday }

    public mutating func start(now: Date = Date()) {
        guard runState != .running else { return }
        if remaining <= 0 { state.remaining = phaseDuration }
        state.endsAt = now.addingTimeInterval(remaining)
        state.runState = .running
        state.changedAt = now
    }

    public mutating func pause(now: Date = Date()) {
        guard runState == .running else { return }
        state.remaining = max(0, (state.endsAt ?? now).timeIntervalSince(now))
        state.endsAt = nil
        state.runState = .paused
        state.changedAt = now
    }

    public mutating func toggle(now: Date = Date()) {
        runState == .running ? pause(now: now) : start(now: now)
    }

    public mutating func stop(now: Date = Date()) {
        state.runState = .idle
        state.endsAt = nil
        state.phaseDuration = settings.duration(for: phase)
        state.remaining = phaseDuration
        state.changedAt = now
    }

    /// Work counts even when finished early, or never started at all: this is
    /// how the user adds an interval worked without the timer. Dropping work
    /// without counting it is stop().
    public mutating func skip(now: Date = Date()) -> [EngineEvent] {
        advance(now: now, changedAt: now)
    }

    public mutating func setPhaseDuration(_ seconds: TimeInterval, now: Date = Date()) {
        state.phaseDuration = max(1, seconds)
        state.remaining = phaseDuration
        state.endsAt = runState == .running ? now.addingTimeInterval(remaining) : nil
        state.changedAt = now
    }

    public mutating func applySettings(_ new: IntervalSettings, now: Date = Date()) {
        settings = new
        guard runState == .idle, new.duration(for: phase) != phaseDuration else { return }
        state.phaseDuration = new.duration(for: phase)
        state.remaining = phaseDuration
        state.changedAt = now
    }

    /// Resets the daily count the first time it is called on a new day.
    public mutating func rollOverDay(_ day: String) {
        guard day != state.day else { return }
        state.day = day
        state.completedToday = 0
        state.sinceLongBreak = 0
    }

    /// The other device's state, already on this Mac's clock. Plays nothing:
    /// the device where the change happened did that.
    public mutating func adopt(_ new: EngineState) {
        state = new
    }

    public mutating func update(now: Date = Date()) -> [EngineEvent] {
        guard runState == .running, let endsAt = state.endsAt else { return [] }
        state.remaining = max(0, endsAt.timeIntervalSince(now))
        guard remaining <= 0 else { return [] }
        // Changed at the moment it ran out, not at the tick that noticed:
        // the phone gets the same time. The next interval starts now, though,
        // so a Mac that slept through several does not replay them all.
        return advance(now: now, changedAt: endsAt)
    }

    private mutating func advance(now: Date, changedAt: Date) -> [EngineEvent] {
        let finished = phase
        if finished == .work {
            state.completedToday += 1
            state.sinceLongBreak += 1
        }

        let next: Phase
        if finished == .work {
            let due = settings.longBreakAfter > 0 && state.sinceLongBreak >= settings.longBreakAfter
            next = due ? .longBreak : .shortBreak
            if due { state.sinceLongBreak = 0 }
        } else {
            next = .work
        }

        state.phase = next
        state.phaseDuration = settings.duration(for: next)
        state.remaining = phaseDuration
        state.runState = autoStartNextInterval ? .running : .idle
        state.endsAt = autoStartNextInterval ? now.addingTimeInterval(remaining) : nil
        state.changedAt = changedAt
        return [.phaseFinished(finished), .phaseStarted(next)]
    }
}
