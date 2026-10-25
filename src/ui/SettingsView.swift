import PomodoroConfig
import PomodoroCore
import SwiftUI

public enum SettingsTab: CaseIterable, Identifiable, Sendable {
    case general, intervals, sounds, devices

    public var id: Self { self }

    public init?(name: String) {
        guard let match = Self.allCases.first(where: { String(describing: $0) == name }) else { return nil }
        self = match
    }

    /// The short one where the long ones do not fit: on a phone.
    func title(short: Bool) -> String {
        switch self {
        case .general: return "General"
        case .intervals: return "Intervals"
        case .sounds: return short ? "Sounds" : "Notifications & Sounds"
        case .devices: return "Devices"
        }
    }
}

/// The settings window: tabs across the top edge of a box, form rows inside.
/// The same on the Mac and the phone; what only one of them has comes in
/// through `general`, `soundNotes` and `devices`.
public struct SettingsView<General: View, SoundNotes: View, Devices: View>: View {
    @Binding var settings: PomodoroCore.Settings
    let sound: SoundOutput
    let config: AppConfig
    let general: General
    let soundNotes: SoundNotes
    let devices: Devices

    @State private var tab: SettingsTab

    public init(
        settings: Binding<PomodoroCore.Settings>,
        sound: SoundOutput,
        config: AppConfig,
        tab: SettingsTab = .general,
        @ViewBuilder general: () -> General,
        @ViewBuilder soundNotes: () -> SoundNotes,
        @ViewBuilder devices: () -> Devices
    ) {
        _settings = settings
        self.sound = sound
        self.config = config
        self.general = general()
        self.soundNotes = soundNotes()
        self.devices = devices()
        _tab = State(initialValue: tab)
    }

    private var metrics: SettingsWindowConfig { config.settingsMetrics }

    public var body: some View {
        ZStack(alignment: .top) {
            Color(hex: metrics.background)
                .ignoresSafeArea()

            box
                .padding(.top, metrics.boxTop)
                .padding(.horizontal, metrics.boxMargin)
                .padding(.bottom, metrics.boxMargin)

            ViewThatFits(in: .horizontal) {
                tabBar(short: false)
                tabBar(short: true)
            }
            .padding(.horizontal, metrics.boxMargin)
            .padding(.top, metrics.boxTop - metrics.tabBarHeight / 2)
        }
    }

    private func tabBar(short: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(SettingsTab.allCases.enumerated()), id: \.element) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(Color(hex: metrics.tabDivider))
                        .frame(width: metrics.tabDividerWidth, height: metrics.tabDividerHeight)
                }
                segment(item, short: short)
            }
        }
        .frame(height: metrics.tabBarHeight)
        .background(
            RoundedRectangle(cornerRadius: metrics.cornerRadius)
                .fill(Color(hex: metrics.tabBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: metrics.cornerRadius)
                .stroke(Color(hex: metrics.boxBorder), lineWidth: metrics.borderWidth)
        )
    }

    private func segment(_ item: SettingsTab, short: Bool) -> some View {
        // A finger needs more height than the bar has.
        let reach = max(0, config.minTouch - metrics.tabBarHeight) / 2
        return Button { tab = item } label: {
            Text(item.title(short: short))
                .font(.system(size: metrics.tabTextSize))
                .foregroundStyle(Color(hex: metrics.tabTextColor))
                .padding(.horizontal, metrics.tabPadding)
                .frame(height: metrics.tabBarHeight - metrics.tabInset)
                .background(
                    Group {
                        if tab == item {
                            RoundedRectangle(cornerRadius: metrics.cornerRadius - metrics.innerCornerDelta)
                                .fill(Color(hex: metrics.tabSelectedFill))
                        }
                    }
                )
                .contentShape(Rectangle().inset(by: -reach))
        }
        .buttonStyle(.plain)
    }

    private var box: some View {
        // A tab taller than the box, on a small phone or over the keyboard, scrolls.
        ViewThatFits(in: .vertical) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(insets)
            ScrollView {
                content
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(insets)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: metrics.cornerRadius)
                .fill(Color(hex: metrics.boxBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: metrics.cornerRadius)
                .stroke(Color(hex: metrics.boxBorder), lineWidth: metrics.borderWidth)
        )
    }

    private var insets: EdgeInsets {
        EdgeInsets(top: metrics.contentTop, leading: metrics.boxPadding,
                   bottom: metrics.boxPadding, trailing: metrics.boxPadding)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .general: VStack(spacing: 0) { general }
        case .intervals: IntervalsTab(settings: $settings, config: config)
        case .sounds: SoundsTab(settings: $settings, sound: sound, metrics: metrics) { soundNotes }
        case .devices: devices
        }
    }
}
