import ActivityKit
import Foundation
import Observation
import PomodoroConfig
import PomodoroCore

/// The one owner of the timer, for the screen and the Lock Screen button
/// alike. Unlike the Mac it keeps the timer across launches: iOS ends a
/// closed app whenever it likes.
@MainActor
@Observable
final class TimerStore {
    private static let stateKey = "EngineState"
    private static let settingsKey = "Settings"
    private static let lockScreenKey = "ShowOnLockScreen"
    /// An interval that ran out longer ago than this rang with its
    /// notification while the app was closed; the app does not ring it again.
    private static let lateAfter: TimeInterval = 2

    private(set) var state: EngineState
    private(set) var settings: Settings
    /// The Live Activity. iPhone only, so not in Settings, which the Mac shares.
    private(set) var showOnLockScreen: Bool
    /// Switched off in iOS Settings, as opposed to never asked.
    private(set) var notificationsDenied = false
    private(set) var liveActivitiesDenied = false
    let dial: DurationDial
    @ObservationIgnored let sound: SoundPlayer

    /// A new state for the Mac: after a button or an interval running out, not after taking the Mac's.
    @ObservationIgnored var onStateChange: (@MainActor (EngineState) -> Void)?
    /// The user changed the intervals: they go to the Mac (docs/SYNC.md, Interval settings).
    @ObservationIgnored var onIntervalsChange: (@MainActor (IntervalSettings, Date) -> Void)?

    @ObservationIgnored private var engine: PomodoroEngine
    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let notifier = Notifier()
    @ObservationIgnored private let lockScreen: LockScreenTimer
    /// What was last saved and scheduled; see publish().
    @ObservationIgnored private var published: EngineState?
    @ObservationIgnored private var sentChangedAt: Date?
    @ObservationIgnored private var sentIntervalsAt: Date?

    init(config: AppConfig) {
        let defaults = UserDefaults.standard
        dial = config.dial.dial
        var settings = defaults.data(forKey: Self.settingsKey).flatMap { try? JSONDecoder().decode(Settings.self, from: $0) }
            ?? Settings(intervals: config.intervals)
        settings.intervals = dial.clamp(intervals: settings.intervals)
        sound = SoundPlayer()
        // The Mac's sound names do not exist here: two different iPhone tones instead.
        let tones = sound.available.map(\.key)
        if !tones.contains(settings.sound.workCompletedSound), let first = tones.first {
            settings.sound.workCompletedSound = first
        }
        if !tones.contains(settings.sound.breakEndedSound), let second = tones.dropFirst().first ?? tones.first {
            settings.sound.breakEndedSound = second
        }
        self.settings = settings
        showOnLockScreen = defaults.object(forKey: Self.lockScreenKey) as? Bool ?? true
        lockScreen = LockScreenTimer(ring: config.ring)

        engine = PomodoroEngine(settings: settings.intervals, autoStartNextInterval: settings.general.autoStartNextInterval)
        if let data = defaults.data(forKey: Self.stateKey),
           let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
           let saved = EngineState(json: json) {
            engine.adopt(saved)
        }
        engine.rollOverDay(EngineState.day(of: Date()))
        state = engine.state
        // Its first publish saves and schedules everything for the state as it is now.
        tick()
    }

    var timeText: String { TimeFormat.string(from: state.remaining) }
    var isRunning: Bool { state.runState == .running }
    var skipTitle: String { state.phase == .work ? "Finish work" : "Skip break" }

    func toggle() {
        engine.rollOverDay(EngineState.day(of: Date()))
        engine.toggle()
        publish()
    }

    func stop() {
        engine.stop()
        publish()
    }

    func skip() {
        engine.rollOverDay(EngineState.day(of: Date()))
        ring(engine.skip())
        publish()
    }

    func setDuration(fraction: Double) {
        setDuration(seconds: dial.seconds(forFraction: fraction))
    }

