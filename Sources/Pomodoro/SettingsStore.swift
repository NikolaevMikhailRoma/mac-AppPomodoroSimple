import Foundation
import Observation
import PomodoroCore

/// Holds the user's settings and persists them as one JSON blob in
/// `UserDefaults`. Every write goes through `settings`, so there is exactly one
/// place that saves and one place that notifies.
@MainActor
@Observable
final class SettingsStore {

    private static let key = "Settings"

    /// Called after any change, so the timer and the appearance can follow.
    @ObservationIgnored var onChange: ((Settings) -> Void)?

    @ObservationIgnored private let defaults: UserDefaults

    var settings: Settings {
        didSet {
            guard settings != oldValue else { return }
            save()
            onChange?(settings)
        }
    }

    init(defaults: UserDefaults = .standard, fallback: Settings = Settings()) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let stored = try? JSONDecoder().decode(Settings.self, from: data) {
            self.settings = stored
        } else {
            self.settings = fallback
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
