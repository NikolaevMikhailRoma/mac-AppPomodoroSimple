import PomodoroCore
import SwiftUI

/// The Mac settings window as a phone screen: the same tabs over the same
/// box, and a tab for the Mac itself, as on Android.
struct SettingsScreen: View {
    let timer: PomodoroTimer
    let alerts: PhoneAlerts
    let sync: SyncClient
    let pair: () -> Void

    private enum Tab: String, CaseIterable {
        case general = "General", intervals = "Intervals", sounds = "Sounds", devices = "Devices"
    }

    @State private var tab = Tab.general
    @State private var limitHints = 0

    var body: some View {
        VStack(spacing: 16) {
            Picker("Tab", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch tab {
                    case .general: general
                    case .intervals: intervals
                    case .sounds: sounds
                    case .devices: devices
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.box, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border))
            }
        }
        .padding(.horizontal, 16)
        .font(Theme.labelFont)
        .foregroundStyle(Theme.label)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    // The number fields commit when they lose focus.
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }

    private func setting<T>(_ path: WritableKeyPath<Settings, T>) -> Binding<T> {
        Binding(
            get: { timer.settings[keyPath: path] },
            set: { value in
                var new = timer.settings
                new[keyPath: path] = value
                timer.update(new)
            }
        )
    }

    @ViewBuilder private var general: some View {
        ToggleRow("Auto-start next interval", isOn: setting(\.general.autoStartNextInterval))
        ToggleRow("Show timer on the Lock Screen", isOn: Binding(get: { alerts.showOnLockScreen }, set: { alerts.setShowOnLockScreen($0) }))
        if alerts.showOnLockScreen, alerts.liveActivitiesDenied {
            BlockedHint(text: "Live Activities are off for Pomodoro in iOS Settings", settings: UIApplication.openSettingsURLString)
        }
    }

    @ViewBuilder private var intervals: some View {
        minutesRow("Work interval", \.intervals.workMinutes)
        minutesRow("Short break", \.intervals.shortBreakMinutes)
        minutesRow("Long break", \.intervals.longBreakMinutes)
        FormRow("Long break after") {
            NumberStepper(value: timer.settings.intervals.longBreakAfter, unit: "intervals") {
                setting(\.intervals.longBreakAfter).wrappedValue = min(max($0, 1), 12)
            }
        }
        // The limit as the fields show it: 59:59 reads as 60.
        TransientHint(text: "Max \(Int(timer.dial.maxMinutes.rounded(.up))) min", trigger: limitHints)
            .font(Theme.secondaryFont)
            .foregroundStyle(Theme.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func minutesRow(_ label: String, _ path: WritableKeyPath<Settings, Double>) -> some View {
        FormRow(label) {
            NumberStepper(value: Int(timer.settings[keyPath: path].rounded()), unit: "min") { minutes in
                if Double(minutes) > timer.dial.maxMinutes.rounded(.up) { limitHints += 1 }
                // At least a minute: 0 here would make a one-second interval.
                setting(path).wrappedValue = timer.dial.clamp(minutes: Double(max(minutes, 1)))
            }
        }
    }

    @ViewBuilder private var sounds: some View {
        let on = timer.settings.sound.soundEnabled
        ToggleRow("Play a sound when an interval ends", isOn: setting(\.sound.soundEnabled))
        Group {
            FormRow("Work completed sound") { soundPicker(\.sound.workCompletedSound) }
            FormRow("Break ended sound") { soundPicker(\.sound.breakEndedSound) }
            FormRow("Volume") {
                Slider(value: setting(\.sound.volume), in: 0...1) { editing in
                    if !editing { timer.sound.play(timer.settings.sound.workCompletedSound, volume: timer.settings.sound.volume) }
                }
                .frame(width: 160)
            }
        }
        .disabled(!on)
        .opacity(on ? 1 : 0.4)

        Text("Notifications")
            .font(Theme.secondaryFont)
            .foregroundStyle(Theme.secondary)
            .padding(.top, 22)
            .padding(.bottom, 4)
        ToggleRow("Show a notification when an interval ends", isOn: setting(\.sound.notificationsEnabled))
        if timer.settings.sound.notificationsEnabled, alerts.notificationsDenied {
            BlockedHint(text: "Notifications are off for Pomodoro in iOS Settings",
                        settings: UIApplication.openNotificationSettingsURLString)
        }
        Text("With the app closed, the sound comes with the notification, at the phone's volume.")
            .font(Theme.secondaryFont)
            .foregroundStyle(Theme.secondary)
            .padding(.vertical, 8)
    }

    private func soundPicker(_ path: WritableKeyPath<Settings, String>) -> some View {
        Picker("Sound", selection: Binding(
            get: { timer.settings[keyPath: path] },
            set: { name in
                timer.sound.play(name, volume: timer.settings.sound.volume)
                setting(path).wrappedValue = name
            }
        )) {
            ForEach(timer.sound.names, id: \.self) { Text(SoundPlayer.title($0)).tag($0) }
        }
        .pickerStyle(.menu)
    }

    /// Like the Mac's Devices tab: the paired Mac in a row, with its state and Forget.
    @ViewBuilder private var devices: some View {
        if sync.isPaired {
            FormRow(sync.pairedTitle) {
                Text(statusText)
                    .font(Theme.secondaryFont)
                    .foregroundStyle(Theme.secondary)
                Button("Forget", action: sync.forget)
            }
        } else {
            Text("Pair with Pomodoro on your Mac to see and control one timer from both, over your Wi-Fi.")
                .padding(.vertical, 12)
        }
        if case .failed(let message) = sync.status {
            Text(message)
                .font(Theme.secondaryFont)
                .foregroundStyle(Theme.secondary)
                .padding(.vertical, 8)
        }
        Button(sync.isPaired ? "Pair again" : "Pair with Mac", action: pair)
            .padding(.vertical, 12)
    }

    private var statusText: String {
        switch sync.status {
        case .connected: return "Connected"
        case .pairing: return "Pairing…"
        case .searching: return "Looking…"
        default: return ""
        }
    }
}

private struct FormRow<Control: View>: View {
    let label: String
    let control: Control

    init(_ label: String, @ViewBuilder control: () -> Control) {
        self.label = label
        self.control = control()
    }

    var body: some View {
        // The label wraps rather than squeeze the control.
        HStack(spacing: 8) {
            Text(label)
            Spacer(minLength: 0)
            control.fixedSize()
        }
        .frame(minHeight: 52)
    }
}

private struct ToggleRow: View {
    let label: String
    let isOn: Binding<Bool>

    init(_ label: String, isOn: Binding<Bool>) {
        self.label = label
        self.isOn = isOn
    }

    var body: some View {
        Toggle(label, isOn: isOn)
            .frame(minHeight: 52)
    }
}

private struct BlockedHint: View {
    let text: String
    let settings: String

    var body: some View {
        HStack {
            Text(text)
                .font(Theme.secondaryFont)
                .foregroundStyle(Theme.secondary)
            Spacer(minLength: 8)
            Button("Allow") {
                if let url = URL(string: settings) { UIApplication.shared.open(url) }
            }
        }
        .frame(minHeight: 40)
    }
}

/// A field and − + : typing commits when the field loses focus.
private struct NumberStepper: View {
    let value: Int
    let unit: String
    let onChange: (Int) -> Void

    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            TextField("", text: $draft)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .focused($focused)
                .frame(width: 44)
                .padding(.vertical, 6)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.border))
                .onChange(of: focused) { _, now in
                    if !now { commit() }
                }
            Stepper(unit, onIncrement: { onChange(value + 1) }, onDecrement: { onChange(value - 1) })
                .labelsHidden()
            Text(unit)
                .foregroundStyle(Theme.secondary)
        }
        .onAppear { draft = "\(value)" }
        .onChange(of: value) { _, new in draft = "\(new)" }
    }

    private func commit() {
        if let typed = Int(draft), typed != value { onChange(typed) }
        // A value clamped back to the old one changes nothing above: show it again.
        draft = "\(value)"
    }
}