    /// True when the typed value was over the limit and the timer took the limit.
    @discardableResult
    func setDuration(text: String) -> Bool {
        guard let seconds = TimeFormat.seconds(from: text) else { return false }
        setDuration(seconds: seconds)
        return seconds > dial.maxSeconds
    }

    func tick() {
        let now = Date()
        let late = state.endsAt.map { now.timeIntervalSince($0) > Self.lateAfter } ?? false
        var events: [EngineEvent] = []
        // Interval by interval, the way their notifications rang while the app
        // was closed; the engine alone would start the next one only now.
        while events.count < 2 * Notifier.scheduledAhead, engine.runState == .running,
              let endsAt = engine.state.endsAt, endsAt < now {
            events += engine.update(now: endsAt)
        }
        events += engine.update(now: now)
        if !late { ring(events) }
        publish()
    }

    /// The Mac's state, already on this phone's clock (docs/SYNC.md, Merging).
    func receive(_ remote: EngineState) {
        guard SyncRules.shouldAdopt(local: engine.state.changedAt, remote: remote.changedAt, receiverIsMac: false) else {
            return
        }
        engine.adopt(remote)
        sentChangedAt = remote.changedAt
        publish()
    }

    func update(_ new: Settings) {
        var new = new
        new.intervals = dial.clamp(intervals: new.intervals)
        if new.intervals != settings.intervals { new.intervalsChangedAt = Date() }
        apply(new)
    }

    /// The Mac's interval settings, their change time already on this phone's clock.
    func receiveIntervals(_ intervals: IntervalSettings, changedAt: Date) {
        guard SyncRules.shouldAdoptIntervals(local: settings.intervalsChangedAt, remote: changedAt, receiverIsMac: false) else {
            return
        }
        var new = settings
        new.intervals = dial.clamp(intervals: intervals)
        new.intervalsChangedAt = changedAt
        sentIntervalsAt = changedAt
        apply(new)
    }

    func setShowOnLockScreen(_ on: Bool) {
        showOnLockScreen = on
        defaults.set(on, forKey: Self.lockScreenKey)
        publish(force: true)
    }

    /// Asked when the timer first starts, not at launch: that is when a
    /// notification is first due. iOS itself asks only once.
    func askForNotifications() async {
        guard settings.sound.notificationsEnabled, await notifier.status() == .notDetermined else { return }
        await notifier.requestPermission()
        await refreshPermissions()
        publish(force: true)
    }

    /// After a return to the app: either may have been switched in iOS Settings.
    func refreshPermissions() async {
        notificationsDenied = await notifier.status() == .denied
        liveActivitiesDenied = !ActivityAuthorizationInfo().areActivitiesEnabled
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
        // Sound and notification settings change what is scheduled, not the state.
        publish(force: true)
        if new.intervalsChangedAt != sentIntervalsAt {
            sentIntervalsAt = new.intervalsChangedAt
            onIntervalsChange?(new.intervals, new.intervalsChangedAt)
        }
    }

    private func ring(_ events: [EngineEvent]) {
        let s = settings.sound
        guard s.soundEnabled else { return }
        for case .phaseFinished(let finished) in events {
            sound.play(s.sound(afterFinishing: finished), volume: s.volume)
        }
    }

    /// The screen gets every tick. Saving, the notifications and the Live
    /// Activity change only when something other than the countdown itself
    /// did: while running, `remaining` follows from `endsAt`.
    private func publish(force: Bool = false) {
        let current = engine.state
        state = current
        if current.changedAt != sentChangedAt {
            sentChangedAt = current.changedAt
            onStateChange?(current)
        }
        var structural = current
        if current.runState == .running { structural.remaining = 0 }
        guard force || structural != published else { return }
        published = structural
        defaults.set(try? JSONSerialization.data(withJSONObject: current.json), forKey: Self.stateKey)
        notifier.schedule(engine, sound: settings.sound, file: sound.notificationSound)
        lockScreen.show(current, enabled: showOnLockScreen)
    }
}
