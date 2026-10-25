import PomodoroConfig
import PomodoroCore
import SwiftUI

/// The Mac popover, laid out for a phone: header at the top, ring in the
/// middle, footer at the bottom, every size the popover's scaled to the screen.
struct TimerScreen: View {
    let timer: PomodoroTimer
    let config: AppConfig
    /// Before the timer starts: the first start is when a notification is first due.
    let onStart: () -> Void
    let openSettings: () -> Void

    @State private var draft: String?
    @State private var limitHints = 0
    @FocusState private var editing: Bool

    private var popover: PopoverConfig { config.popover }
    private var accent: Color { Color(hex: config.ring.accent(for: timer.state.phase)) }
    private var secondary: Color { Color(hex: popover.textSecondary) }

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / popover.width, geometry.size.height / popover.height)
            VStack(spacing: 0) {
                header(scale)
                Spacer(minLength: 0)
                dial(config.ring.scaled(scale), scale: scale)
                Spacer(minLength: 0)
                footer(scale)
            }
            .padding(popover.padding * scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            // A tap anywhere else ends typing, like clicking away on the Mac.
            .onTapGesture(perform: commitIfEditing)
        }
        .background(Color(hex: popover.background).ignoresSafeArea())
    }

    private func header(_ scale: Double) -> some View {
        HStack(spacing: 0) {
            Text(timer.state.phase.title)
                .font(Theme.font(config.fonts.phase, scale: scale))
                .foregroundStyle(Color(hex: popover.textDim))
            Spacer(minLength: 0)
            IconButton(icon: config.icons.reset, scale: scale, color: secondary, label: "Stop and reset") {
                commitIfEditing()
                timer.stop()
            }
        }
        .frame(height: popover.headerHeight * scale)
    }

    private func dial(_ ring: RingConfig, scale: Double) -> some View {
        ZStack {
            RingView(
                turnFraction: timer.dial.fraction(forSeconds: timer.state.remaining),
                ring: ring,
                color: accent,
                trackColor: Color(hex: ring.trackColor),
                backgroundColor: Color(hex: popover.background)
            ) {
                commitIfEditing()
                timer.setDuration(fraction: $0)
            }

            digits(scale)
                .frame(width: ring.diameter - ring.lineWidth * 4)
                .offset(y: ring.digitsOffset)

            TransientHint(text: "Max \(TimeFormat.string(from: timer.dial.maxSeconds))", trigger: limitHints)
                .font(Theme.font(config.fonts.hint, scale: scale))
                .foregroundStyle(secondary)
                .offset(y: ring.hintOffset)

            TransportButton(isRunning: timer.isRunning, ring: ring, color: accent) {
                commitIfEditing()
                if !timer.isRunning { onStart() }
                timer.toggle()
            }
            .offset(y: ring.playOffset)
        }
        .frame(width: ring.diameter, height: ring.diameter)
    }

    private func digits(_ scale: Double) -> some View {
        Group {
            if let draft {
                // Starts empty, the time as a placeholder: typing replaces it whole.
                TextField("", text: Binding(get: { draft }, set: { self.draft = $0 }),
                          prompt: Text(timer.timeText).foregroundStyle(accent.opacity(0.35)))
                    .keyboardType(.numbersAndPunctuation)
                    .submitLabel(.done)
                    .multilineTextAlignment(.center)
                    .focused($editing)
                    .onSubmit(commitIfEditing)
                    .onChange(of: editing) { _, focused in
                        if !focused { commitIfEditing() }
                    }
                    .task { editing = true }
            } else {
                Text(timer.timeText)
                    .onTapGesture { draft = "" }
            }
        }
        .font(Theme.font(config.fonts.digits, scale: scale))
        .monospacedDigit()
        .foregroundStyle(accent)
        .lineLimit(1)
    }

    private func commitIfEditing() {
        guard let text = draft else { return }
        draft = nil
        editing = false
        if !text.isEmpty, timer.setDuration(text: text) { limitHints += 1 }
    }

    private func footer(_ scale: Double) -> some View {
        HStack(spacing: 0) {
            IconButton(icon: config.icons.skip, scale: scale, color: secondary, label: timer.skipTitle) {
                commitIfEditing()
                timer.skip()
            }
            .frame(width: popover.footerSideWidth * scale, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: popover.counterSpacing * scale) {
                Text("Today").foregroundStyle(secondary)
                Text("\(timer.state.completedToday)").foregroundStyle(accent)
            }
            .font(Theme.font(config.fonts.counter, scale: scale))

            Spacer(minLength: 0)

            IconButton(icon: config.icons.settings, scale: scale, color: secondary, label: "Settings") {
                commitIfEditing()
                openSettings()
            }
            .frame(width: popover.footerSideWidth * scale, alignment: .trailing)
        }
        .frame(height: popover.footerHeight * scale)
    }
}

/// A small drawn icon with a finger-sized touch area around it.
private struct IconButton: View {
    let icon: IconConfig
    let scale: Double
    let color: Color
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Theme.icon(icon, scale: scale, color: color)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

extension RingConfig {
    /// Every length in points times `scale`; ratios and colours stay.
    func scaled(_ scale: Double) -> RingConfig {
        var ring = self
        ring.diameter *= scale
        ring.lineWidth *= scale
        ring.handleDiameter *= scale
        ring.handleLineWidth *= scale
        ring.digitsOffset *= scale
        ring.playOffset *= scale
        ring.hintOffset *= scale
        ring.playSide *= scale
        ring.playLineWidth *= scale
        return ring
    }
}
