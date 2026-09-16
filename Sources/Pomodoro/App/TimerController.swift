import Foundation
import Observation
import PomodoroCore
import PomodoroConfig

@MainActor
@Observable
final class TimerController {
    private static let tickInterval: TimeInterval = 0.25

    private(set) var engine: PomodoroEngine
    let dial: DurationDial

    @ObservationIgnored var onChange: (() -> Void)?

    @ObservationIgnored private var ticker: Timer?
    @ObservationIgnored private var sound: SoundPlayer
    @ObservationIgnored private var notifier = Notifier()
    @ObservationIgnored private var settings: Settings
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

    var timeText: String { TimeFormat.string(from: engine.remaining) }
    var isRunning: Bool { engine.runState == .running }
    var phase: Phase { engine.phase }
    var completedToday: Int { engine.completedToday }
    var skipTitle: String { engine.phase == .work ? "Finish work" : "Skip break" }

    var ringFraction: Double { dial.fraction(forSeconds: engine.remaining) }

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
        rollOverDayIfNeeded()
        handle(engine.skip())
        syncTicker()
        changed()
    }

    func setDuration(seconds: TimeInterval) {
        engine.setPhaseDuration(dial.clamp(seconds: seconds))
        changed()
    }

    func setDuration(fraction: Double) {
        setDuration(seconds: dial.seconds(forFraction: fraction))
    }

    /// true, если введённое больше предела и таймер встал на предел.
    @discardableResult
    func setDuration(text: String) -> Bool {
        guard let seconds = TimeFormat.seconds(from: text) else { return false }
        setDuration(seconds: seconds)
        return seconds > dial.maxSeconds
    }

    func apply(_ new: Settings) {
        settings = new
        sound.settings = new.sound
        engine.autoStartNextInterval = new.general.autoStartNextInterval
        engine.applySettings(new.intervals)
        changed()
    }

    private func syncTicker() {
        if isRunning, ticker == nil {
            let t = Timer(timeInterval: Self.tickInterval, repeats: true) { _ in
                MainActor.assumeIsolated { self.tick() }
            }
            RunLoop.main.add(t, forMode: .common)
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

    private func rollOverDayIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        guard today != countedDay else { return }
        countedDay = today
        engine.resetDailyCount()
    }

    private func changed() { onChange?() }
}
