import SwiftUI
import PomodoroCore
import PomodoroConfig

struct SoundsTab: View {
    @Binding var settings: PomodoroCore.Settings
    let names: [String]
    let metrics: SettingsWindowConfig

    private var soundOff: Bool { !settings.sound.soundEnabled }

    var body: some View {
        VStack(spacing: 0) {
            FormRow(label: "Play a sound when an interval ends", metrics: metrics) {
                Toggle("", isOn: $settings.sound.soundEnabled)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
            }
            FormRow(label: "Work completed sound", metrics: metrics, disabled: soundOff) {
                soundPicker($settings.sound.workCompletedSound)
            }
            FormRow(label: "Break ended sound", metrics: metrics, disabled: soundOff) {
                soundPicker($settings.sound.breakEndedSound)
            }
            FormRow(label: "Volume", metrics: metrics, disabled: soundOff) {
                Slider(value: $settings.sound.volume, in: 0...1)
                    .frame(width: metrics.sliderWidth)
                    .disabled(soundOff)
            }

            SectionHeader(title: "Notifications", metrics: metrics)

            FormRow(label: "Show a notification when an interval ends", metrics: metrics) {
                Toggle("", isOn: $settings.sound.notificationsEnabled)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
            }
        }
    }

    private func soundPicker(_ selection: Binding<String>) -> some View {
        Picker("", selection: selection) {
            ForEach(names, id: \.self) { Text($0).tag($0) }
        }
        .labelsHidden()
        .frame(width: metrics.controlWidth)
        .disabled(soundOff)
    }
}
