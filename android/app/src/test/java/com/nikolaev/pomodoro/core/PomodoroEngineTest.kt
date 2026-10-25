package com.nikolaev.pomodoro.core

import com.nikolaev.pomodoro.core.EngineEvent.PhaseFinished
import com.nikolaev.pomodoro.core.EngineEvent.PhaseStarted
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

// Ported from pomidoro_app/tests/PomodoroEngineTests.swift: the
// two apps must behave the same, so the same cases guard both.

private const val T0 = 1_000_000.0

private fun engine(
    work: Double = 25.0,
    short: Double = 5.0,
    long: Double = 15.0,
    longAfter: Int = 4,
    autoStart: Boolean = false,
) = PomodoroEngine(IntervalSettings(work, short, long, longAfter), autoStart)

class CountdownTest {
    @Test
    fun startsIdleAtTheFullWorkDuration() {
        val e = engine()
        assertEquals(Phase.WORK, e.phase)
        assertEquals(RunState.IDLE, e.runState)
        assertEquals(25 * 60.0, e.remaining, 0.0)
    }

    @Test
    fun countsDownWhileRunning() {
        val e = engine()
        e.start(T0)
        assertEquals(RunState.RUNNING, e.runState)
        e.update(T0 + 60)
        assertEquals(24 * 60.0, e.remaining, 0.0)
    }

    @Test
    fun pauseFreezesTheRemainingTime() {
        val e = engine()
        e.start(T0)
        e.pause(T0 + 60)
        assertEquals(24 * 60.0, e.remaining, 0.0)
        assertEquals(RunState.PAUSED, e.runState)
        e.update(T0 + 3600)
        assertEquals(24 * 60.0, e.remaining, 0.0)
    }

    @Test
    fun resumeContinuesFromWhereItStopped() {
        val e = engine()
        e.start(T0)
        e.pause(T0 + 60)
        e.start(T0 + 3600)
        e.update(T0 + 3660)
        assertEquals(23 * 60.0, e.remaining, 0.0)
    }

    @Test
    fun stopReturnsToTheStartOfThePhase() {
        val e = engine()
        e.start(T0)
        e.update(T0 + 600)
        e.stop(T0)
        assertEquals(RunState.IDLE, e.runState)
        assertEquals(25 * 60.0, e.remaining, 0.0)
    }

    @Test
    fun stopDiscardsAHandSetLength() {
        val e = engine()
        e.setPhaseDuration(15.0, T0)
        e.start(T0)
        assertEquals(15.0, e.remaining, 0.0)
        e.stop(T0)
        assertEquals(25 * 60.0, e.phaseDuration, 0.0)
        assertEquals(25 * 60.0, e.remaining, 0.0)
    }
}

class TransitionTest {
    @Test
    fun workRunsOutIntoAShortBreakAndCountsOne() {
        val e = engine()
        e.start(T0)
        val events = e.update(T0 + 25 * 60)
        assertEquals(listOf(PhaseFinished(Phase.WORK), PhaseStarted(Phase.SHORT_BREAK)), events)
        assertEquals(Phase.SHORT_BREAK, e.phase)
        assertEquals(5 * 60.0, e.remaining, 0.0)
        assertEquals(1, e.completedToday)
        assertEquals(RunState.IDLE, e.runState)
    }

    @Test
    fun everyFourthWorkIntervalLeadsToALongBreak() {
        val e = engine(autoStart = true)
        var now = T0
        for (cycle in 1..4) {
            e.start(now)
            now += e.remaining
            e.update(now)
            assertEquals(cycle, e.completedToday)
            assertEquals(if (cycle == 4) Phase.LONG_BREAK else Phase.SHORT_BREAK, e.phase)
            now += e.remaining
            e.update(now)
            assertEquals(Phase.WORK, e.phase)
        }
        assertEquals(4, e.completedToday)
    }

    @Test
    fun theLongBreakCounterRestartsAfterALongBreak() {
        val e = engine(longAfter = 2, autoStart = true)
        var now = T0
        val phases = mutableListOf<Phase>()
        e.start(now)
        repeat(8) {
            now += e.remaining
            e.update(now)
            phases += e.phase
        }
        val w = Phase.WORK
        val s = Phase.SHORT_BREAK
        val l = Phase.LONG_BREAK
        assertEquals(listOf(s, w, l, w, s, w, l, w), phases)
    }

    @Test
    fun autoStartKeepsTheNextPhaseRunning() {
        val e = engine(autoStart = true)
        e.start(T0)
        e.update(T0 + 25 * 60)
        assertEquals(RunState.RUNNING, e.runState)
        assertEquals(Phase.SHORT_BREAK, e.phase)
        e.update(T0 + 25 * 60 + 60)
        assertEquals(4 * 60.0, e.remaining, 0.0)
    }

