import SwiftUI
import PomodoroCore
import PomodoroConfig

struct GeneralTab: View {
    @Bindable var store: SettingsStore
    let loginItem: LoginItem
    let metrics: SettingsWindowConfig

    var body: some View {
        VStack(spacing: 0) {
            FormRow(label: "Appearance", metrics: metrics) {
                Picker("", selection: $store.settings.general.appearance) {
                    ForEach(Appearance.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .frame(width: metrics.controlWidth)
            }
            FormRow(label: "Launch at startup", metrics: metrics) {
                Toggle("", isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.set($0) }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
            }
            if loginItem.isBlockedBySystem {
                HStack(spacing: metrics.rowSpacing) {
                    Text("Turned off in System Settings → Login Items")
                        .font(.system(size: metrics.sectionHeaderSize))
                        .foregroundStyle(Theme.swiftUIColor(metrics.sectionHeaderColor, fallback: .secondaryLabelColor))
                    Spacer(minLength: metrics.rowSpacing)
                    Button("Open") { loginItem.openSystemSettings() }
                }
                .frame(height: metrics.rowHeight)
            }
            FormRow(label: "Show timer in menu bar", metrics: metrics) {
                Toggle("", isOn: $store.settings.general.showTimerInMenuBar)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
            }
            FormRow(label: "Auto-start next interval", metrics: metrics) {
                Toggle("", isOn: $store.settings.general.autoStartNextInterval)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
            }

            SectionHeader(title: "Application", metrics: metrics)

            Button("Quit Pomodoro") { NSApp.terminate(nil) }
                .frame(maxWidth: .infinity)
        }
    }
}
