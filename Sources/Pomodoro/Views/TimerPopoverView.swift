import SwiftUI
import PomodoroCore

/// The main screen, laid out to the measurements taken off the reference.
///
/// The vertical rhythm is additive and adds up to the popover's height:
/// padding 14 + header 22 + gap 39 + ring 196 + gap 28 + footer 22 + padding 14.
/// That puts the top of the ring 75 pt below the content's top edge, where the
/// original has it at 75.25.
struct TimerPopoverView: View {

    let timer: TimerController
    let config: AppConfig
    let openSettings: () -> Void

    /// Set while the digits are being typed over.
    @State private var draft: String?
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

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 0) {
            Text(timer.phase.title)
                .font(Theme.font(config.fonts.phase))
                .foregroundStyle(dim)
            Spacer(minLength: 8)
            Button(action: { commitIfEditing(); timer.stop() }) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: ring.closeButtonSize, weight: .ultraLight))
                    .foregroundStyle(secondary)
            }
            .buttonStyle(.plain)
            .help("Stop and reset")
            // The reference leaves a wider gap on the right than the popover's
            // own padding, so the button is not jammed into the corner.
            .padding(.trailing, max(0, popover.closeButtonInset - popover.padding))
        }
    }

    // MARK: - Dial

    private var dial: some View {
        ZStack {
            RingView(
                fraction: timer.ringFraction,
                color: accent,
                trackColor: Theme.swiftUIColor(ring.trackColor, fallback: .separatorColor),
                backgroundColor: background,
                diameter: ring.diameter,
                lineWidth: ring.lineWidth,
                handleDiameter: ring.handleDiameter,
                handleLineWidth: ring.handleLineWidth,
                onDrag: { timer.setDuration(fraction: $0) }
            )

            digits
                .offset(y: ring.digitsOffset)

            TransportButton(
                isRunning: timer.isRunning,
                color: accent,
                side: ring.playSide,
                lineWidth: ring.playLineWidth,
                action: { commitIfEditing(); timer.toggle() }
            )
            .offset(y: ring.playOffset)
        }
        .frame(width: ring.diameter, height: ring.diameter)
    }

    /// Click to type a new length. Anything unparseable leaves the old value.
    /// Available at any time, including mid-countdown.
    ///
    /// The draft is committed when the field loses focus, not only on Enter.
    /// Without that it outlives the edit: the field keeps showing what was
    /// typed while the countdown carries on underneath, which reads as a
    /// frozen timer.
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
        if let draft { timer.setDuration(text: draft) }
        cancelEditing()
    }

    /// Drops the draft without applying it, so the digits go back to showing
    /// the live countdown.
    private func cancelEditing() {
        draft = nil
        editing = false
    }

    private func commitIfEditing() {
        if draft != nil { commit() }
    }

    // MARK: - Footer

    /// Skip on the left, the day's count centred, settings on the right. The
    /// two side slots are the same width so the counter lands on the middle.
    private var footer: some View {
        HStack(spacing: 0) {
            FooterButton(
                systemName: "forward.end",
                size: 15,
                color: secondary,
                help: "Skip interval",
                action: { commitIfEditing(); timer.skip() }
            )
            .frame(width: 44, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Text("Today")
                    .foregroundStyle(secondary)
                Text("\(timer.completedToday)")
                    .foregroundStyle(accent)
            }
            .font(Theme.font(config.fonts.counter))

            Spacer(minLength: 0)

            FooterButton(
                systemName: "gearshape",
                size: 18,
                color: secondary,
                help: "Settings",
                action: openSettings
            )
            .frame(width: 44, alignment: .trailing)
        }
    }
}

/// A bare icon button — the footer has no button chrome in the reference, and
/// SwiftUI's default `Menu` styling was what drew the green pill here before.
private struct FooterButton: View {
    let systemName: String
    let size: Double
    let color: Color
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .ultraLight))
                .foregroundStyle(color)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
