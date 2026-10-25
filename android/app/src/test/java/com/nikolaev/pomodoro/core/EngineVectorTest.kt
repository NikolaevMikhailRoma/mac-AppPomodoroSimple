package com.nikolaev.pomodoro.core

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** docs/engine-vectors.json: the same scenarios the Swift tests run. Gradle runs tests from android/app. */
private val scenarios = JSONObject(File("../../docs/engine-vectors.json").readText()).getJSONArray("scenarios")

/** Where every scenario's clock starts. */
private const val T0 = 1_000_000.0

private fun EngineEvent.name() = when (this) {
    is EngineEvent.PhaseFinished -> "finished ${phase.key}"
    is EngineEvent.PhaseStarted -> "started ${phase.key}"
}

class EngineVectorTest {
    @Test
    fun everyScenario() {
        assertTrue(scenarios.length() > 0)
        for (i in 0 until scenarios.length()) {
            val scenario = scenarios.getJSONObject(i)
            val title = scenario.getString("name")
            val settings = IntervalSettings.from(scenario.getJSONObject("settings"))
            val engine = PomodoroEngine(settings, scenario.getBoolean("autoStart"))
            val steps = scenario.getJSONArray("steps")
            for (j in 0 until steps.length()) {
                val step = steps.getJSONObject(j)
                val at = step.getDouble("at")
                val now = T0 + at
                val events = when (val action = step.getString("do")) {
                    "start" -> engine.start(now).let { emptyList() }
                    "pause" -> engine.pause(now).let { emptyList() }
                    "stop" -> engine.stop(now).let { emptyList() }
                    "skip" -> engine.skip(now)
                    "update" -> engine.update(now)
                    "setDuration" -> engine.setPhaseDuration(step.getDouble("seconds"), now).let { emptyList() }
                    "applySettings" -> engine.applySettings(IntervalSettings.from(step.getJSONObject("settings")), now).let { emptyList() }
                    else -> error("$title: unknown step $action")
                }
                step.optJSONArray("events")?.let { expected ->
                    assertEquals("$title, at $at", List(expected.length()) { expected.getString(it) }, events.map { it.name() })
                }
                val state = engine.state.toJson()
                val expected = step.getJSONObject("expect")
                for (key in expected.keys()) {
                    val message = "$title, at $at: $key"
                    when (val value = expected.get(key)) {
                        JSONObject.NULL -> assertTrue(message, state.isNull(key))
                        is String -> assertEquals(message, value, state.getString(key))
                        else -> {
                            val offset = if (key == "endsAt" || key == "changedAt") T0 else 0.0
                            assertEquals(message, (value as Number).toDouble() + offset, state.getDouble(key), 0.0)
                        }
                    }
                }
            }
        }
    }
}
