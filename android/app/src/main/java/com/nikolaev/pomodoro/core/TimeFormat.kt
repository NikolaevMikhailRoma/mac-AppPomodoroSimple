package com.nikolaev.pomodoro.core

import java.util.Locale
import kotlin.math.ceil

object TimeFormat {
    fun string(seconds: Double): String {
        val total = ceil(seconds).toInt().coerceAtLeast(0)
        val h = total / 3600
        val m = (total % 3600) / 60
        val s = total % 60
        // Locale.ROOT: some locales would otherwise print non-Latin digits.
        return if (h > 0) "%d:%02d:%02d".format(Locale.ROOT, h, m, s) else "%02d:%02d".format(Locale.ROOT, m, s)
    }

    /**
     * Minutes, mm:ss or h:mm:ss. Unlike the Mac, `.`, `,` and spaces also
     * separate the parts: the phone's number keyboard has no colon.
     */
    fun seconds(text: String): Double? {
        val parts = text.trim().split(':', '.', ',', ' ').filter { it.isNotEmpty() }
        if (parts.size !in 1..3) return null
        val numbers = parts.map { part ->
            if (!part.all { it in '0'..'9' }) return null
            part.toIntOrNull() ?: return null
        }
        return when (numbers.size) {
            1 -> numbers[0] * 60.0
            2 -> numbers[0] * 60.0 + numbers[1]
            else -> numbers[0] * 3600.0 + numbers[1] * 60 + numbers[2]
        }
    }
}
