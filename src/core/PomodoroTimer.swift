import Foundation
import Observation

/// The platform's alert sounds: macOS's on the Mac, iOS's tones on the iPhone.
@MainActor
public protocol SoundOutput: AnyObject {
    /// What settings offers. A saved name this platform lacks gives way to the first ones.
    var names: [String] { get }
    func play(_ name: String, volume: Double)
}

/// End-of-interval notifications, and whatever else shows the timer outside the app.
@MainActor
public protocol TimerAlerts: AnyObject {
    /// True where the system rings for a closed app: the iPhone schedules its
    /// notifications ahead. The timer is then kept across launches, catches up
    /// interval by interval as they went off, and does not ring them again.
    var ringWhileClosed: Bool { get }
    /// An interval just ran out with the app running.
    func finished(_ phase: Phase, next: Phase, settings: Settings)
    /// Anything but the countdown changed: a button, a new interval, the settings.
    func changed(_ engine: PomodoroEngine, settings: Settings)
}

/// The one owner of the timer on the Mac and the iPhone: the engine, the
/// settings, ticking, ringing and the sync rules. What only a platform can do
/// comes in through `SoundOutput` and `TimerAlerts`.
@MainActor
@Observable
public final class PomodoroTimer {
    /// A tick comes this long after the shown second turned: a timer fires late at times, never early.
    private static let tickMargin: TimeInterval = 0.01
    /// An interval that ran out longer ago than this rang while the app was
    /// closed (`ringWhileClosed`); the app does not ring it again.
    private static let lateAfter: TimeInterval = 2
    /// Interval ends that `ringWhileClosed` alerts schedule ahead, and so the
    /// most the timer catches up after a long time closed.
    public nonisolated static let endsAhead = 8
    private static let settingsKey = "Settings"
    private static let stateKey = "EngineState"

    public private(set) var state: EngineState
    public private(set) var settings: Settings
    public let dial: DurationDial
    @ObservationIgnored public let sound: SoundOutput

    /// Every change, ticks included: for what SwiftUI does not draw (the Mac's menu bar).
    @ObservationIgnored public var onChange: (() -> Void)?
    /// A new state for the other devices: after a button or an interval running out.
    @ObservationIgnored public var onStateChange: ((EngineState) -> Void)?
    /// New interval settings for the other devices (docs/SYNC.md, Interval settings).
    @ObservationIgnored public var onIntervalsChange: ((IntervalSettings, Date) -> Void)?

    @ObservationIgnored private var engine: PomodoroEngine
    @ObservationIgnored private let alerts: TimerAlerts
    /// The Mac: phones sync through it, so what it takes from one goes on to the others.
    @ObservationIgnored private let isHub: Bool
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var ticker: Timer?
    /// What `alerts` last got; see publish().
    @ObservationIgnored private var published: EngineState?
    @ObservationIgnored private var sentChangedAt: Date?
    @ObservationIgnored private var sentIntervalsAt: Date?
    /// The hub's last state taken from a phone: while the engine still has it,
    /// the hub has not changed the timer itself since.
    @ObservationIgnored private var adoptedChangedAt: Date?

    /// `intervals` and `dial` come from config.json; the saved settings win over the first.
    public init(intervals: IntervalSettings, dial: DurationDial, sound: SoundOutput, alerts: TimerAlerts,
                isHub: Bool, defaults: UserDefaults = .standard) {
        self.dial = dial
        self.sound = sound
        self.alerts = alerts
        self.isHub = isHub
        self.defaults = defaults
        var settings = defaults.data(forKey: Self.settingsKey).flatMap { try? JSONDecoder().decode(Settings.self, from: $0) }
            ?? Settings(intervals: intervals)
        // Durations saved earlier may be longer than today's upper bound.
        settings.intervals = dial.clamp(intervals: settings.intervals)
        let names = sound.names
        if !names.contains(settings.sound.workCompletedSound), let first = names.first {
            settings.sound.workCompletedSound = first
        }
        if !names.contains(settings.sound.breakEndedSound), let second = names.dropFirst().first ?? names.first {
            settings.sound.breakEndedSound = second
        }
        self.settings = settings
        sentIntervalsAt = settings.intervalsChangedAt
        engine = PomodoroEngine(settings: settings.intervals, autoStartNextInterval: settings.general.autoStartNextInterval)
        if alerts.ringWhileClosed,
           let data = defaults.data(forKey: Self.stateKey),
           let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
           let saved = EngineState(json: json) {
            engine.adopt(saved)
        }
        engine.rollOverDay(EngineState.day(of: Date()))
        state = engine.state
        tick()
    }

    public var timeText: String { TimeFormat.string(from: state.remaining) }
    public var isRunning: Bool { state.runState == .running }
    public var phase: Phase { state.phase }
    public var skipTitle: String { state.phase == .work ? "Finish work" : "Skip break" }
    public var ringFraction: Double { dial.fraction(forSeconds: state.remaining) }

    public func toggle() {
        engine.rollOverDay(EngineState.day(of: Date()))
        engine.toggle()
        publish()
    }

