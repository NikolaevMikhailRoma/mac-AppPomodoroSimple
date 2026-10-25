import PomodoroConfig
import PomodoroCore
import SwiftUI

/// A label on the left, its control on the right. A long label wraps and makes the row taller.
public struct FormRow<Content: View>: View {
    let label: String
    let metrics: SettingsWindowConfig
    let disabled: Bool
    let content: Content

    public init(_ label: String, metrics: SettingsWindowConfig, disabled: Bool = false, @ViewBuilder content: () -> Content) {
        self.label = label
        self.metrics = metrics
        self.disabled = disabled
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: metrics.rowSpacing) {
            Text(label)
                .font(.system(size: metrics.labelSize))
                .foregroundStyle(disabled ? Color.secondary : Color(hex: metrics.labelColor))
            Spacer(minLength: metrics.rowSpacing)
            // The label wraps rather than squeeze the control.
            content.fixedSize()
        }
        .frame(minHeight: metrics.rowHeight)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// On or off: a checkbox on the Mac, a switch on the phone, each the platform's own.
public struct ToggleRow: View {
    let label: String
    let isOn: Binding<Bool>
    let metrics: SettingsWindowConfig

    public init(_ label: String, isOn: Binding<Bool>, metrics: SettingsWindowConfig) {
        self.label = label
        self.isOn = isOn
        self.metrics = metrics
    }

    public var body: some View {
        FormRow(label, metrics: metrics) {
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
    }
}

/// The one general setting every platform has.
public struct AutoStartRow: View {
    @Binding var settings: PomodoroCore.Settings
    let metrics: SettingsWindowConfig

    public init(settings: Binding<PomodoroCore.Settings>, metrics: SettingsWindowConfig) {
        _settings = settings
        self.metrics = metrics
    }

    public var body: some View {
        ToggleRow("Auto-start next interval", isOn: $settings.general.autoStartNextInterval, metrics: metrics)
    }
}

public struct SectionHeader: View {
    let title: String
    let metrics: SettingsWindowConfig

    public init(_ title: String, metrics: SettingsWindowConfig) {
        self.title = title
        self.metrics = metrics
    }

    public var body: some View {
        Text(title.uppercased())
            .font(.system(size: metrics.sectionHeaderSize))
            .foregroundStyle(Color(hex: metrics.sectionHeaderColor))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, metrics.sectionTopPadding)
            .padding(.bottom, metrics.sectionBottomPadding)
    }
}

/// Small grey text: a state, an explanation.
public struct Hint: View {
    let text: String
    let metrics: SettingsWindowConfig

    public init(_ text: String, metrics: SettingsWindowConfig) {
        self.text = text
        self.metrics = metrics
    }

    public var body: some View {
        Text(text)
            .font(.system(size: metrics.sectionHeaderSize))
            .foregroundStyle(Color(hex: metrics.sectionHeaderColor))
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Something switched off in the system's settings, and the button that goes there.
public struct HintRow: View {
    let text: String
    let button: String
    let metrics: SettingsWindowConfig
    let action: () -> Void

    public init(_ text: String, button: String, metrics: SettingsWindowConfig, action: @escaping () -> Void) {
        self.text = text
        self.button = button
        self.metrics = metrics
        self.action = action
    }

    public var body: some View {
        HStack(spacing: metrics.rowSpacing) {
            Hint(text, metrics: metrics)
            Spacer(minLength: metrics.rowSpacing)
            Button(button, action: action)
                .fixedSize()
        }
        .frame(minHeight: metrics.rowHeight)
        .fixedSize(horizontal: false, vertical: true)
    }
}
