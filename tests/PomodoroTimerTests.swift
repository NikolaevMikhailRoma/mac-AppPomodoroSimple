import Foundation
import Testing
@testable import PomodoroCore

@MainActor
private final class FakeSound: SoundOutput {
    let names = ["Glass", "Ping", "Pop"]
    var played: [String] = []
    func play(_ name: String, volume: Double) { played.append(name) }
}

@MainActor
private final class FakeAlerts: TimerAlerts {
    let ringWhileClosed: Bool
    var finished: [Phase] = []
    var changes = 0
    init(ringWhileClosed: Bool) { self.ringWhileClosed = ringWhileClosed }
    func finished(_ phase: Phase, next: Phase, settings: Settings) { finished.append(phase) }
    func changed(_ engine: PomodoroEngine, settings: Settings) { changes += 1 }
}

@MainActor
private struct Setup {
    let sound = FakeSound()
    let alerts: FakeAlerts
    let defaults: UserDefaults
    let timer: PomodoroTimer

    init(hub: Bool, ringWhileClosed: Bool = false, defaults name: String = UUID().uuidString) {
        alerts = FakeAlerts(ringWhileClosed: ringWhileClosed)
        defaults = UserDefaults(suiteName: name)!
        timer = PomodoroTimer(intervals: IntervalSettings(), dial: DurationDial(), sound: sound, alerts: alerts,
                              isHub: hub, defaults: defaults)
    }
}

/// A running work interval that ended `ago` seconds back, as another device sends it.
private func ended(_ ago: TimeInterval) -> EngineState {
    let now = Date()
    return EngineState(phase: .work, runState: .running, phaseDuration: 60, remaining: 0,
                       endsAt: now.addingTimeInterval(-ago), completedToday: 0, sinceLongBreak: 0,
                       day: EngineState.day(of: now), changedAt: now.addingTimeInterval(-60 - ago))
}

@MainActor
@Suite("Timer owner")
struct PomodoroTimerTests {

    @Test("an interval that runs out rings and tells the alerts")
    func rings() {
        let s = Setup(hub: false)
        s.timer.receive(ended(0.5))
        s.timer.tick()
        #expect(s.sound.played == ["Glass"])
        #expect(s.alerts.finished == [.work])
        #expect(s.timer.state.phase == .shortBreak)
        #expect(s.timer.state.completedToday == 1)
    }

    @Test("where the system rang while closed, a late end is caught up silently")
    func lateIsSilent() {
        let s = Setup(hub: false, ringWhileClosed: true)
        s.timer.receive(ended(30))
        s.timer.tick()
        #expect(s.sound.played.isEmpty)
        #expect(s.alerts.finished.isEmpty)
        #expect(s.timer.state.completedToday == 1)
    }

    @Test("the state outlives the app only where the system rings for it")
    func keepsState() {
        let name = UUID().uuidString
        let phone = Setup(hub: false, ringWhileClosed: true, defaults: name)
        phone.timer.toggle()
        #expect(Setup(hub: false, ringWhileClosed: true, defaults: name).timer.isRunning)

        let macDefaults = UUID().uuidString
        Setup(hub: true, defaults: macDefaults).timer.toggle()
        #expect(!Setup(hub: true, defaults: macDefaults).timer.isRunning)
    }

    @Test("a phone does not send back what it took; the Mac passes it on")
    func relays() {
        let state = ended(-600)
        for hub in [false, true] {
            let s = Setup(hub: hub)
            var sent: [EngineState] = []
            var intervalsSent = 0
            s.timer.onStateChange = { sent.append($0) }
            s.timer.onIntervalsChange = { _, _ in intervalsSent += 1 }
            s.timer.receive(state)
            s.timer.receiveIntervals(IntervalSettings(workMinutes: 40), changedAt: Date())
            #expect(s.timer.settings.intervals.workMinutes == 40)
            #expect(sent.count == (hub ? 1 : 0))
            #expect(intervalsSent == (hub ? 1 : 0))
        }
    }

    @Test("a button here goes out once")
    func sendsOwnChanges() {
        let s = Setup(hub: false)
        var sent: [EngineState] = []
        s.timer.onStateChange = { sent.append($0) }
        s.timer.toggle()
        s.timer.tick()
        #expect(sent.count == 1)
        #expect(sent.first?.runState == .running)
    }

    @Test("the user's new intervals get a time and go out; sound changes do not")
    func stampsIntervals() {
        let s = Setup(hub: false)
        var sent: [Date] = []
        s.timer.onIntervalsChange = { sent.append($1) }
        var new = s.timer.settings
        new.sound.volume = 0.2
        s.timer.update(new)
        #expect(sent.isEmpty)
        new.intervals.workMinutes = 90
        s.timer.update(new)
        #expect(sent.count == 1)
        #expect(s.timer.settings.intervals.workMinutes * 60 == DurationDial().maxSeconds)
        #expect(s.timer.settings.intervalsChangedAt == sent[0])
    }

    @Test("a saved sound this platform lacks gives way to its own")
    func soundFallback() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        var saved = Settings()
        saved.sound.workCompletedSound = "Morse"
        saved.sound.breakEndedSound = "Nope"
        defaults.set(try! JSONEncoder().encode(saved), forKey: "Settings")
        let s = Setup(hub: false, defaults: name)
        #expect(s.timer.settings.sound.workCompletedSound == "Glass")
        #expect(s.timer.settings.sound.breakEndedSound == "Ping")
    }
}
