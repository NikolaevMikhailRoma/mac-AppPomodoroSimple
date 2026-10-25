import ActivityKit
import SwiftUI
import WidgetKit

@main
struct TimerWidgets: WidgetBundle {
    var body: some Widget {
        TimerLiveActivity()
    }
}

/// The running timer on the Lock Screen (and in the Dynamic Island, on the
/// phones that have one), with the one button the Android shade row has.
struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerAttributes.self) { context in
            LockScreenView(state: context.state, finished: context.isStale)
                .activityBackgroundTint(Color(hex: Style.background))
                .activitySystemActionForegroundColor(Color(hex: Style.secondary))
        } dynamicIsland: { context in
            let accent = Color(hex: context.state.accent)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Title(state: context.state, finished: context.isStale)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ToggleButton(running: context.state.endsAt != nil, accent: accent)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Countdown(state: context.state, size: 40)
                }
            } compactLeading: {
                Image(systemName: "timer").foregroundStyle(accent)
            } compactTrailing: {
                Countdown(state: context.state, size: 15).frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "timer").foregroundStyle(accent)
            }
        }
    }
}

/// The app's colours; config.json is not part of the extension.
private enum Style {
    static let background = "#252525"
    static let secondary = "#C8C8C8"
}

private extension Color {
    /// "#EC958C". Not PomodoroUI's: linking that for one colour made the extension six times bigger.
    init(hex: String) {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0xFFFFFF
        self.init(red: Double(value >> 16 & 0xFF) / 255, green: Double(value >> 8 & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}

private struct LockScreenView: View {
    let state: TimerAttributes.ContentState
    let finished: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Title(state: state, finished: finished)
                Countdown(state: state, size: 44)
            }
            Spacer()
            ToggleButton(running: state.endsAt != nil, accent: Color(hex: state.accent))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

private struct Title: View {
    let state: TimerAttributes.ContentState
    let finished: Bool

    var body: some View {
        Text(finished ? "Interval finished" : state.title)
            .font(.custom("HelveticaNeue-Light", size: 15))
            .foregroundStyle(Color(hex: Style.secondary))
    }
}

/// The system counts a running timer down by itself; a paused one stands still.
private struct Countdown: View {
    let state: TimerAttributes.ContentState
    let size: Double

    var body: some View {
        Group {
            if let endsAt = state.endsAt {
                // A range must not end before it starts: after the end it shows 0:00.
                Text(timerInterval: min(Date(), endsAt)...endsAt, countsDown: true)
            } else {
                Text(Duration.seconds(state.remaining.rounded(.up)).formatted(.time(pattern: .minuteSecond)))
            }
        }
        .font(.custom("HelveticaNeue-Thin", size: size))
        .monospacedDigit()
        .foregroundStyle(Color(hex: state.accent))
    }
}

private struct ToggleButton: View {
    let running: Bool
    let accent: Color

    var body: some View {
        Button(intent: ToggleTimerIntent()) {
            Image(systemName: running ? "pause" : "play")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(accent)
                .frame(width: 50, height: 50)
                .overlay(Circle().stroke(accent, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(running ? "Pause" : "Resume")
    }
}
