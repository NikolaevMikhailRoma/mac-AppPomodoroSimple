import Testing
import Foundation
@testable import PomodoroCore

private let t0 = Date(timeIntervalSince1970: 1_000_000)

private func engine(
    work: Double = 25,
    short: Double = 5,
    long: Double = 15,
    longAfter: Int = 4,
    autoStart: Bool = false
) -> PomodoroEngine {
    PomodoroEngine(
        settings: IntervalSettings(
            workMinutes: work,
            shortBreakMinutes: short,
            longBreakMinutes: long,
            longBreakAfter: longAfter
        ),
        autoStartNextInterval: autoStart
    )
}

@Suite("Engine countdown")
struct CountdownTests {

    @Test("starts idle at the full work duration")
    func startsIdle() {
        let e = engine()
        #expect(e.phase == .work)
        #expect(e.runState == .idle)
        #expect(e.remaining == 25 * 60)
        #expect(e.progress == 0)
        #expect(e.isWorking == false)
    }

    @Test("counts down while running")
    func countsDown() {
        var e = engine()
        e.start(now: t0)
        #expect(e.isWorking)
        _ = e.update(now: t0.addingTimeInterval(60))
        #expect(e.remaining == 24 * 60)
        #expect(abs(e.progress - 1.0 / 25.0) < 0.0001)
    }

    @Test("pause freezes the remaining time regardless of wall clock")
    func pauseFreezes() {
        var e = engine()
        e.start(now: t0)
        e.pause(now: t0.addingTimeInterval(60))
        #expect(e.remaining == 24 * 60)
        #expect(e.runState == .paused)
        #expect(e.isWorking == false)

        // An hour passes while paused; nothing moves.
        _ = e.update(now: t0.addingTimeInterval(3600))
        #expect(e.remaining == 24 * 60)
    }

    @Test("resume continues from where it stopped")
    func resumeContinues() {
        var e = engine()
        e.start(now: t0)
        e.pause(now: t0.addingTimeInterval(60))
        e.start(now: t0.addingTimeInterval(3600))
        _ = e.update(now: t0.addingTimeInterval(3660))
        #expect(e.remaining == 23 * 60)
    }

    @Test("stop returns to the start of the phase")
    func stopResets() {
        var e = engine()
        e.start(now: t0)
        _ = e.update(now: t0.addingTimeInterval(600))
        e.stop()
        #expect(e.runState == .idle)
        #expect(e.remaining == 25 * 60)
    }
}

@Suite("Phase transitions")
struct TransitionTests {

    @Test("work runs out into a short break and counts one interval")
    func workToShortBreak() {
        var e = engine()
        e.start(now: t0)
        let events = e.update(now: t0.addingTimeInterval(25 * 60))
        #expect(events == [.phaseFinished(.work), .phaseStarted(.shortBreak)])
        #expect(e.phase == .shortBreak)
        #expect(e.remaining == 5 * 60)
        #expect(e.completedToday == 1)
        #expect(e.runState == .idle)   // autoStart is off
    }

    @Test("every fourth work interval leads to a long break")
    func longBreakOnFourth() {
        var e = engine(autoStart: true)
        var now = t0
        for cycle in 1...4 {
            e.start(now: now)
            now = now.addingTimeInterval(e.remaining)
            _ = e.update(now: now)
            #expect(e.completedToday == cycle)
            let expected: Phase = cycle == 4 ? .longBreak : .shortBreak
            #expect(e.phase == expected)
            // Run the break out too, so the next work interval begins.
            now = now.addingTimeInterval(e.remaining)
            _ = e.update(now: now)
            #expect(e.phase == .work)
        }
        #expect(e.completedToday == 4)
    }

