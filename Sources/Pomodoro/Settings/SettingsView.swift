import SwiftUI
import PomodoroCore
import PomodoroConfig

struct SettingsView: View {
    @Bindable var store: SettingsStore
    let loginItem: LoginItem
    let config: AppConfig

    @State private var tab: SettingsTab = .general

    private var metrics: SettingsWindowConfig { config.settingsWindow }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.swiftUIColor(metrics.background, fallback: .windowBackgroundColor)
                .ignoresSafeArea()

            box
                .padding(.top, metrics.boxTop)
                .padding(.horizontal, metrics.boxMargin)
                .padding(.bottom, metrics.boxMargin)

            tabBar
                .padding(.top, metrics.boxTop - metrics.tabBarHeight / 2)
        }
        .frame(width: metrics.width, height: metrics.height)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(SettingsTab.allCases.enumerated()), id: \.element) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(Theme.swiftUIColor(metrics.tabDivider, fallback: .separatorColor))
                        .frame(width: metrics.tabDividerWidth, height: metrics.tabDividerHeight)
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
                .stroke(Theme.swiftUIColor(metrics.boxBorder, fallback: .separatorColor), lineWidth: metrics.borderWidth)
        )
    }

    private func segment(_ item: SettingsTab) -> some View {
        Button { tab = item } label: {
            Text(item.title)
                .font(.system(size: metrics.tabTextSize))
                .foregroundStyle(Theme.swiftUIColor(metrics.tabTextColor, fallback: .labelColor))
                .padding(.horizontal, metrics.tabPadding)
                .frame(height: metrics.tabBarHeight - metrics.tabInset)
                .background(
                    Group {
                        if tab == item {
                            RoundedRectangle(cornerRadius: metrics.cornerRadius - metrics.innerCornerDelta)
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
                    .stroke(Theme.swiftUIColor(metrics.boxBorder, fallback: .separatorColor), lineWidth: metrics.borderWidth)
            )
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .general: GeneralTab(store: store, loginItem: loginItem, metrics: metrics)
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
