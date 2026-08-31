import SwiftUI
import ServiceManagement
import PomodoroCore

/// Three tabs, matching the only parts of the reference app that earn their
/// place: General, Intervals, Notifications & Sounds.
///
/// The tab strip is a segmented picker rather than SwiftUI's `TabView`. On
/// macOS 15 a plain `TabView` in a window without a toolbar collapses its tabs
/// into a `>>` overflow menu, which buries Intervals behind two clicks. A
/// picker is one control, always shows all three, and looks like the
/// segmented control the reference app uses.
struct SettingsView: View {

    @Bindable var store: SettingsStore
    let config: AppConfig

    @State private var tab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(SettingsTab.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 20)
            .padding(.top, 14)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: SettingsWindowController.size.width,
               height: SettingsWindowController.size.height)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .general: GeneralTab(store: store)
        case .intervals: IntervalsTab(store: store, config: config)
        case .sounds: SoundsTab(store: store)
        }
    }
}

enum SettingsTab: CaseIterable, Identifiable {
    case general, intervals, sounds

    var id: Self { self }

    var title: String {
        switch self {
        case .general: return "General"
        case .intervals: return "Intervals"
        case .sounds: return "Notifications & Sounds"
        }
    }
}

// MARK: - General

private struct GeneralTab: View {
    @Bindable var store: SettingsStore

    var body: some View {
        Form {
            Picker("Appearance", selection: $store.settings.general.appearance) {
                ForEach(Appearance.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Toggle("Launch at startup", isOn: Binding(
                get: { store.settings.general.launchAtStartup },
                set: { store.settings.general.launchAtStartup = LoginItem.set($0) }
            ))
            Toggle("Show timer in menu bar", isOn: $store.settings.general.showTimerInMenuBar)
            Toggle("Auto-start next interval", isOn: $store.settings.general.autoStartNextInterval)
        }
        .formStyle(.grouped)
    }
}

// MARK: - Intervals

private struct IntervalsTab: View {
    @Bindable var store: SettingsStore
    let config: AppConfig

    /// The reference app only offered a dropdown of fixed lengths. Here every
    /// duration is a plain number field, so any value can be typed.
    var body: some View {
        Form {
            MinutesField(
                "Work interval",
                minutes: $store.settings.intervals.workMinutes,
                dial: config.dial
            )
            MinutesField(
                "Short break",
                minutes: $store.settings.intervals.shortBreakMinutes,
                dial: config.dial
            )
            MinutesField(
                "Long break",
                minutes: $store.settings.intervals.longBreakMinutes,
                dial: config.dial
            )
            Stepper(
                "Long break after \(store.settings.intervals.longBreakAfter) intervals",
                value: $store.settings.intervals.longBreakAfter,
                in: 1...12
            )
        }
        .formStyle(.grouped)
    }
}

/// A number field plus stepper, clamped to the range in `config.json`.
private struct MinutesField: View {
    let label: String
    @Binding var minutes: Double
    let dial: DialConfig

    init(_ label: String, minutes: Binding<Double>, dial: DialConfig) {
        self.label = label
        self._minutes = minutes
        self.dial = dial
    }

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("", value: $minutes, format: .number.precision(.fractionLength(0)))
                .labelsHidden()
                .frame(width: 56)
                .multilineTextAlignment(.trailing)
                .onChange(of: minutes) { _, new in
                    let clamped = dial.dial.clamp(minutes: new)
                    if clamped != new { minutes = clamped }
                }
            Stepper("", value: $minutes, in: dial.minMinutes...dial.maxMinutes, step: 1)
                .labelsHidden()
            Text("min").foregroundStyle(.secondary)
        }
    }
}

// MARK: - Notifications & Sounds

private struct SoundsTab: View {
    @Bindable var store: SettingsStore

    var body: some View {
        Form {
            Toggle("Play a sound when an interval ends", isOn: $store.settings.sound.soundEnabled)
            Picker("Work completed sound", selection: $store.settings.sound.workCompletedSound) {
                ForEach(SoundPlayer.names, id: \.self) { Text($0).tag($0) }
            }
            .disabled(!store.settings.sound.soundEnabled)
            Picker("Break ended sound", selection: $store.settings.sound.breakEndedSound) {
                ForEach(SoundPlayer.names, id: \.self) { Text($0).tag($0) }
            }
            .disabled(!store.settings.sound.soundEnabled)
            HStack {
                Text("Volume")
                Slider(value: $store.settings.sound.volume, in: 0...1)
            }
            .disabled(!store.settings.sound.soundEnabled)
            Toggle("Show a notification when an interval ends",
                   isOn: $store.settings.sound.notificationsEnabled)
        }
        .formStyle(.grouped)
    }
}

// MARK: - Login item

/// Registering as a login item only works from a packaged, signed `.app`.
/// A failure reports back so the toggle snaps to what actually happened.
private enum LoginItem {
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
