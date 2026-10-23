package com.nikolaev.pomodoro.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TimeFormatTest {
    @Test
    fun secondsRenderAsMmSsAndAsHMmSsPastAnHour() {
        assertEquals("00:00", TimeFormat.string(0.0))
        assertEquals("00:59", TimeFormat.string(59.0))
        assertEquals("25:00", TimeFormat.string(25 * 60.0))
        assertEquals("1:00:00", TimeFormat.string(3600.0))
        assertEquals("1:01:01", TimeFormat.string(3661.0))
    }

    @Test
    fun aPartialSecondRoundsUpSoTheTimerNeverShowsZeroEarly() {
        assertEquals("00:01", TimeFormat.string(0.4))
    }

    @Test
    fun typedInputIsParsedInMinutesMmSsOrHMmSs() {
        assertEquals(1500.0, TimeFormat.seconds("25"))
        assertEquals(1530.0, TimeFormat.seconds("25:30"))
        assertEquals(3900.0, TimeFormat.seconds("1:05:00"))
        assertEquals(2400.0, TimeFormat.seconds(" 40 "))
    }

    @Test
    fun theNumberKeyboardsSeparatorsWorkLikeAColon() {
        assertEquals(1530.0, TimeFormat.seconds("25.30"))
        assertEquals(1530.0, TimeFormat.seconds("25,30"))
    }

    @Test
    fun nonsenseInputIsRejectedRatherThanGuessedAt() {
        assertNull(TimeFormat.seconds(""))
        assertNull(TimeFormat.seconds("abc"))
        assertNull(TimeFormat.seconds("-5"))
        assertNull(TimeFormat.seconds("1:2:3:4"))
    }
}

class DialTest {
    private val dial = DurationDial(fullTurnMinutes = 60.0, minSeconds = 10.0, maxSeconds = 10_800.0, dragStepSeconds = 5.0)

    @Test
    fun aQuarterTurnIsAQuarterOfTheFullTurn() {
        assertEquals(15 * 60.0, dial.seconds(0.25), 0.0)
        assertEquals(30 * 60.0, dial.seconds(0.5), 0.0)
        assertEquals(60 * 60.0, dial.seconds(1.0), 0.0)
    }

    @Test
    fun draggingSnapsToTheDragStepNotToWholeMinutes() {
        assertEquals(15 * 60.0 + 10, dial.seconds(0.2529), 0.0)
        assertEquals(20.0, dial.seconds(0.005), 0.0)
    }

    @Test
    fun theFractionRoundTripsBackFromADuration() {
        assertEquals(0.25, dial.fraction(15 * 60.0), 0.0001)
        assertEquals(0.0, dial.fraction(0.0), 0.0)
    }

    @Test
    fun durationsPastOneTurnPinToAFullRing() {
        assertEquals(1.0, dial.fraction(90 * 60.0), 0.0)
    }

    @Test
    fun clampingKeepsAValueInRangeWithoutRoundingIt() {
        assertEquals(10.0, dial.clampSeconds(10.0), 0.0)
        assertEquals(37.0, dial.clampSeconds(37.0), 0.0)
        assertEquals(95.0, dial.clampSeconds(95.0), 0.0)
    }

    @Test
    fun valuesOutsideTheRangeArePulledToTheNearestEnd() {
        assertEquals(10.0, dial.clampSeconds(0.0), 0.0)
        assertEquals(10_800.0, dial.clampSeconds(99_999.0), 0.0)
        assertEquals(10.0, dial.seconds(0.0), 0.0)
    }

    @Test
    fun theMinuteRangeFollowsTheSecondsRange() {
        assertEquals(180.0, dial.maxMinutes, 0.0)
        assertEquals(10.0 / 60.0, dial.minMinutes, 0.0001)
    }

