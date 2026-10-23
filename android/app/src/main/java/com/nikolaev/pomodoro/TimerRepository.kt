package com.nikolaev.pomodoro

import android.content.Context
import androidx.core.content.edit
import com.nikolaev.pomodoro.core.DurationDial
import com.nikolaev.pomodoro.core.EngineEvent
import com.nikolaev.pomodoro.core.EngineState
import com.nikolaev.pomodoro.core.IntervalSettings
import com.nikolaev.pomodoro.core.PomodoroEngine
import com.nikolaev.pomodoro.core.RunState
import com.nikolaev.pomodoro.core.Settings
import com.nikolaev.pomodoro.core.SyncRules
import com.nikolaev.pomodoro.core.TimeFormat
import com.nikolaev.pomodoro.system.AlarmScheduler
import com.nikolaev.pomodoro.system.Notifier
import com.nikolaev.pomodoro.system.SoundPlayer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.LocalDate

/**
 * The one owner of the timer, for the screen, the notification buttons and
 * the end-of-interval alarm alike. Lives in the Application, so whichever of
 * them wakes the process first rebuilds it from the saved state.
 * Every call comes on the main thread.
 */
class TimerRepository(context: Context) {
    private val prefs = context.getSharedPreferences("pomodoro", Context.MODE_PRIVATE)
    private val alarms = AlarmScheduler(context)
    private val notifier = Notifier(context)
    val sound = SoundPlayer(context)
    val dial = DurationDial()

    private val _settings = MutableStateFlow(
        Settings.fromJson(prefs.getString(KEY_SETTINGS, null))
            .let { it.copy(intervals = dial.clampIntervals(it.intervals)) },
    )
    val settings: StateFlow<Settings> = _settings.asStateFlow()

    private val engine = PomodoroEngine(
        settings = _settings.value.intervals,
        autoStartNextInterval = _settings.value.general.autoStartNextInterval,
        state = EngineState.fromJson(prefs.getString(KEY_STATE, null))
            ?: EngineState.initial(_settings.value.intervals, today()),
    )

    private val _state = MutableStateFlow(engine.state)
    val state: StateFlow<EngineState> = _state.asStateFlow()

    private val _notificationsAllowed = MutableStateFlow(notifier.canPost())
    val notificationsAllowed: StateFlow<Boolean> = _notificationsAllowed.asStateFlow()

    /** What was last saved and shown in the notification; see [publish]. */
    private var published: EngineState? = null

    /** A new state for the Mac: after a button or an interval running out, not after taking the Mac's. */
    var onStateChange: ((EngineState) -> Unit)? = null
    private var sentChangedAt: Double? = null

    /** The user changed the intervals: they go to the Mac (docs/SYNC.md, Interval settings). */
    var onIntervalsChange: ((IntervalSettings, Double) -> Unit)? = null
    private var sentIntervalsAt: Double? = null

    init {
        engine.rollOverDay(today())
        // Catches up with a timer that ran out while the process was dead, and
        // puts back the alarm a force-stop or an app update removed.
        handle(engine.update(now()))
        publish(force = true)
    }

    fun toggle() {
        engine.rollOverDay(today())
        engine.toggle(now())
        publish()
    }

    fun stop() {
        engine.stop(now())
        publish()
    }

    fun skip() {
        engine.rollOverDay(today())
        handle(engine.skip(now()))
        publish()
    }

    fun setDurationFraction(fraction: Double) = setDurationSeconds(dial.seconds(fraction))

    /** True when the typed value was over the limit and the timer took the limit. */
    fun setDurationText(text: String): Boolean {
        val seconds = TimeFormat.seconds(text) ?: return false
        setDurationSeconds(seconds)
        return seconds > dial.maxSeconds
    }

    fun tick() {
        handle(engine.update(now()))
        publish()
    }

    /** The alarm can fire a few milliseconds early; re-arming then fires it again at once. */
    fun onAlarm() {
        tick()
        alarms.sync(engine.state)
    }