    @Test
    fun finishingWorkEarlyCountsItEvenIfTheTimerNeverRan() {
        val e = engine()
        e.start(T0)
        val events = e.skip(T0 + 60)
        assertEquals(listOf(PhaseFinished(Phase.WORK), PhaseStarted(Phase.SHORT_BREAK)), events)
        assertEquals(1, e.completedToday)
        assertEquals(Phase.SHORT_BREAK, e.phase)

        val forgotten = engine()
        forgotten.skip(T0)
        assertEquals(1, forgotten.completedToday)
    }

    @Test
    fun skippingABreakCountsNothing() {
        val e = engine()
        e.skip(T0)
        e.skip(T0)
        assertEquals(Phase.WORK, e.phase)
        assertEquals(1, e.completedToday)
    }

    @Test
    fun workFinishedByHandLeadsToTheLongBreak() {
        val e = engine(longAfter = 2)
        e.skip(T0)
        e.skip(T0)
        e.skip(T0)
        assertEquals(Phase.LONG_BREAK, e.phase)
    }

    @Test
    fun aBreakEndsBackAtWork() {
        val e = engine()
        e.start(T0)
        e.update(T0 + 25 * 60)
        e.start(T0 + 25 * 60)
        e.update(T0 + 30 * 60)
        assertEquals(Phase.WORK, e.phase)
        assertEquals(25 * 60.0, e.remaining, 0.0)
    }
}

class EditingTest {
    @Test
    fun settingADurationWhileStoppedResetsTheCountdown() {
        val e = engine()
        e.setPhaseDuration(40 * 60.0, T0)
        assertEquals(40 * 60.0, e.remaining, 0.0)
        assertEquals(40 * 60.0, e.phaseDuration, 0.0)
        assertEquals(RunState.IDLE, e.runState)
    }

    @Test
    fun settingADurationWhileRunningRestartsFromTheNewValue() {
        val e = engine()
        e.start(T0)
        e.update(T0 + 600)
        e.setPhaseDuration(40 * 60.0, T0 + 600)
        assertEquals(RunState.RUNNING, e.runState)
        assertEquals(40 * 60.0, e.remaining, 0.0)
        e.update(T0 + 660)
        assertEquals(39 * 60.0, e.remaining, 0.0)
    }

    @Test
    fun newSettingsResizeAnIdlePhaseButNeverARunningOne() {
        val idle = engine()
        idle.applySettings(IntervalSettings(workMinutes = 50.0), T0)
        assertEquals(50 * 60.0, idle.remaining, 0.0)

        val running = engine()
        running.start(T0)
        running.update(T0 + 60)
        running.applySettings(IntervalSettings(workMinutes = 50.0), T0)
        assertEquals(24 * 60.0, running.remaining, 0.0)
    }
}

/** Android-only: the process can die at any moment, so the state must survive a round trip. */
class PersistenceTest {
    @Test
    fun aRunningTimerSurvivesTheProcessDying() {
        val e = engine()
        e.start(T0)
        e.update(T0 + 60)
        val saved = e.state.toJson().toString()

        val restored = PomodoroEngine(IntervalSettings(), false, EngineState.fromJson(saved)!!)
        restored.update(T0 + 120)
        assertEquals(23 * 60.0, restored.remaining, 0.0)
        assertEquals(RunState.RUNNING, restored.runState)
    }

    @Test
    fun aTimerThatRanOutWhileTheAppWasDeadFinishesOnTheNextLaunch() {
        val e = engine()
        e.start(T0)
        val restored = PomodoroEngine(IntervalSettings(), false, EngineState.fromJson(e.state.toJson().toString())!!)
        val events = restored.update(T0 + 3 * 3600)
        assertEquals(listOf(PhaseFinished(Phase.WORK), PhaseStarted(Phase.SHORT_BREAK)), events)
        assertEquals(1, restored.completedToday)
    }

    @Test
    fun brokenOrInconsistentStateIsRejected() {
        assertNull(EngineState.fromJson(null))
        assertNull(EngineState.fromJson("not json"))
        assertNull(EngineState.fromJson("""{"phase":"work","runState":"running","phaseDuration":60}"""))
        assertNull(EngineState.fromJson("""{"phase":"nap","runState":"idle","phaseDuration":60}"""))
    }

    @Test
    fun theDailyCountResetsOnANewDayOnly() {
        val e = PomodoroEngine(state = EngineState.initial(IntervalSettings(), day = 100))
        e.skip(T0)
        e.rollOverDay(100)
        assertEquals(1, e.completedToday)
        e.rollOverDay(101)
        assertEquals(0, e.completedToday)
    }
}
