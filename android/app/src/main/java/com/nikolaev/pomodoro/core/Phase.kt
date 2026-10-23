package com.nikolaev.pomodoro.core

/** `key` is what gets stored; it matches the raw values of the macOS app. */
enum class Phase(val key: String, val title: String) {
    WORK("work", "Work"),
    SHORT_BREAK("shortBreak", "Short break"),
    LONG_BREAK("longBreak", "Long break");

    companion object {
        fun fromKey(key: String?): Phase? = entries.firstOrNull { it.key == key }
    }
}

enum class RunState(val key: String) {
    IDLE("idle"),
    RUNNING("running"),
    PAUSED("paused");

    companion object {
        fun fromKey(key: String?): RunState? = entries.firstOrNull { it.key == key }
    }
}