    @Test("the long break counter restarts after a long break")
    func longBreakCounterRestarts() {
        var e = engine(longAfter: 2, autoStart: true)
        var now = t0
        var phases: [Phase] = []
        e.start(now: now)
        for _ in 0..<8 {
            now = now.addingTimeInterval(e.remaining)
            _ = e.update(now: now)
            phases.append(e.phase)
        }
        #expect(phases == [
            .shortBreak, .work, .longBreak, .work,
            .shortBreak, .work, .longBreak, .work,
        ])
    }

    @Test("autoStart keeps the next phase running")
    func autoStartRuns() {
        var e = engine(autoStart: true)
        e.start(now: t0)
        _ = e.update(now: t0.addingTimeInterval(25 * 60))
        #expect(e.runState == .running)
        #expect(e.phase == .shortBreak)
        _ = e.update(now: t0.addingTimeInterval(25 * 60 + 60))
        #expect(e.remaining == 4 * 60)
    }

    @Test("skipping does not count as a completed interval")
    func skipDoesNotCount() {
        var e = engine()
        e.start(now: t0)
        let events = e.skip(now: t0.addingTimeInterval(60))
        #expect(events == [.phaseFinished(.work), .phaseStarted(.shortBreak)])
        #expect(e.completedToday == 0)
        #expect(e.phase == .shortBreak)
    }

    @Test("a break ends back at work")
    func breakReturnsToWork() {
        var e = engine()
        e.start(now: t0)
        _ = e.update(now: t0.addingTimeInterval(25 * 60))
        e.start(now: t0.addingTimeInterval(25 * 60))
        _ = e.update(now: t0.addingTimeInterval(30 * 60))
        #expect(e.phase == .work)
        #expect(e.remaining == 25 * 60)
    }
}

@Suite("Editing the timer")
struct EditingTests {

    @Test("setting a duration while stopped resets the countdown")
    func setWhileStopped() {
        var e = engine()
        e.setPhaseDuration(40 * 60, now: t0)
        #expect(e.remaining == 40 * 60)
        #expect(e.phaseDuration == 40 * 60)
        #expect(e.runState == .idle)
    }

    @Test("setting a duration while running restarts from the new value")
    func setWhileRunning() {
        var e = engine()
        e.start(now: t0)
        _ = e.update(now: t0.addingTimeInterval(600))
        e.setPhaseDuration(40 * 60, now: t0.addingTimeInterval(600))
        #expect(e.runState == .running)
        #expect(e.remaining == 40 * 60)
        _ = e.update(now: t0.addingTimeInterval(660))
        #expect(e.remaining == 39 * 60)
    }

    @Test("new settings resize an idle phase but never a running one")
    func applySettings() {
        var idle = engine()
        idle.applySettings(IntervalSettings(workMinutes: 50))
        #expect(idle.remaining == 50 * 60)

        var running = engine()
        running.start(now: t0)
        _ = running.update(now: t0.addingTimeInterval(60))
        running.applySettings(IntervalSettings(workMinutes: 50))
        #expect(running.remaining == 24 * 60)
    }

    @Test("resetDailyCount clears the counter")
    func resetsCount() {
        var e = engine()
        e.start(now: t0)
        _ = e.update(now: t0.addingTimeInterval(25 * 60))
        #expect(e.completedToday == 1)
        e.resetDailyCount()
        #expect(e.completedToday == 0)
    }
}

@Suite("Time formatting")
struct TimeFormatTests {

    @Test("seconds render as mm:ss, and as h:mm:ss past an hour")
    func rendering() {
        #expect(TimeFormat.string(from: 0) == "00:00")
        #expect(TimeFormat.string(from: 59) == "00:59")
        #expect(TimeFormat.string(from: 25 * 60) == "25:00")
        #expect(TimeFormat.string(from: 3600) == "1:00:00")
        #expect(TimeFormat.string(from: 3661) == "1:01:01")
    }

    @Test("a partial second rounds up so the timer never shows 00:00 early")
    func roundsUp() {
        #expect(TimeFormat.string(from: 0.4) == "00:01")
    }

    // The expected values are written as Double: the result is an optional
    // TimeInterval, and #expect does not compare it against an integer
    // expression the way a plain `==` would.
    @Test("typed input is parsed in minutes, mm:ss or h:mm:ss")
    func parsing() {
        #expect(TimeFormat.seconds(from: "25") == 1500.0)
        #expect(TimeFormat.seconds(from: "25:30") == 1530.0)
        #expect(TimeFormat.seconds(from: "1:05:00") == 3900.0)
        #expect(TimeFormat.seconds(from: " 40 ") == 2400.0)
    }

