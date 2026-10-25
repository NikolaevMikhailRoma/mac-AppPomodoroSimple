package com.nikolaev.pomodoro.ui

import android.content.Context
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import com.nikolaev.pomodoro.core.Phase
import org.json.JSONObject

/**
 * The look of the app: config.json, the file the Mac and the iPhone read too
 * (src/config/Resources, packed as an asset). Sections and keys are the
 * file's own, and what each means is written in the Swift files beside it. Lengths
 * are the Mac's points: the timer screen scales them to the phone ([Units]),
 * the settings screen by `phone.settingsScale`.
 */
object Design {
    private lateinit var root: JSONObject

    /** Before anything is drawn or posted: PomodoroApp.onCreate. */
    fun load(context: Context) {
        root = context.assets.open("config.json").use { JSONObject(it.reader().readText()) }
    }

    val popover by lazy { Section("popover") }
    val ring by lazy { Section("ring") }
    val fonts by lazy { Section("fonts") }
    val icons by lazy { Section("icons") }
    val settings by lazy { Section("settingsWindow") }
    val phone by lazy { Section("phone") }

    /** Text and ring colour: red-ish while working, green on a break. */
    fun accent(phase: Phase): Color = ring.color(if (phase == Phase.WORK) "workColor" else "breakColor")

    class Section(name: String) {
        private val o = root.getJSONObject(name)

        operator fun get(key: String): Double = o.getDouble(key)

        fun color(key: String): Color = parseColor(o.getString(key))

        /** A font as config.json names it, "HelveticaNeue-Thin": a size and the weight in the name. */
        fun font(key: String): Font = o.getJSONObject(key).let { Font(it.getDouble("size"), weight(it.getString("name"))) }

        /** An icon's size; the icons themselves are drawn in Icons.kt. */
        fun iconSize(key: String): Double = o.getJSONObject(key).getDouble("size")
    }

    data class Font(val size: Double, val weight: FontWeight)

    /** "#RRGGBB", "#RRGGBBAA", or a name from the palette. */
    private fun parseColor(value: String): Color {
        val hex = root.getJSONObject("palette").optString(value, value).removePrefix("#")
        val v = hex.toLong(16)
        val rgb = if (hex.length == 8) v shr 8 else v
        val alpha = if (hex.length == 8) (v and 0xFF).toInt() else 0xFF
        return Color((rgb shr 16 and 0xFF).toInt(), (rgb shr 8 and 0xFF).toInt(), (rgb and 0xFF).toInt(), alpha)
    }

    private fun weight(fontName: String): FontWeight = when (fontName.substringAfterLast('-').lowercase()) {
        "thin" -> FontWeight.Thin
        "ultralight" -> FontWeight.ExtraLight
        "light" -> FontWeight.Light
        "medium" -> FontWeight.Medium
        else -> FontWeight.Normal
    }
}
