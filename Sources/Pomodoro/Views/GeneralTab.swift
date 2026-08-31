import SwiftUI
import ServiceManagement
import PomodoroCore

struct GeneralTab: View {
    @Bindable var store: SettingsStore
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
                    get: { store.settings.general.launchAtStartup },
                    set: { store.settings.general.launchAtStartup = LoginItem.set($0) }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
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

enum LoginItem {
    @MainActor
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return enabled
        } catch {
            return SMAppService.mainApp.status == .enabled
        }
    }
}
