import SwiftUI
import PomodoroCore

/// The whole main screen: phase name, gear menu, ring with editable digits,
/// play/pause and stop, and the day's count.
struct TimerPopoverView: View {

    let timer: TimerController
    let config: AppConfig
    let openSettings: () -> Void
    let quit: () -> Void

    /// Set while the digits are being typed over.
    @State private var draft: String?
    @FocusState private var editing: Bool

    private var accent: Color {
        Theme.swiftUIColor(
            timer.phase == .work ? config.ring.workColor : config.ring.breakColor,
            fallback: timer.phase == .work ? .systemRed : .systemGreen
        )
    }

    private var secondary: Color {
        Theme.swiftUIColor(config.popover.secondaryTextColor, fallback: .secondaryLabelColor)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 8)
            ring
            Spacer(minLength: 8)
            controls
            Spacer(minLength: 10)
            Text("Today \(timer.completedToday)")
                .font(.system(size: 12))
                .foregroundStyle(secondary)
        }
        .padding(14)
        .frame(width: config.popover.width, height: config.popover.height)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(timer.phase.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(secondary)
            Spacer()
            Menu {
                Button("Skip interval") { timer.skip() }
                Divider()
                Button("Settings…") { openSettings() }
                Button("Quit Pomodoro") { quit() }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundStyle(secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 22)
        }
    }

    // MARK: - Ring

    private var ring: some View {
        ZStack {
            RingView(
                fraction: timer.ringFraction,
                color: accent,
                trackColor: Theme.swiftUIColor(config.ring.trackColor, fallback: .separatorColor),
                diameter: config.ring.diameter,
                lineWidth: config.ring.lineWidth,
                handleDiameter: config.ring.handleDiameter,
                showsHandle: timer.isEditable,
                onDrag: { timer.setDuration(fraction: $0) }
            )
            digits
        }
    }

    /// Click to type a new length. Anything unparseable leaves the old value.
    private var digits: some View {
        Group {
            if let draft {
                TextField("", text: Binding(get: { draft }, set: { self.draft = $0 }))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .focused($editing)
                    .onSubmit(commit)
                    .onExitCommand { self.draft = nil }
            } else {
                Text(timer.timeText)
                    .onTapGesture { beginEditing() }
            }
        }
        .font(.system(size: config.ring.timeFontSize, weight: .thin, design: .default))
        .monospacedDigit()
        .foregroundStyle(accent)
        .frame(width: config.ring.diameter - config.ring.lineWidth * 4)
    }

    private func beginEditing() {
        guard timer.isEditable else { return }
        draft = timer.timeText
        editing = true
    }

    private func commit() {
        if let draft { timer.setDuration(text: draft) }
        draft = nil
        editing = false
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 26) {
            CircleButton(
                systemName: timer.isRunning ? "pause.fill" : "play.fill",
                color: accent,
                help: timer.isRunning ? "Pause" : "Start",
                action: { commitIfEditing(); timer.toggle() }
            )
            CircleButton(
                systemName: "stop.fill",
                color: secondary,
                help: "Stop and reset",
                action: { commitIfEditing(); timer.stop() }
            )
        }
    }

    private func commitIfEditing() {
        if draft != nil { commit() }
    }
}

/// A flat round icon button — the only button shape the popover uses.
private struct CircleButton: View {
    let systemName: String
    let color: Color
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(color.opacity(0.5), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
