import PomodoroConfig
import PomodoroCore
import SwiftUI

/// The timer: the Mac's popover, and the phone's main screen with every size
/// the popover's scaled to it. On the Mac the frame is the popover's, so the scale is 1.
public struct TimerView: View {
    let timer: PomodoroTimer
    let config: AppConfig
    /// Before the timer starts: the iPhone asks for notifications then, when the first is due.
    let onStart: () -> Void
    let openSettings: () -> Void

    @State private var draft: String?
    @State private var limitHints = 0
    @FocusState private var editing: Bool

    public init(timer: PomodoroTimer, config: AppConfig, onStart: @escaping () -> Void = {}, openSettings: @escaping () -> Void) {
        self.timer = timer
        self.config = config
        self.onStart = onStart
        self.openSettings = openSettings
    }

    private var popover: PopoverConfig { config.popover }
    private var accent: Color { Color(hex: config.ring.accent(for: timer.phase)) }
    private var secondary: Color { Color(hex: popover.textSecondary) }
    private var background: Color { Color(hex: popover.background) }

    public var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / popover.width, geometry.size.height / popover.height)
            VStack(spacing: 0) {
                header(scale)
                Spacer(minLength: popover.headerToRing * scale)
                dial(config.ring.scaled(scale), scale: scale)
                Spacer(minLength: popover.ringToFooter * scale)
                footer(scale)
            }
            .padding(popover.padding * scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            // A tap anywhere else ends typing.
            .onTapGesture(perform: commitIfEditing)
        }
        .background(background.ignoresSafeArea())
    }

    private func header(_ scale: Double) -> some View {
        HStack(spacing: 0) {
            Text(timer.phase.title)
                .font(config.fonts.phase.font(scale: scale))
                .foregroundStyle(Color(hex: popover.textDim))
            Spacer(minLength: popover.headerSpacing * scale)
            IconButton(icon: config.icons.reset, scale: scale, color: secondary, label: "Stop and reset",
                       minTouch: config.minTouch) {
                commitIfEditing()
                timer.stop()
            }
            .padding(.trailing, max(0, popover.closeButtonInset - popover.padding) * scale)
        }
        .frame(height: popover.headerHeight * scale)
    }

    private func dial(_ ring: RingConfig, scale: Double) -> some View {
        ZStack {
            RingView(
                turnFraction: timer.ringFraction,
                ring: ring,
                color: accent,
                trackColor: Color(hex: ring.trackColor),
                backgroundColor: background,
                touchBand: config.ringTouchBand
            ) {
                commitIfEditing()
                timer.setDuration(fraction: $0)
            }

            digits(scale)
                .frame(width: ring.diameter - ring.lineWidth * 4)
                .offset(y: ring.digitsOffset)

            TransientHint(text: "Max \(TimeFormat.string(from: timer.dial.maxSeconds))", trigger: limitHints)
                .font(config.fonts.hint.font(scale: scale))
                .foregroundStyle(secondary)
                .offset(y: ring.hintOffset)

            TransportButton(isRunning: timer.isRunning, ring: ring, color: accent, minTouch: config.minTouch) {
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
                // On a phone it starts empty, the time as a placeholder: typing
                // replaces it whole. On the Mac it starts with the time, to edit.
                TextField("", text: Binding(get: { draft }, set: { self.draft = $0 }),
                          prompt: Text(timer.timeText).foregroundStyle(accent.opacity(0.35)))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .focused($editing)
                    .onSubmit(commitIfEditing)
                    .onChange(of: editing) { _, focused in
                        if !focused { commitIfEditing() }
                    }
                    .timeKeyboard(cancel: cancelEditing)
                    .task { editing = true }
            } else {
                Text(timer.timeText)
                    .onTapGesture { draft = AppConfig.onPhone ? "" : timer.timeText }
            }
        }
        .font(config.fonts.digits.font(scale: scale))
        .monospacedDigit()
        .foregroundStyle(accent)
        .lineLimit(1)
    }

    private func commitIfEditing() {
        guard let text = draft else { return }
        cancelEditing()
        if timer.setDuration(text: text) { limitHints += 1 }
    }

    private func cancelEditing() {
        draft = nil
        editing = false
    }

    private func footer(_ scale: Double) -> some View {
        HStack(spacing: 0) {
            IconButton(icon: config.icons.skip, scale: scale, color: secondary, label: timer.skipTitle,
                       minTouch: config.minTouch) {
                commitIfEditing()
                timer.skip()
            }
            .frame(width: popover.footerSideWidth * scale, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: popover.counterSpacing * scale) {
                Text("Today").foregroundStyle(secondary)
                Text("\(timer.state.completedToday)").foregroundStyle(accent)
            }
            .font(config.fonts.counter.font(scale: scale))

            Spacer(minLength: 0)

            IconButton(icon: config.icons.settings, scale: scale, color: secondary, label: "Settings",
                       minTouch: config.minTouch) {
                commitIfEditing()
                openSettings()
            }
            .frame(width: popover.footerSideWidth * scale, alignment: .trailing)
        }
        .frame(height: popover.footerHeight * scale)
    }
}

/// A small drawn icon, with a finger-sized touch area around it on a phone.
private struct IconButton: View {
    let icon: IconConfig
    let scale: Double
    let color: Color
    let label: String
    let minTouch: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            icon.image(scale: scale, color: color)
                .frame(minWidth: minTouch, minHeight: minTouch)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}

private extension View {
    /// Typing a time: a keyboard with a colon and Done on the phone, Escape to cancel on the Mac.
    func timeKeyboard(cancel: @escaping () -> Void) -> some View {
        #if os(iOS)
        keyboardType(.numbersAndPunctuation).submitLabel(.done)
        #else
        onExitCommand(perform: cancel)
        #endif
    }
}
