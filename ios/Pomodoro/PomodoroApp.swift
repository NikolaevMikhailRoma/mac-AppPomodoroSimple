import PomodoroConfig
import PomodoroCore
import SwiftUI

/// The one timer and the one connection to the Mac, for the screen and the
/// Lock Screen button alike: whichever wakes the app first creates them.
@MainActor
enum Shared {
    static let config = AppConfig.load()
    static let sound = SoundPlayer()
    static let alerts = PhoneAlerts(sound: sound, ring: config.ring)
    static let timer = PomodoroTimer(intervals: config.intervals, dial: config.dial.dial,
                                     sound: sound, alerts: alerts, isHub: false)
    static let sync = SyncClient(timer: timer)
}

/// The Lock Screen button, in the app's process (ToggleTimerIntent).
enum TimerIntentHandler {
    @MainActor
    static func toggle() async {
        // An interval that ran out while the app was closed finishes first.
        Shared.timer.tick()
        Shared.timer.toggle()
        // With the app closed there is no connection: tell the Mac now.
        await Shared.sync.quickSync()
    }
}

private enum Route: Hashable {
    case settings, pair
}

@main
struct PomodoroApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var path: [Route] = []

    init() {
        #if DEBUG
        // The simulator has no camera to read the QR: `simctl launch … -pairLink '<link>'`.
        if let link = UserDefaults.standard.string(forKey: "pairLink").flatMap(PairLink.init(link:)) {
            Shared.sync.pair(link)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $path) {
                TimerScreen(timer: Shared.timer, config: Shared.config,
                            onStart: { Task { await Shared.alerts.askForNotifications() } }) { path.append(.settings) }
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .settings:
                            SettingsScreen(timer: Shared.timer, alerts: Shared.alerts, sync: Shared.sync) { path.append(.pair) }
                        case .pair:
                            PairScreen { link in
                                Shared.sync.pair(link)
                                path.removeLast()
                            }
                        }
                    }
            }
            .tint(Theme.accent)
            .preferredColorScheme(.dark)
            .onChange(of: scenePhase, initial: true) { _, phase in
                switch phase {
                case .active:
                    Shared.timer.tick()
                    Task { await Shared.alerts.refreshPermissions() }
                    Shared.sync.setActive(true)
                case .background:
                    Shared.sync.setActive(false)
                default:
                    break
                }
            }
        }
    }
}