    @Test("nonsense input is rejected rather than guessed at")
    func rejectsGarbage() {
        #expect(TimeFormat.seconds(from: "") == nil)
        #expect(TimeFormat.seconds(from: "abc") == nil)
        #expect(TimeFormat.seconds(from: "-5") == nil)
        #expect(TimeFormat.seconds(from: "1:2:3:4") == nil)
    }
}

@Suite("Ring geometry")
struct DialTests {

    private let dial = DurationDial(fullTurnMinutes: 60, minMinutes: 1, maxMinutes: 180, stepMinutes: 1)

    @Test("a quarter turn is a quarter of the full turn")
    func fractionToSeconds() {
        #expect(dial.seconds(forFraction: 0.25) == 15 * 60)
        #expect(dial.seconds(forFraction: 0.5) == 30 * 60)
        #expect(dial.seconds(forFraction: 1) == 60 * 60)
    }

    @Test("dragging snaps to whole minutes")
    func snapsToStep() {
        #expect(dial.seconds(forFraction: 0.257) == 15 * 60)
        #expect(dial.seconds(forFraction: 0.262) == 16 * 60)
    }

    @Test("the fraction round-trips back from a duration")
    func roundTrip() {
        #expect(abs(dial.fraction(forSeconds: 15 * 60) - 0.25) < 0.0001)
        #expect(dial.fraction(forSeconds: 0) == 0)
    }

    @Test("durations past one turn pin to a full ring instead of wrapping")
    func pinsPastFullTurn() {
        #expect(dial.fraction(forSeconds: 90 * 60) == 1)
    }

    @Test("values are clamped to the allowed range")
    func clamps() {
        #expect(dial.clamp(minutes: 0) == 1)
        #expect(dial.clamp(minutes: 500) == 180)
        #expect(dial.seconds(forFraction: 0) == 60)   // never below minMinutes
    }
}

@Suite("Config loading")
struct ConfigTests {

    @Test("a full config file decodes")
    func decodesFull() {
        let json = """
        {"menuBar":{"fontSize":15,"monospacedDigits":false},
         "dial":{"fullTurnMinutes":90,"minMinutes":2,"maxMinutes":120,"stepMinutes":5},
         "defaults":{"workMinutes":50,"shortBreakMinutes":10,"longBreakMinutes":20,"longBreakAfter":3}}
        """
        let c = AppConfig.decode(Data(json.utf8))
        #expect(c.menuBar.fontSize == 15)
        #expect(c.menuBar.monospacedDigits == false)
        #expect(c.dial.fullTurnMinutes == 90)
        #expect(c.defaults.workMinutes == 50)
        #expect(c.defaults.longBreakAfter == 3)
    }

    @Test("missing keys fall back one at a time, not all at once")
    func partialKeepsOtherValues() {
        let c = AppConfig.decode(Data(##"{"ring":{"workColor":"#ABCDEF"}}"##.utf8))
        #expect(c.ring.workColor == "#ABCDEF")
        #expect(c.ring.breakColor == RingConfig().breakColor)
        #expect(c.ring.diameter == RingConfig().diameter)
    }

    @Test("a wrong type falls back instead of throwing the file away")
    func wrongTypeFallsBack() {
        let c = AppConfig.decode(Data(##"{"menuBar":{"fontSize":"big","monospacedDigits":false}}"##.utf8))
        #expect(c.menuBar.fontSize == MenuBarConfig().fontSize)
        #expect(c.menuBar.monospacedDigits == false)
    }

    @Test("an unreadable file gives the built-in defaults")
    func brokenFile() {
        #expect(AppConfig.decode(Data("not json".utf8)) == AppConfig())
    }

    @Test("stored settings survive a field being added later")
    func settingsForwardCompatible() {
        let stored = Data(#"{"intervals":{"workMinutes":45}}"#.utf8)
        let s = try? JSONDecoder().decode(Settings.self, from: stored)
        #expect(s?.intervals.workMinutes == 45)
        #expect(s?.intervals.longBreakAfter == 4)
        #expect(s?.general.showTimerInMenuBar == true)
    }
}
