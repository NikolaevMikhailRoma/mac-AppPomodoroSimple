import SwiftUI
import PomodoroCore

struct IntervalsTab: View {
    @Bindable var store: SettingsStore
    let config: AppConfig

    private var metrics: SettingsWindowConfig { config.settingsWindow }

    var body: some View {
        VStack(spacing: 0) {
            MinutesRow("Work interval", $store.settings.intervals.workMinutes, config)
            MinutesRow("Short break", $store.settings.intervals.shortBreakMinutes, config)
            MinutesRow("Long break", $store.settings.intervals.longBreakMinutes, config)

            FormRow(label: "Long break after", metrics: metrics) {
                HStack(spacing: 6) {
                    TextField("", value: $store.settings.intervals.longBreakAfter, format: .number)
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 48)
                    Stepper("", value: $store.settings.intervals.longBreakAfter, in: 1...12)
                        .labelsHidden()
                    Text("intervals")
                        .font(.system(size: metrics.labelSize))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct MinutesRow: View {
    let label: String
    @Binding var minutes: Double
    let config: AppConfig

    init(_ label: String, _ minutes: Binding<Double>, _ config: AppConfig) {
        self.label = label
        self._minutes = minutes
        self.config = config
    }

    var body: some View {
        FormRow(label: label, metrics: config.settingsWindow) {
            HStack(spacing: 6) {
                TextField("", value: $minutes, format: .number.precision(.fractionLength(0)))
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 48)
                    .onChange(of: minutes) { _, new in
                        let clamped = config.dial.dial.clamp(minutes: new)
                        if clamped != new { minutes = clamped }
                    }
                Stepper(
                    "",
                    value: $minutes,
                    in: config.dial.dial.minMinutes...config.dial.dial.maxMinutes,
                    step: 1
                )
                .labelsHidden()
                Text("min")
                    .font(.system(size: config.settingsWindow.labelSize))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
