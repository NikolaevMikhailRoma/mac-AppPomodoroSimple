import ActivityKit
import PomodoroConfig
import PomodoroCore

/// The timer on the Lock Screen, as a Live Activity, while it runs or is paused.
@MainActor
final class LockScreenTimer {
    private let ring: RingConfig
    /// The one this app started: a new request can come before the list of activities has it.
    private var activity: Activity<TimerAttributes>?

    init(ring: RingConfig) {
        self.ring = ring
    }

    func show(_ state: EngineState, enabled: Bool) {
        let current = Activity<TimerAttributes>.activities
        // One left from an earlier launch is taken over; any more are ended.
        if activity == nil { activity = current.first }
        let wanted = enabled && state.runState != .idle
        for other in current where !wanted || other.id != activity?.id {
            Task { await other.end(nil, dismissalPolicy: .immediate) }
        }
        guard wanted else {
            activity = nil
            return
        }
        let content = ActivityContent(
            state: TimerAttributes.ContentState(
                title: state.phase.title,
                accent: ring.accent(for: state.phase),
                endsAt: state.endsAt,
                remaining: state.remaining
            ),
            // Then the Lock Screen says the interval is over.
            staleDate: state.endsAt
        )
        if let activity, activity.activityState != .ended, activity.activityState != .dismissed {
            Task { await activity.update(content) }
        } else {
            // Fails with the app in the background or Live Activities switched off; nothing to do then.
            activity = try? Activity.request(attributes: TimerAttributes(), content: content)
        }
    }
}
