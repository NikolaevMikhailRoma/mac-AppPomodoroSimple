import Foundation
import Observation
import PomodoroCore

/// The only place that owns a real clock.
///
/// Wraps the pure `PomodoroEngine`, drives it with a repeating timer, and turns
/// the events it returns into sounds and notifications. Views read its
/// properties; nothing writes to the engine except through the methods here.
@MainActor
@Observable
final class TimerController {

    /// How often the countdown is re-read. Fine enough for a smooth ring,
    /// cheap enough to leave running.
    private static let tickInterval: TimeInterval = 0.25

    private(set) var engine: PomodoroEngine
    let dial: DurationDial

    /// Called after every change, for observers that are not SwiftUI views.
    @ObservationIgnored var onChange: (() -> Void)?

    @ObservationIgnored private var ticker: Timer?
    @ObservationIgnored private var sound: SoundPlayer
    @ObservationIgnored private var notifier = Notifier()
    @ObservationIgnored private var settings: Settings
    /// The day the counter belongs to, so it rolls over at midnight.
    @ObservationIgnored private var countedDay: Date

    init(config: AppConfig, settings: Settings) {
        self.settings = settings
        self.dial = config.dial.dial
        self.sound = SoundPlayer(settings: settings.sound)
        self.engine = PomodoroEngine(
            settings: settings.intervals,
            autoStartNextInterval: settings.general.autoStartNextInterval
        )
        self.countedDay = Calendar.current.startOfDay(for: Date())
        notifier.requestPermission()
    }

    // MARK: - Read

    var timeText: String { TimeFormat.string(from: engine.remaining) }
    var isRunning: Bool { engine.runState == .running }
    var phase: Phase { engine.phase }
    var completedToday: Int { engine.completedToday }

    /// Fraction of the dial the remaining time fills — what the ring draws.
    var ringFraction: Double { dial.fraction(forSeconds: engine.remaining) }

    // MARK: - Commands

    func toggle() {
        rollOverDayIfNeeded()
        engine.toggle()
        syncTicker()
        changed()
    }

    func stop() {
        engine.stop()
        syncTicker()
        changed()
    }

    func skip() {
        handle(engine.skip())
        syncTicker()
        changed()
    }

    /// Used by both the ring drag and the editable digits.
    func setDuration(seconds: TimeInterval) {
        engine.setPhaseDuration(dial.clamp(seconds: seconds))
        changed()
    }

    func setDuration(fraction: Double) {
        setDuration(seconds: dial.seconds(forFraction: fraction))
    }

    /// Parses what the user typed over the digits. Bad input is ignored.
    func setDuration(text: String) {
        guard let seconds = TimeFormat.seconds(from: text) else { return }
        setDuration(seconds: seconds)
    }

    func apply(_ new: Settings) {
        settings = new
        sound.settings = new.sound
        engine.autoStartNextInterval = new.general.autoStartNextInterval
        engine.applySettings(new.intervals)
        changed()
    }

    // MARK: - Clock

    private func syncTicker() {
        if isRunning, ticker == nil {
            let t = Timer(timeInterval: Self.tickInterval, repeats: true) { _ in
                // Scheduled on the main run loop, so this always runs on the
                // main actor — the compiler just cannot see that.
                MainActor.assumeIsolated { self.tick() }
            }
            RunLoop.main.add(t, forMode: .common)   // keeps ticking during menu tracking
            ticker = t
        } else if !isRunning {
            ticker?.invalidate()
            ticker = nil
        }
    }

    private func tick() {
        let events = engine.update()
        if !events.isEmpty { handle(events) }
        syncTicker()
        changed()
    }

    private func handle(_ events: [EngineEvent]) {
        for event in events {
            guard case .phaseFinished(let finished) = event else { continue }
            sound.play(afterFinishing: finished)
            notifier.post(finished: finished, next: engine.phase, enabled: settings.sound.notificationsEnabled)
        }
    }

    /// The daily counter belongs to a day, not to the process.
    private func rollOverDayIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        guard today != countedDay else { return }
        countedDay = today
        engine.resetDailyCount()
    }

    private func changed() { onChange?() }
}
