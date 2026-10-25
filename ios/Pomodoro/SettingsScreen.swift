import PomodoroConfig
import PomodoroCore
import PomodoroUI
import SwiftUI

/// The Mac's settings window, with the iPhone's own rows: the Lock Screen,
/// what iOS has switched off, and the paired Mac.
struct SettingsScreen: View {
    let timer: PomodoroTimer
    let alerts: PhoneAlerts
    let sync: SyncClient
    let config: AppConfig
    let pair: () -> Void

    private var metrics: SettingsWindowConfig { config.settingsMetrics }

    var body: some View {
        let settings = Binding(get: { timer.settings }, set: { timer.update($0) })
        SettingsView(settings: settings, sound: timer.sound, config: config) {
            ToggleRow("Show timer on the Lock Screen",
                      isOn: Binding(get: { alerts.showOnLockScreen }, set: { alerts.setShowOnLockScreen($0) }),
                      metrics: metrics)
            if alerts.showOnLockScreen, alerts.liveActivitiesDenied {
                HintRow("Live Activities are off for Pomodoro in iOS Settings", button: "Allow", metrics: metrics) {
                    open(UIApplication.openSettingsURLString)
                }
            }
            AutoStartRow(settings: settings, metrics: metrics)
        } soundNotes: {
            if timer.settings.sound.notificationsEnabled, alerts.notificationsDenied {
                HintRow("Notifications are off for Pomodoro in iOS Settings", button: "Allow", metrics: metrics) {
                    open(UIApplication.openNotificationSettingsURLString)
                }
            }
            Hint("With the app closed, the sound comes with the notification, at the phone's volume.", metrics: metrics)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, metrics.rowSpacing)
        } devices: {
            devices
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    // The number fields take what was typed when they lose focus.
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }

    /// Like the Mac's Devices tab: the paired Mac in a row, with its state and Forget.
    @ViewBuilder private var devices: some View {
        VStack(spacing: 0) {
            if sync.isPaired {
                FormRow(sync.pairedTitle, metrics: metrics) {
                    Hint(statusText, metrics: metrics)
                    Button("Forget", action: sync.forget)
                }
            } else {
                Text("Pair with Pomodoro on your Mac to see and control one timer from both, over your Wi-Fi.")
                    .font(.system(size: metrics.labelSize))
                    .foregroundStyle(Color(hex: metrics.labelColor))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, metrics.rowSpacing)
            }
            if case .failed(let message) = sync.status {
                Hint(message, metrics: metrics)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, metrics.rowSpacing)
            }
            Button(sync.isPaired ? "Pair again" : "Pair with Mac", action: pair)
                .padding(.top, metrics.sectionTopPadding)
        }
    }

    private var statusText: String {
        switch sync.status {
        case .connected: return "Connected"
        case .pairing: return "Pairing…"
        case .searching: return "Looking…"
        default: return ""
        }
    }

    private func open(_ settings: String) {
        if let url = URL(string: settings) { UIApplication.shared.open(url) }
    }
}
