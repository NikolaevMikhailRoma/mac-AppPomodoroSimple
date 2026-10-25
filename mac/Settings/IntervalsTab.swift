import SwiftUI
import PomodoroCore
import PomodoroConfig

struct IntervalsTab: View {
    @Binding var settings: PomodoroCore.Settings
    let config: AppConfig

    private var metrics: SettingsWindowConfig { config.settingsWindow }

    var body: some View {
        VStack(spacing: 0) {
            MinutesRow("Work interval", $settings.intervals.workMinutes, config)
            MinutesRow("Short break", $settings.intervals.shortBreakMinutes, config)
            MinutesRow("Long break", $settings.intervals.longBreakMinutes, config)

            FormRow(label: "Long break after", metrics: metrics) {
                HStack(spacing: metrics.stepperSpacing) {
                    TextField("", value: $settings.intervals.longBreakAfter, format: .number)
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: metrics.fieldWidth)
                    Stepper("", value: $settings.intervals.longBreakAfter, in: 1...12)
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

    @State private var limitHints = 0

    init(_ label: String, _ minutes: Binding<Double>, _ config: AppConfig) {
        self.label = label
        self._minutes = minutes
        self.config = config
    }

    private var metrics: SettingsWindowConfig { config.settingsWindow }

    var body: some View {
        FormRow(label: label, metrics: metrics) {
            HStack(spacing: metrics.stepperSpacing) {
                TextField("", value: checked, format: .number.precision(.fractionLength(0)))
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: metrics.fieldWidth)
                Stepper(
                    "",
                    value: checked,
                    in: config.dial.dial.minMinutes...config.dial.dial.maxMinutes,
                    step: 1
                )
                .labelsHidden()
                Text("min")
                    .font(.system(size: metrics.labelSize))
                    .foregroundStyle(.secondary)
            }
            // Left of the field, over the free space, so the row does not move.
            .overlay(alignment: .leading) { [spacing = metrics.rowSpacing] in
                TransientHint(text: "Max \(Int(limitMinutes)) min", trigger: limitHints)
                    .font(.system(size: metrics.sectionHeaderSize))
                    .foregroundStyle(Theme.swiftUIColor(metrics.sectionHeaderColor, fallback: .secondaryLabelColor))
                    .alignmentGuide(.leading) { $0[.trailing] + spacing }
            }
        }
    }

    /// Whole minutes within the dial; over the limit shows the hint.
    private var checked: Binding<Double> {
        Binding(get: { minutes }, set: { new in
            if new.rounded() > limitMinutes { limitHints += 1 }
            minutes = config.dial.dial.clamp(minutes: new)
        })
    }

    /// The limit as the field shows it: 59:59 reads as 60.
    private var limitMinutes: Double { config.dial.dial.maxMinutes.rounded(.up) }
}
