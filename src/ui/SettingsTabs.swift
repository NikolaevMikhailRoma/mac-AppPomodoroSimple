import PomodoroConfig
import PomodoroCore
import SwiftUI

struct IntervalsTab: View {
    @Binding var settings: PomodoroCore.Settings
    let config: AppConfig

    private var metrics: SettingsWindowConfig { config.settingsMetrics }

    var body: some View {
        VStack(spacing: 0) {
            MinutesRow("Work interval", $settings.intervals.workMinutes, config)
            MinutesRow("Short break", $settings.intervals.shortBreakMinutes, config)
            MinutesRow("Long break", $settings.intervals.longBreakMinutes, config)

            FormRow("Long break after", metrics: metrics) {
                NumberField(value: Binding(
                    get: { Double(settings.intervals.longBreakAfter) },
                    set: { settings.intervals.longBreakAfter = Int(min(max($0.rounded(), 1), 12)) }
                ), range: 1...12, unit: "intervals", metrics: metrics)
            }
        }
    }
}

private struct MinutesRow: View {
    let label: String
    @Binding var minutes: Double
    let config: AppConfig

    @State private var limitHints = 0

    init(_ label: String, _ minutes: Binding<Double>, _ config: AppConfig) {
        self.label = label
        self._minutes = minutes
        self.config = config
    }

    private var metrics: SettingsWindowConfig { config.settingsMetrics }
    private var dial: DurationDial { config.dial.dial }

    var body: some View {
        FormRow(label, metrics: metrics) {
            NumberField(value: checked, range: dial.minMinutes...dial.maxMinutes, unit: "min", metrics: metrics)
                // Left of the field, over the free space, so the row does not move.
                .overlay(alignment: .leading) { [spacing = metrics.rowSpacing] in
                    TransientHint(text: "Max \(Int(limitMinutes)) min", trigger: limitHints)
                        .font(.system(size: metrics.sectionHeaderSize))
                        .foregroundStyle(Color(hex: metrics.sectionHeaderColor))
                        .alignmentGuide(.leading) { $0[.trailing] + spacing }
                }
        }
    }

    /// Whole minutes within the dial; over the limit shows the hint.
    private var checked: Binding<Double> {
        Binding(get: { minutes }, set: { new in
            if new.rounded() > limitMinutes { limitHints += 1 }
            minutes = dial.clamp(minutes: new)
        })
    }

    /// The limit as the field shows it: 59:59 reads as 60.
    private var limitMinutes: Double { dial.maxMinutes.rounded(.up) }
}

/// A number to type, the platform's stepper beside it, and its unit.
private struct NumberField: View {
    let value: Binding<Double>
    let range: ClosedRange<Double>
    let unit: String
    let metrics: SettingsWindowConfig

    var body: some View {
        HStack(spacing: metrics.stepperSpacing) {
            TextField("", value: value, format: .number.precision(.fractionLength(0)))
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .numberKeyboard()
                .frame(width: metrics.fieldWidth)
            Stepper("", value: value, in: range, step: 1)
                .labelsHidden()
            Text(unit)
                .font(.system(size: metrics.labelSize))
                .foregroundStyle(.secondary)
        }
    }
}

struct SoundsTab<Notes: View>: View {
    @Binding var settings: PomodoroCore.Settings
    let sound: SoundOutput
    let metrics: SettingsWindowConfig
    @ViewBuilder let notes: () -> Notes

    private var soundOff: Bool { !settings.sound.soundEnabled }

    var body: some View {
        VStack(spacing: 0) {
            ToggleRow("Play a sound when an interval ends", isOn: $settings.sound.soundEnabled, metrics: metrics)
            FormRow("Work completed sound", metrics: metrics, disabled: soundOff) {
                soundPicker($settings.sound.workCompletedSound)
            }
            FormRow("Break ended sound", metrics: metrics, disabled: soundOff) {
                soundPicker($settings.sound.breakEndedSound)
            }
            FormRow("Volume", metrics: metrics, disabled: soundOff) {
                Slider(value: $settings.sound.volume, in: 0...1) { editing in
                    if !editing { preview(settings.sound.workCompletedSound) }
                }
                .frame(width: metrics.sliderWidth)
                .disabled(soundOff)
            }

            SectionHeader("Notifications", metrics: metrics)

            ToggleRow("Show a notification when an interval ends", isOn: $settings.sound.notificationsEnabled, metrics: metrics)
            notes()
        }
    }

    /// Choosing a sound plays it.
    private func soundPicker(_ selection: Binding<String>) -> some View {
        Picker("", selection: Binding(get: { selection.wrappedValue }, set: { name in
            preview(name)
            selection.wrappedValue = name
        })) {
            ForEach(sound.names, id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ")).tag($0) }
        }
        .labelsHidden()
        .frame(width: metrics.controlWidth)
        .disabled(soundOff)
    }

    private func preview(_ name: String) {
        sound.play(name, volume: settings.sound.volume)
    }
}

private extension View {
    /// Digits only on the phone, in a field filled like the stepper beside it.
    func numberKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.numberPad)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 8))
        #else
        self
        #endif
    }
}
