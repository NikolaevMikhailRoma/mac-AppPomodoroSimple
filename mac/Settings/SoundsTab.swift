import SwiftUI
import PomodoroCore
import PomodoroConfig

struct SoundsTab: View {
    @Bindable var store: SettingsStore
    let metrics: SettingsWindowConfig

    private var soundOff: Bool { !store.settings.sound.soundEnabled }

    var body: some View {
        VStack(spacing: 0) {
            FormRow(label: "Play a sound when an interval ends", metrics: metrics) {
                Toggle("", isOn: $store.settings.sound.soundEnabled)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
            }
            FormRow(label: "Work completed sound", metrics: metrics, disabled: soundOff) {
                soundPicker($store.settings.sound.workCompletedSound)
            }
            FormRow(label: "Break ended sound", metrics: metrics, disabled: soundOff) {
                soundPicker($store.settings.sound.breakEndedSound)
            }
            FormRow(label: "Volume", metrics: metrics, disabled: soundOff) {
                Slider(value: $store.settings.sound.volume, in: 0...1)
                    .frame(width: metrics.sliderWidth)
                    .disabled(soundOff)
            }

            SectionHeader(title: "Notifications", metrics: metrics)

            FormRow(label: "Show a notification when an interval ends", metrics: metrics) {
                Toggle("", isOn: $store.settings.sound.notificationsEnabled)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
            }
        }
    }

    private func soundPicker(_ selection: Binding<String>) -> some View {
        Picker("", selection: selection) {
            ForEach(SoundPlayer.names, id: \.self) { Text($0).tag($0) }
        }
        .labelsHidden()
        .frame(width: metrics.controlWidth)
        .disabled(soundOff)
    }
}
