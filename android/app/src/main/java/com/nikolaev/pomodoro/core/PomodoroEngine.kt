package com.nikolaev.pomodoro.core

import org.json.JSONObject

sealed interface EngineEvent {
    data class PhaseFinished(val phase: Phase) : EngineEvent
    data class PhaseStarted(val phase: Phase) : EngineEvent
}

/**
 * Everything the engine knows, as plain values. Android may kill the process
 * at any moment, so this is saved after every change and the engine is
 * rebuilt from it. `endsAt` is wall-clock time, which is what lets a timer
 * that ran out while the app was dead finish correctly on the next launch.
 * Times are seconds; `endsAt` is seconds since the epoch.
 */
data class EngineState(
    val phase: Phase,
    val runState: RunState,
    val phaseDuration: Double,
    val remaining: Double,
    val completedToday: Int,
    val endsAt: Double?,
    val sinceLongBreak: Int,
    /** Days since the epoch in local time, for resetting the daily count. */
    val countedDay: Long,
    /** When the state last changed: a button, or the moment an interval ran out (docs/SYNC.md). */
    val changedAt: Double = 0.0,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("phase", phase.key)
        .put("runState", runState.key)
        .put("phaseDuration", phaseDuration)
        .put("remaining", remaining)
        .put("completedToday", completedToday)
        .put("endsAt", endsAt ?: JSONObject.NULL)
        .put("sinceLongBreak", sinceLongBreak)
        .put("countedDay", countedDay)
        .put("changedAt", changedAt)

    companion object {
        fun initial(settings: IntervalSettings, day: Long) = EngineState(
            phase = Phase.WORK,
            runState = RunState.IDLE,
            phaseDuration = settings.duration(Phase.WORK),
            remaining = settings.duration(Phase.WORK),
            completedToday = 0,
            endsAt = null,
            sinceLongBreak = 0,
            countedDay = day,
        )

        /** Null when there is nothing usable stored; the caller starts fresh. */
        fun fromJson(text: String?): EngineState? = fromJsonObject(text?.let(::parseObject))

        fun fromJsonObject(o: JSONObject?): EngineState? {
            if (o == null) return null
            val phase = Phase.fromKey(o.optString("phase")) ?: return null
            val runState = RunState.fromKey(o.optString("runState")) ?: return null
            val duration = o.num("phaseDuration", -1.0).takeIf { it > 0 } ?: return null
            val endsAt = o.num("endsAt", Double.NaN).takeIf { !it.isNaN() }
            if (runState == RunState.RUNNING && endsAt == null) return null
            return EngineState(
                phase = phase,
                runState = runState,
                phaseDuration = duration,
                remaining = o.num("remaining", duration).coerceIn(0.0, duration),
                completedToday = o.int("completedToday", 0).coerceAtLeast(0),
                endsAt = if (runState == RunState.RUNNING) endsAt else null,
                sinceLongBreak = o.int("sinceLongBreak", 0).coerceAtLeast(0),
                countedDay = o.long("countedDay", 0),
                changedAt = o.num("changedAt", 0.0),
            )
        }
    }
}

/** The rules of PomodoroEngine.swift; its tests are ported too. */
class PomodoroEngine(
    settings: IntervalSettings = IntervalSettings(),
    var autoStartNextInterval: Boolean = false,
    state: EngineState = EngineState.initial(settings, day = 0),
) {
    private var settings: IntervalSettings = settings
    var state: EngineState = state
        private set

    val phase: Phase get() = state.phase
    val runState: RunState get() = state.runState
    val phaseDuration: Double get() = state.phaseDuration
    val remaining: Double get() = state.remaining
    val completedToday: Int get() = state.completedToday

    fun start(now: Double) {
        if (runState == RunState.RUNNING) return
        val left = if (remaining <= 0) phaseDuration else remaining
        state = state.copy(runState = RunState.RUNNING, remaining = left, endsAt = now + left, changedAt = now)
    }

    fun pause(now: Double) {
        if (runState != RunState.RUNNING) return
        val left = maxOf(0.0, (state.endsAt ?: now) - now)
        state = state.copy(runState = RunState.PAUSED, remaining = left, endsAt = null, changedAt = now)
    }

    fun toggle(now: Double) = if (runState == RunState.RUNNING) pause(now) else start(now)

    fun stop(now: Double) {
        val duration = settings.duration(phase)
        state = state.copy(
            runState = RunState.IDLE, phaseDuration = duration, remaining = duration, endsAt = null, changedAt = now,
        )
    }

    /**
     * Work counts even when finished early, or never started at all: this is
     * how the user adds an interval worked without the timer. Dropping work
     * without counting it is stop().
     */
    fun skip(now: Double): List<EngineEvent> = advance(now, changedAt = now)

    fun setPhaseDuration(seconds: Double, now: Double) {
        val duration = maxOf(1.0, seconds)
        val endsAt = if (runState == RunState.RUNNING) now + duration else null
        state = state.copy(phaseDuration = duration, remaining = duration, endsAt = endsAt, changedAt = now)
    }

    fun applySettings(new: IntervalSettings, now: Double) {
        settings = new
        val duration = new.duration(phase)
        if (runState != RunState.IDLE || duration == phaseDuration) return
        state = state.copy(phaseDuration = duration, remaining = duration, changedAt = now)
    }

    /** Resets the daily count the first time it is called on a new day. */
    fun rollOverDay(day: Long) {
        if (day == state.countedDay) return
        state = state.copy(countedDay = day, completedToday = 0, sinceLongBreak = 0)
    }

    /** The Mac's state, already on this phone's clock. Plays nothing: the Mac did that. */
    fun adopt(new: EngineState) {
        state = new
    }

    fun update(now: Double): List<EngineEvent> {
        val end = state.endsAt
        if (runState != RunState.RUNNING || end == null) return emptyList()
        state = state.copy(remaining = maxOf(0.0, end - now))
        // Changed at the moment it ran out, not when the alarm fired: the Mac
        // gets the same time. The next interval starts now, though.
        return if (remaining > 0) emptyList() else advance(now, changedAt = end)
    }

    private fun advance(now: Double, changedAt: Double): List<EngineEvent> {
        val finished = phase
        var completed = state.completedToday
        var sinceLongBreak = state.sinceLongBreak
        if (finished == Phase.WORK) {
            completed += 1
            sinceLongBreak += 1
        }

        val next = when {
            finished != Phase.WORK -> Phase.WORK
            settings.longBreakAfter > 0 && sinceLongBreak >= settings.longBreakAfter -> {
                sinceLongBreak = 0
                Phase.LONG_BREAK
            }
            else -> Phase.SHORT_BREAK
        }

        val duration = settings.duration(next)
        state = state.copy(
            phase = next,
            runState = if (autoStartNextInterval) RunState.RUNNING else RunState.IDLE,
            phaseDuration = duration,
            remaining = duration,
            completedToday = completed,
            endsAt = if (autoStartNextInterval) now + duration else null,
            sinceLongBreak = sinceLongBreak,
            changedAt = changedAt,
        )
        return listOf(EngineEvent.PhaseFinished(finished), EngineEvent.PhaseStarted(next))
    }
}
