package com.nikolaev.pomodoro.core

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.round

class DurationDial(
    val fullTurnMinutes: Double = 60.0,
    val minSeconds: Double = 1.0,
    val maxSeconds: Double = 3_599.0,
    val dragStepSeconds: Double = 5.0,
) {
    fun fraction(seconds: Double): Double {
        val turn = fullTurnMinutes * 60
        if (seconds >= turn) return 1.0
        return (seconds / turn).coerceIn(0.0, 1.0)
    }

    fun seconds(fraction: Double): Double {
        val raw = fraction.coerceIn(0.0, 1.0) * fullTurnMinutes * 60
        val snapped = round(raw / dragStepSeconds) * dragStepSeconds
        return clampSeconds(snapped)
    }

    fun clampSeconds(seconds: Double): Double = min(max(seconds, minSeconds), maxSeconds)

    val minMinutes: Double get() = minSeconds / 60
    val maxMinutes: Double get() = maxSeconds / 60

    /**
     * Settings fields hold whole minutes, but the upper bound stays exact: 60
     * in settings gives 59:59 on the timer instead of being cut to 59:00.
     */
    fun clampMinutes(minutes: Double): Double {
        val whole = round(minutes)
        return if (whole * 60 >= maxSeconds) maxMinutes else max(whole, minMinutes)
    }

    /** Stored durations brought back inside the dial's range. */
    fun clampIntervals(intervals: IntervalSettings) = intervals.copy(
        workMinutes = clampSeconds(intervals.workMinutes * 60) / 60,
        shortBreakMinutes = clampSeconds(intervals.shortBreakMinutes * 60) / 60,
        longBreakMinutes = clampSeconds(intervals.longBreakMinutes * 60) / 60,
    )
}

/**
 * Dragging the ring handle with a stop at twelve o'clock, the way a real dial
 * behaves: having reached zero or a full turn the handle stays there instead of
 * jumping to the other end, wherever the finger goes.
 */
class DialDrag(startingAt: Double) {
    var fraction: Double = startingAt.coerceIn(0.0, 1.0)
        private set

    /** 0 or 1 while the handle rests against a stop. */
    private var stop: Double? = null

    /** Where the handle goes for a finger at `raw`, a turn fraction clockwise from twelve. */
    fun move(raw: Double): Double {
        stop?.let {
            if (distance(raw, it) >= GRAB_DISTANCE) return fraction
            stop = null
        }
        if (abs(raw - fraction) > WRAP_THRESHOLD) {
            val end = if (fraction < 0.5) 0.0 else 1.0
            stop = end
            fraction = end
        } else {
            fraction = raw
        }
        return fraction
    }

    companion object {
        /**
         * A jump of more than half a turn in one move means the finger crossed
         * twelve o'clock, not that the user swept half the dial in one frame.
         */
        private const val WRAP_THRESHOLD = 0.5

        /** How close a touch has to land to pick the handle up rather than move it there. */
        const val GRAB_DISTANCE = 0.05

        /** Distance around the circle: 0.98 and 0.02 are 0.04 apart, not 0.96. */
        fun distance(a: Double, b: Double): Double {
            val d = abs(a - b) % 1.0
            return min(d, 1 - d)
        }
    }
}