    public func stop() {
        engine.stop()
        publish()
    }

    public func skip() {
        engine.rollOverDay(EngineState.day(of: Date()))
        ring(engine.skip(), late: false)
        publish()
    }

    public func setDuration(fraction: Double) {
        setDuration(seconds: dial.seconds(forFraction: fraction))
    }

    /// True when the typed value was over the limit and the timer took the limit.
    @discardableResult
    public func setDuration(text: String) -> Bool {
        guard let seconds = TimeFormat.seconds(from: text) else { return false }
        setDuration(seconds: seconds)
        return seconds > dial.maxSeconds
    }

    /// Runs out what is due. Also for the iPhone's return to the app and its Lock Screen button.
    public func tick() {
        let now = Date()
        var events: [EngineEvent] = []
        var late = false
        if alerts.ringWhileClosed {
            late = state.endsAt.map { now.timeIntervalSince($0) > Self.lateAfter } ?? false
            // Interval by interval, the way their notifications rang while the
            // app was closed; the engine alone would start the next one only now.
            while events.count < 2 * Self.endsAhead, engine.runState == .running, let endsAt = engine.state.endsAt, endsAt < now {
                events += engine.update(now: endsAt)
            }
        }
        events += engine.update(now: now)
        ring(events, late: late)
        publish()
    }

    /// The other device's state, already on this one's clock (docs/SYNC.md, Merging).
    public func receive(_ remote: EngineState) {
        let local = engine.state.changedAt
        guard SyncRules.shouldAdopt(local: local, remote: remote.changedAt, receiverIsMac: isHub,
                                    localAdopted: local == adoptedChangedAt) else { return }
        engine.adopt(remote)
        if isHub { adoptedChangedAt = remote.changedAt } else { sentChangedAt = remote.changedAt }
        publish()
    }

    /// The user's settings. Changed intervals get the time of the change.
    public func update(_ new: Settings) {
        var new = new
        new.intervals = dial.clamp(intervals: new.intervals)
        if new.intervals != settings.intervals { new.intervalsChangedAt = Date() }
        apply(new)
    }

    /// The other device's interval settings, their change time already on this one's clock.
    public func receiveIntervals(_ intervals: IntervalSettings, changedAt: Date) {
        guard SyncRules.shouldAdoptIntervals(local: settings.intervalsChangedAt, remote: changedAt, receiverIsMac: isHub) else {
            return
        }
        var new = settings
        new.intervals = dial.clamp(intervals: intervals)
        new.intervalsChangedAt = changedAt
        // The hub passes them on to its other phones; a phone does not send them back.
        if !isHub { sentIntervalsAt = changedAt }
        apply(new)
    }

    private func setDuration(seconds: TimeInterval) {
        engine.setPhaseDuration(dial.clamp(seconds: seconds))
        publish()
    }

    private func apply(_ new: Settings) {
        guard new != settings else { return }
        settings = new
        if let data = try? JSONEncoder().encode(new) { defaults.set(data, forKey: Self.settingsKey) }
        engine.autoStartNextInterval = new.general.autoStartNextInterval
        engine.applySettings(new.intervals)
        // Sound and notification settings change what the alerts do, not the state.
        publish(force: true)
        if new.intervalsChangedAt != sentIntervalsAt {
            sentIntervalsAt = new.intervalsChangedAt
            onIntervalsChange?(new.intervals, new.intervalsChangedAt)
        }
    }

    private func ring(_ events: [EngineEvent], late: Bool) {
        guard !late else { return }
        for case .phaseFinished(let finished) in events {
            if settings.sound.soundEnabled {
                sound.play(settings.sound.sound(afterFinishing: finished), volume: settings.sound.volume)
            }
            alerts.finished(finished, next: engine.phase, settings: settings)
        }
    }

    /// The screen gets every tick. What is saved and what the alerts show
    /// change only when something other than the countdown did: while
    /// running, `remaining` follows from `endsAt`.
    private func publish(force: Bool = false) {
        let current = engine.state
        state = current
        syncTicker()
        if current.changedAt != sentChangedAt {
            sentChangedAt = current.changedAt
            onStateChange?(current)
        }
        var structural = current
        if current.runState == .running { structural.remaining = 0 }
        if force || structural != published {
            published = structural
            if alerts.ringWhileClosed {
                defaults.set(try? JSONSerialization.data(withJSONObject: current.json), forKey: Self.stateKey)
            }
            alerts.changed(engine, settings: settings)
        }
        onChange?()
    }

    /// While running, one tick each time the shown time turns, and none in
    /// between. The time is rounded up, so it turns when whole seconds are left.
    private func syncTicker() {
        ticker?.invalidate()
        ticker = nil
        guard isRunning, let endsAt = state.endsAt else { return }
        let left = endsAt.timeIntervalSinceNow
        let ticker = Timer(timeInterval: left - left.rounded(.down) + Self.tickMargin, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // .common: the Mac's menu bar keeps counting while a menu is open.
        RunLoop.main.add(ticker, forMode: .common)
        self.ticker = ticker
    }
}
