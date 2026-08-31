import Foundation

/// Something worth reacting to — a sound, a notification, a redraw.
public enum EngineEvent: Equatable, Sendable {
    /// A phase ran out of time. Carries the phase that just ended.
    case phaseFinished(Phase)
    /// A new phase became current, either automatically or by skipping.
    case phaseStarted(Phase)
}

/// The whole timer, as a value type.
///
/// Deliberately knows nothing about clocks: every method that depends on the
/// current time takes `now` as a parameter, so tests drive it with fixed dates
/// instead of sleeping. The UI layer owns the real clock and calls `update`.
public struct PomodoroEngine: Equatable, Sendable {

    public var settings: IntervalSettings
    /// Start the following phase without waiting for the user to press play.
    public var autoStartNextInterval: Bool

    public private(set) var phase: Phase
    public private(set) var runState: RunState
    /// Full length of the current phase. Editing the timer changes this.
    public private(set) var phaseDuration: TimeInterval
    /// Seconds left. Only meaningful together with `runState`.
    public private(set) var remaining: TimeInterval
    /// Work intervals finished today. Reset by `resetDailyCount`.
    public private(set) var completedToday: Int

    /// Wall-clock moment the current phase ends. Nil unless running.
    private var endsAt: Date?
    /// Work intervals finished since the last long break, for the cycle rule.
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

    // MARK: - Derived state

    /// 0 at the start of a phase, 1 when it runs out. Drives the ring.
    public var progress: Double {
        guard phaseDuration > 0 else { return 0 }
        return min(max(1 - remaining / phaseDuration, 0), 1)
    }

    /// True only while work is actively counting down — the red menu bar state.
    public var isWorking: Bool {
        phase == .work && runState == .running
    }

    // MARK: - Commands

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

    /// Back to the beginning of the current phase, stopped.
    public mutating func stop() {
        runState = .idle
        endsAt = nil
        remaining = phaseDuration
    }

    /// Move to the next phase without finishing this one. Does not count as a
    /// completed work interval — an abandoned pomodoro is not a pomodoro.
    public mutating func skip(now: Date = Date()) -> [EngineEvent] {
        advance(countingCompletion: false, now: now)
    }

    /// Change the length of the current phase, e.g. by dragging the ring or
    /// typing over the digits. Clamped to the allowed range by the caller.
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

    /// Re-read durations after the user edited them in Settings. The current
    /// phase is only resized when it is not mid-countdown, so a running timer
    /// is never yanked out from under the user.
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

    // MARK: - Clock

    /// Called on every tick. Returns what happened, if anything.
    public mutating func update(now: Date = Date()) -> [EngineEvent] {
        guard runState == .running, let endsAt else { return [] }
        remaining = max(0, endsAt.timeIntervalSince(now))
        guard remaining <= 0 else { return [] }
        return advance(countingCompletion: true, now: now)
    }

    // MARK: - Transitions

    /// The one place that decides what comes after what.
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
