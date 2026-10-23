package com.nikolaev.pomodoro.core

import org.json.JSONObject

// Lenient readers: a missing key or a value of the wrong type falls back for
// that one key and takes nothing else down with it, as on macOS.

internal fun JSONObject?.num(key: String, fallback: Double): Double =
    (this?.opt(key) as? Number)?.toDouble()?.takeIf { it.isFinite() } ?: fallback

internal fun JSONObject?.int(key: String, fallback: Int): Int =
    (this?.opt(key) as? Number)?.toInt() ?: fallback

internal fun JSONObject?.long(key: String, fallback: Long): Long =
    (this?.opt(key) as? Number)?.toLong() ?: fallback

internal fun JSONObject?.bool(key: String, fallback: Boolean): Boolean =
    this?.opt(key) as? Boolean ?: fallback

internal fun JSONObject?.str(key: String, fallback: String): String =
    this?.opt(key) as? String ?: fallback

internal fun JSONObject?.obj(key: String): JSONObject? = this?.opt(key) as? JSONObject

internal fun parseObject(text: String): JSONObject? =
    try {
        JSONObject(text)
    } catch (_: Exception) {
        null
    }
