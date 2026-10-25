import SwiftUI
import PomodoroCore
import PomodoroConfig
import PomodoroUI

/// The Mac's own general settings, around the one every platform has.
struct GeneralTab: View {
    @Binding var settings: PomodoroCore.Settings
    let loginItem: LoginItem
    let metrics: SettingsWindowConfig

    var body: some View {
        VStack(spacing: 0) {
            FormRow("Appearance", metrics: metrics) {
                Picker("", selection: $settings.general.appearance) {
                    ForEach(Appearance.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .frame(width: metrics.controlWidth)
                .onChange(of: settings.general.appearance) { _, new in Theme.applyAppearance(new) }
            }
            ToggleRow("Launch at startup", isOn: Binding(get: { loginItem.isEnabled }, set: { loginItem.set($0) }),
                      metrics: metrics)
            if loginItem.isBlockedBySystem {
                HintRow("Turned off in System Settings → Login Items", button: "Open", metrics: metrics) {
                    loginItem.openSystemSettings()
                }
            }
            ToggleRow("Show timer in menu bar", isOn: $settings.general.showTimerInMenuBar, metrics: metrics)
            AutoStartRow(settings: $settings, metrics: metrics)

            SectionHeader("Application", metrics: metrics)

            Button("Quit Pomodoro") { NSApp.terminate(nil) }
                .frame(maxWidth: .infinity)
        }
    }
}