    /** The Mac's state, already on this phone's clock (docs/SYNC.md, Merging). */
    fun receive(remote: EngineState) {
        if (!SyncRules.shouldAdopt(engine.state.changedAt, remote.changedAt, receiverIsMac = false)) return
        engine.adopt(remote)
        sentChangedAt = remote.changedAt
        publish()
    }

    fun updateSettings(new: Settings) {
        val old = _settings.value
        var clamped = new.copy(intervals = dial.clampIntervals(new.intervals))
        if (clamped.intervals != old.intervals) clamped = clamped.copy(intervalsChangedAt = now())
        applySettings(clamped)
    }

    /** The Mac's interval settings, their change time already on this phone's clock. */
    fun receiveIntervals(intervals: IntervalSettings, changedAt: Double) {
        val old = _settings.value
        if (!SyncRules.shouldAdoptIntervals(old.intervalsChangedAt, changedAt, receiverIsMac = false)) return
        sentIntervalsAt = changedAt
        applySettings(old.copy(intervals = dial.clampIntervals(intervals), intervalsChangedAt = changedAt))
    }

    private fun applySettings(clamped: Settings) {
        val old = _settings.value
        if (clamped == old) return
        _settings.value = clamped
        prefs.edit { putString(KEY_SETTINGS, clamped.toJson().toString()) }
        engine.autoStartNextInterval = clamped.general.autoStartNextInterval
        engine.applySettings(clamped.intervals, now())
        // Only "show timer in notifications" changes the notification without changing the state.
        publish(force = clamped.general != old.general)
        if (clamped.intervalsChangedAt != sentIntervalsAt) {
            sentIntervalsAt = clamped.intervalsChangedAt
            onIntervalsChange?.invoke(clamped.intervals, clamped.intervalsChangedAt)
        }
    }

    /** After the permission dialog or a return from Android's settings. */
    fun refreshPermissions() {
        val allowed = notifier.canPost()
        if (allowed == _notificationsAllowed.value) return
        _notificationsAllowed.value = allowed
        publish(force = true)
    }

    /**
     * True once: the first time the timer starts while notifications are
     * wanted but not allowed. Android itself blocks asking again and again.
     */
    fun takeNotificationPrompt(): Boolean {
        val s = _settings.value
        val wanted = s.sound.notificationsEnabled || s.general.showTimerInNotification
        if (!wanted || notifier.canPost() || prefs.getBoolean(KEY_ASKED_NOTIFICATIONS, false)) return false
        prefs.edit { putBoolean(KEY_ASKED_NOTIFICATIONS, true) }
        return true
    }

    private fun setDurationSeconds(seconds: Double) {
        engine.setPhaseDuration(dial.clampSeconds(seconds), now())
        publish()
    }

    private fun handle(events: List<EngineEvent>) {
        val s = _settings.value.sound
        for (event in events) {
            if (event !is EngineEvent.PhaseFinished) continue
            if (s.soundEnabled) sound.play(s.soundAfterFinishing(event.phase), s.volume)
            if (s.notificationsEnabled) notifier.postFinished(event.phase, engine.phase)
        }
    }

    /**
     * The screen gets every tick. Saving, the alarm and the notification only
     * change when something other than the countdown itself did: while
     * running, `remaining` follows from `endsAt`.
     */
    private fun publish(force: Boolean = false) {
        val state = engine.state
        _state.value = state
        if (state.changedAt != sentChangedAt) {
            sentChangedAt = state.changedAt
            onStateChange?.invoke(state)
        }
        val structural = if (state.runState == RunState.RUNNING) state.copy(remaining = 0.0) else state
        if (!force && structural == published) return
        published = structural
        prefs.edit { putString(KEY_STATE, state.toJson().toString()) }
        alarms.sync(state)
        notifier.showTimer(state, _settings.value)
    }

    private fun now(): Double = System.currentTimeMillis() / 1000.0

    private fun today(): Long = LocalDate.now().toEpochDay()

    private companion object {
        const val KEY_STATE = "engineState"
        const val KEY_SETTINGS = "settings"
        const val KEY_ASKED_NOTIFICATIONS = "askedNotifications"
    }
}
