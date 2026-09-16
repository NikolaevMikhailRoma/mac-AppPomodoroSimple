import SwiftUI
import PomodoroCore
import PomodoroConfig

struct TimerPopoverView: View {
    let timer: TimerController
    let config: AppConfig
    let openSettings: () -> Void

    @State private var draft: String?
    @State private var limitHints = 0
    @FocusState private var editing: Bool

    private var ring: RingConfig { config.ring }
    private var popover: PopoverConfig { config.popover }

    private var accent: Color {
        Theme.swiftUIColor(
            ring.accent(for: timer.phase),
            fallback: timer.phase == .work ? .systemRed : .systemGreen
        )
    }

    private var secondary: Color {
        Theme.swiftUIColor(popover.textSecondary, fallback: .secondaryLabelColor)
    }

    private var dim: Color {
        Theme.swiftUIColor(popover.textDim, fallback: .tertiaryLabelColor)
    }

    private var background: Color {
        Theme.swiftUIColor(popover.background, fallback: .windowBackgroundColor)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: popover.headerHeight)

            Spacer(minLength: 0).frame(height: popover.headerToRing)

            dial

            Spacer(minLength: 0).frame(height: popover.ringToFooter)

            footer
                .frame(height: popover.footerHeight)
        }
        .padding(popover.padding)
        .frame(width: popover.width, height: popover.height)
        .background(background)
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text(timer.phase.title)
                .font(Theme.font(config.fonts.phase))
                .foregroundStyle(dim)
            Spacer(minLength: popover.headerSpacing)
            Button(action: { commitIfEditing(); timer.stop() }) {
                Theme.icon(config.icons.reset, color: secondary)
            }
            .buttonStyle(.plain)
            .help("Stop and reset")
            .padding(.trailing, max(0, popover.closeButtonInset - popover.padding))
        }
    }

    private var dial: some View {
        ZStack {
            RingView(
                turnFraction: timer.ringFraction,
                ring: ring,
                color: accent,
                trackColor: Theme.swiftUIColor(ring.trackColor, fallback: .separatorColor),
                backgroundColor: background,
                onDrag: { timer.setDuration(fraction: $0) }
            )

            digits
                .offset(y: ring.digitsOffset)

            TransientHint(
                text: "Max \(TimeFormat.string(from: timer.dial.maxSeconds))",
                trigger: limitHints
            )
            .font(Theme.font(config.fonts.hint))
            .foregroundStyle(secondary)
            .offset(y: ring.hintOffset)

            TransportButton(
                isRunning: timer.isRunning,
                ring: ring,
                color: accent,
                action: { commitIfEditing(); timer.toggle() }
            )
            .offset(y: ring.playOffset)
        }
        .frame(width: ring.diameter, height: ring.diameter)
    }

    private var digits: some View {
        Group {
            if let draft {
                TextField("", text: Binding(get: { draft }, set: { self.draft = $0 }))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .focused($editing)
                    .onSubmit(commit)
                    .onExitCommand { cancelEditing() }
                    .onChange(of: editing) { _, focused in
                        if !focused { commit() }
                    }
            } else {
                Text(timer.timeText)
                    .onTapGesture { beginEditing() }
            }
        }
        .font(Theme.font(config.fonts.digits))
        .monospacedDigit()
        .foregroundStyle(accent)
        .frame(width: ring.diameter - ring.lineWidth * 4)
    }

    private func beginEditing() {
        draft = timer.timeText
        editing = true
    }

    private func commit() {
        if let draft, timer.setDuration(text: draft) { limitHints += 1 }
        cancelEditing()
    }

    private func cancelEditing() {
        draft = nil
        editing = false
    }

    private func commitIfEditing() {
        if draft != nil { commit() }
    }

    private var footer: some View {
        HStack(spacing: 0) {
            FooterButton(
                icon: config.icons.skip,
                color: secondary,
                help: timer.skipTitle,
                action: { commitIfEditing(); timer.skip() }
            )
            .frame(width: popover.footerSideWidth, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: popover.counterSpacing) {
                Text("Today")
                    .foregroundStyle(secondary)
                Text("\(timer.completedToday)")
                    .foregroundStyle(accent)
            }
            .font(Theme.font(config.fonts.counter))

            Spacer(minLength: 0)

            FooterButton(
                icon: config.icons.settings,
                color: secondary,
                help: "Settings",
                action: openSettings
            )
            .frame(width: popover.footerSideWidth, alignment: .trailing)
        }
    }
}

private struct FooterButton: View {
    let icon: IconConfig
    let color: Color
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Theme.icon(icon, color: color)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