    @Test
    fun theDefaultLimitIs5959And60MinutesInSettingsReachIt() {
        val dial = DurationDial()
        assertEquals(3_599.0, dial.clampSeconds(60 * 60.0), 0.0)
        assertEquals("59:59", TimeFormat.string(dial.clampSeconds(99_999.0)))
        assertEquals("59:59", TimeFormat.string(dial.clampMinutes(60.0) * 60))
        assertEquals("59:59", TimeFormat.string(dial.clampMinutes(90.0) * 60))
        assertEquals(59.0, dial.clampMinutes(59.0), 0.0)
        assertEquals(59.0, dial.clampMinutes(dial.maxMinutes - 1), 0.0)
    }

    @Test
    fun storedIntervalsOverTheLimitArePulledBackUnderIt() {
        val dial = DurationDial()
        val clamped = dial.clampIntervals(IntervalSettings(90.0, 5.0, 75.0, 3))
        assertEquals("59:59", TimeFormat.string(clamped.duration(Phase.WORK)))
        assertEquals(5.0, clamped.shortBreakMinutes, 0.0)
        assertEquals("59:59", TimeFormat.string(clamped.duration(Phase.LONG_BREAK)))
        assertEquals(3, clamped.longBreakAfter)
    }
}

class DialDragTest {
    @Test
    fun theHandleFollowsTheFingerAroundTheRing() {
        val d = DialDrag(0.25)
        assertEquals(0.3, d.move(0.3), 0.0)
        assertEquals(0.2, d.move(0.2), 0.0)
    }

    @Test
    fun goingBackPastTwelveStopsAtZero() {
        val d = DialDrag(0.02)
        assertEquals(0.001, d.move(0.001), 0.0)
        assertEquals(0.0, d.move(0.98), 0.0)
        assertEquals(0.0, d.move(0.7), 0.0)
        assertEquals(0.0, d.move(0.45), 0.0)
        assertEquals(0.0, d.move(0.2), 0.0)
    }

    @Test
    fun goingForwardPastTwelveStopsAtAFullTurn() {
        val d = DialDrag(0.97)
        assertEquals(1.0, d.move(0.02), 0.0)
        assertEquals(1.0, d.move(0.3), 0.0)
    }

    @Test
    fun aStoppedHandleIsPickedUpAgainWhenTheFingerComesBack() {
        val d = DialDrag(0.02)
        d.move(0.95)
        assertEquals(0.0, d.move(0.97), 0.0)
        assertEquals(0.03, d.move(0.03), 0.0)
        assertEquals(0.1, d.move(0.1), 0.0)

        val full = DialDrag(0.98)
        full.move(0.1)
        assertEquals(0.97, full.move(0.97), 0.0)
    }

    @Test
    fun distanceIsMeasuredAroundTheCircle() {
        assertEquals(0.04, DialDrag.distance(0.98, 0.02), 1e-9)
        assertEquals(0.3, DialDrag.distance(0.2, 0.5), 1e-9)
        assertEquals(0.0, DialDrag.distance(1.0, 0.0), 1e-9)
    }
}

class SettingsTest {
    @Test
    fun storedSettingsSurviveAFieldBeingAddedLater() {
        val s = Settings.fromJson("""{"intervals":{"workMinutes":45}}""")
        assertEquals(45.0, s.intervals.workMinutes, 0.0)
        assertEquals(4, s.intervals.longBreakAfter)
        assertEquals(true, s.general.showTimerInNotification)
    }

    @Test
    fun aWrongTypeFallsBackForThatKeyOnly() {
        val s = Settings.fromJson("""{"intervals":{"workMinutes":"long","shortBreakMinutes":7}}""")
        assertEquals(25.0, s.intervals.workMinutes, 0.0)
        assertEquals(7.0, s.intervals.shortBreakMinutes, 0.0)
    }

    @Test
    fun anUnreadableValueGivesTheDefaults() {
        assertEquals(Settings(), Settings.fromJson("not json"))
        assertEquals(Settings(), Settings.fromJson(null))
    }

    @Test
    fun settingsRoundTrip() {
        val s = Settings(
            GeneralSettings(autoStartNextInterval = true, showTimerInNotification = false),
            IntervalSettings(50.0, 10.0, 20.0, 3),
            SoundSettings("content://a", SoundSettings.SOUND_NONE, false, false, 0.3),
        )
        assertEquals(s, Settings.fromJson(s.toJson().toString()))
    }
}
