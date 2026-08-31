import SwiftUI
import ServiceManagement
import PomodoroCore

/// Three tabs, matching the only parts of the reference app that earn their
/// place: General, Intervals, Notifications & Sounds.
///
/// Laid out to the grid measured off the reference: a bordered box inset 20 pt
/// from the window with 24 pt of padding inside, rows on a 27 pt pitch, labels
/// flush left and controls flush right. Unlike the popover this uses the system
/// font — the reference's own settings are plain AppKit, so matching them means
/// matching macOS rather than importing Helvetica Neue.
struct SettingsView: View {

    @Bindable var store: SettingsStore
    let config: AppConfig

    @State private var tab: SettingsTab = .general

    private var metrics: SettingsWindowConfig { config.settingsWindow }

    /// Distance from the top of the content area to the top of the box. The
    /// reference has the box 70 pt below the window's top edge, and the title
    /// bar accounts for the first 28 of those.
    private var boxTop: Double { 42 }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.swiftUIColor(metrics.windowBackground, fallback: .windowBackgroundColor)
                .ignoresSafeArea()

            box
                .padding(.top, boxTop)
                .padding(.horizontal, metrics.boxMargin)
                .padding(.bottom, metrics.boxMargin)

            // The tab bar straddles the box's top border, which is the detail
            // that makes the window read as the original.
            tabBar
                .padding(.top, boxTop - metrics.tabBarHeight / 2)
        }
        .frame(width: metrics.width, height: metrics.height)
    }

    /// A hand-built segmented bar rather than SwiftUI's segmented `Picker`.
    /// The picker splits its width evenly, which clipped "Notifications &
    /// Sounds"; the reference sizes each segment to its text — 59.5 pt for
    /// General against 152 for the long one.
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(SettingsTab.allCases.enumerated()), id: \.element) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(Theme.swiftUIColor(metrics.tabDivider, fallback: .separatorColor))
                        .frame(width: 1, height: 12)
                }
                segment(item)
            }
        }
        .frame(height: metrics.tabBarHeight)
        .background(
            RoundedRectangle(cornerRadius: metrics.cornerRadius)
                .fill(Theme.swiftUIColor(metrics.tabBackground, fallback: .controlColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: metrics.cornerRadius)
                .stroke(Theme.swiftUIColor(metrics.boxBorder, fallback: .separatorColor), lineWidth: 1)
        )
    }

    private func segment(_ item: SettingsTab) -> some View {
        Button { tab = item } label: {
            Text(item.title)
                .font(.system(size: metrics.tabTextSize))
                .foregroundStyle(Theme.swiftUIColor(metrics.tabTextColor, fallback: .labelColor))
                .padding(.horizontal, 8)
                .frame(height: metrics.tabBarHeight - 2)
                .background(
                    Group {
                        if tab == item {
                            RoundedRectangle(cornerRadius: metrics.cornerRadius - 1)
                                .fill(Theme.swiftUIColor(metrics.tabSelectedFill, fallback: .selectedControlColor))
                        }
                    }
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var box: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(metrics.boxPadding)
            .background(
                RoundedRectangle(cornerRadius: metrics.cornerRadius)
                    .fill(Theme.swiftUIColor(metrics.boxBackground, fallback: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: metrics.cornerRadius)
                    .stroke(Theme.swiftUIColor(metrics.boxBorder, fallback: .separatorColor), lineWidth: 1)
            )
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .general: GeneralTab(store: store, metrics: metrics)
        case .intervals: IntervalsTab(store: store, config: config)
        case .sounds: SoundsTab(store: store, metrics: metrics)
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

// MARK: - Shared row shapes

/// One line of the form: label flush left, control flush right, fixed height.
private struct FormRow<Content: View>: View {
    let label: String
    let metrics: SettingsWindowConfig
    var disabled: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: metrics.labelSize))
                .foregroundStyle(
                    disabled
                        ? Color.secondary
                        : Theme.swiftUIColor(metrics.labelColor, fallback: .labelColor)
                )
            Spacer(minLength: 8)
            content()
        }
        .frame(height: metrics.rowHeight)
    }
}

/// Centred, uppercase, no tracking — the reference's own combination, which is
/// unusual for macOS (labels stay left-aligned) and is what the eye recognises.
private struct SectionHeader: View {
    let title: String
    let metrics: SettingsWindowConfig

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: metrics.sectionHeaderSize))
            .foregroundStyle(Theme.swiftUIColor(metrics.sectionHeaderColor, fallback: .secondaryLabelColor))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 22)
            .padding(.bottom, 12)
    }
}

// MARK: - General

private struct GeneralTab: View {
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

// MARK: - Intervals

private struct IntervalsTab: View {
    @Bindable var store: SettingsStore
    let config: AppConfig

    private var metrics: SettingsWindowConfig { config.settingsWindow }

    /// The reference only offered a dropdown of fixed lengths. Here every
    /// duration is a plain number field, so any value can be typed.
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

/// A number field plus stepper, clamped to the range in `config.json`.
private struct MinutesRow: View {
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

// MARK: - Notifications & Sounds

private struct SoundsTab: View {
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
                    .frame(width: 200)
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
