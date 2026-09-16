import Foundation

public enum EngineEvent: Equatable, Sendable {
    case phaseFinished(Phase)
    case phaseStarted(Phase)
}

public struct PomodoroEngine: Equatable, Sendable {
    public var settings: IntervalSettings
    public var autoStartNextInterval: Bool

    public private(set) var phase: Phase
    public private(set) var runState: RunState
    public private(set) var phaseDuration: TimeInterval
    public private(set) var remaining: TimeInterval
    public private(set) var completedToday: Int

    private var endsAt: Date?
    private var sinceLongBreak: Int

    public init(
        settings: IntervalSettings = IntervalSettings(),
        autoStartNextInterval: Bool = false
    ) {
        self.settings = settings
        self.autoStartNextInterval = autoStartNextInterval
        self.phase = .work
        self.runState = .idle
        self.phaseDuration = settings.duration(for: .work)
        self.remaining = settings.duration(for: .work)
        self.completedToday = 0
        self.endsAt = nil
        self.sinceLongBreak = 0
    }

    public var progress: Double {
        guard phaseDuration > 0 else { return 0 }
        return min(max(1 - remaining / phaseDuration, 0), 1)
    }

    public var isWorking: Bool {
        phase == .work && runState == .running
    }

    public mutating func start(now: Date = Date()) {
        guard runState != .running else { return }
        if remaining <= 0 { remaining = phaseDuration }
        endsAt = now.addingTimeInterval(remaining)
        runState = .running
    }

    public mutating func pause(now: Date = Date()) {
        guard runState == .running else { return }
        remaining = max(0, (endsAt ?? now).timeIntervalSince(now))
        endsAt = nil
        runState = .paused
    }

    public mutating func toggle(now: Date = Date()) {
        runState == .running ? pause(now: now) : start(now: now)
    }

    public mutating func stop() {
        runState = .idle
        endsAt = nil
        phaseDuration = settings.duration(for: phase)
        remaining = phaseDuration
    }

    /// Работа засчитывается даже досрочно или вовсе не запущенная: так
    /// пользователь добавляет интервал, отработанный без таймера. Бросить
    /// работу без засчёта — это stop().
    public mutating func skip(now: Date = Date()) -> [EngineEvent] {
        advance(countingCompletion: true, now: now)
    }

    public mutating func setPhaseDuration(_ seconds: TimeInterval, now: Date = Date()) {
        let wasRunning = runState == .running
        phaseDuration = max(1, seconds)
        remaining = phaseDuration
        if wasRunning {
            endsAt = now.addingTimeInterval(remaining)
        } else {
            endsAt = nil
        }
    }

    public mutating func applySettings(_ new: IntervalSettings) {
        settings = new
        if runState == .idle {
            phaseDuration = new.duration(for: phase)
            remaining = phaseDuration
        }
    }

    public mutating func resetDailyCount() {
        completedToday = 0
        sinceLongBreak = 0
    }

    public mutating func update(now: Date = Date()) -> [EngineEvent] {
        guard runState == .running, let endsAt else { return [] }
        remaining = max(0, endsAt.timeIntervalSince(now))
        guard remaining <= 0 else { return [] }
        return advance(countingCompletion: true, now: now)
    }

    private mutating func advance(countingCompletion: Bool, now: Date) -> [EngineEvent] {
        let finished = phase
        var events: [EngineEvent] = [.phaseFinished(finished)]

        if finished == .work && countingCompletion {
            completedToday += 1
            sinceLongBreak += 1
        }

        let next: Phase
        if finished == .work {
            let due = settings.longBreakAfter > 0 && sinceLongBreak >= settings.longBreakAfter
            next = due ? .longBreak : .shortBreak
            if due { sinceLongBreak = 0 }
        } else {
            next = .work
        }

        phase = next
        phaseDuration = settings.duration(for: next)
        remaining = phaseDuration
        events.append(.phaseStarted(next))

        if autoStartNextInterval {
            endsAt = now.addingTimeInterval(remaining)
            runState = .running
        } else {
            endsAt = nil
            runState = .idle
        }
        return events
    }
}
