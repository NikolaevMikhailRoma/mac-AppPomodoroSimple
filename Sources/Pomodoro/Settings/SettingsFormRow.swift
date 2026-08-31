import SwiftUI
import PomodoroCore
import PomodoroConfig

struct FormRow<Content: View>: View {
    let label: String
    let metrics: SettingsWindowConfig
    var disabled: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: metrics.rowSpacing) {
            Text(label)
                .font(.system(size: metrics.labelSize))
                .foregroundStyle(
                    disabled
                        ? Color.secondary
                        : Theme.swiftUIColor(metrics.labelColor, fallback: .labelColor)
                )
            Spacer(minLength: metrics.rowSpacing)
            content()
        }
        .frame(height: metrics.rowHeight)
    }
}

struct SectionHeader: View {
    let title: String
    let metrics: SettingsWindowConfig

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: metrics.sectionHeaderSize))
            .foregroundStyle(Theme.swiftUIColor(metrics.sectionHeaderColor, fallback: .secondaryLabelColor))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, metrics.sectionTopPadding)
            .padding(.bottom, metrics.sectionBottomPadding)
    }
}
