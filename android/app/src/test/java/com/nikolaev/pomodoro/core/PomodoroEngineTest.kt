package com.nikolaev.pomodoro.core

import com.nikolaev.pomodoro.core.EngineEvent.PhaseFinished
import com.nikolaev.pomodoro.core.EngineEvent.PhaseStarted
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

// The engine's behaviour is in docs/engine-vectors.json (EngineVectorTest);
// only what Android alone has is tested here.

private const val T0 = 1_000_000.0

/** Android-only: the process can die at any moment, so the state must survive a round trip. */
class PersistenceTest {
    @Test
    fun aRunningTimerSurvivesTheProcessDying() {
        val e = PomodoroEngine()
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
        val e = PomodoroEngine()
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
