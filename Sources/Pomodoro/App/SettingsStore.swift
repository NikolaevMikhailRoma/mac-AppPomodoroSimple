import Foundation
import Observation
import PomodoroCore

@MainActor
@Observable
final class SettingsStore {
    private static let key = "Settings"

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
