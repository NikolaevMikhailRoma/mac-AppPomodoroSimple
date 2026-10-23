package com.nikolaev.pomodoro.core

import org.json.JSONObject

data class Settings(
    val general: GeneralSettings = GeneralSettings(),
    val intervals: IntervalSettings = IntervalSettings(),
    val sound: SoundSettings = SoundSettings(),
    /** When the user last changed [intervals]; 0 for defaults nobody touched. Shared by it with the Mac (docs/SYNC.md). */
    val intervalsChangedAt: Double = 0.0,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("general", general.toJson())
        .put("intervals", intervals.toJson())
        .put("sound", sound.toJson())
        .put("intervalsChangedAt", intervalsChangedAt)

    companion object {
        /** Settings stored by an older version keep working when fields are added. */
        fun fromJson(text: String?): Settings {
            val o = text?.let(::parseObject) ?: return Settings()
            return Settings(
                general = GeneralSettings.from(o.obj("general")),
                intervals = IntervalSettings.from(o.obj("intervals")),
                sound = SoundSettings.from(o.obj("sound")),
                intervalsChangedAt = o.num("intervalsChangedAt", 0.0),
            )
        }
    }
}

/** `showTimerInNotification` is the phone's counterpart of the Mac's menu bar timer. */
data class GeneralSettings(
    val autoStartNextInterval: Boolean = false,
    val showTimerInNotification: Boolean = true,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("autoStartNextInterval", autoStartNextInterval)
        .put("showTimerInNotification", showTimerInNotification)

    companion object {
        fun from(o: JSONObject?, d: GeneralSettings = GeneralSettings()) = GeneralSettings(
            autoStartNextInterval = o.bool("autoStartNextInterval", d.autoStartNextInterval),
            showTimerInNotification = o.bool("showTimerInNotification", d.showTimerInNotification),
        )
    }
}

data class IntervalSettings(
    val workMinutes: Double = 25.0,
    val shortBreakMinutes: Double = 5.0,
    val longBreakMinutes: Double = 15.0,
    val longBreakAfter: Int = 4,
) {
    fun duration(phase: Phase): Double = when (phase) {
        Phase.WORK -> workMinutes * 60
        Phase.SHORT_BREAK -> shortBreakMinutes * 60
        Phase.LONG_BREAK -> longBreakMinutes * 60
    }

    fun toJson(): JSONObject = JSONObject()
        .put("workMinutes", workMinutes)
        .put("shortBreakMinutes", shortBreakMinutes)
        .put("longBreakMinutes", longBreakMinutes)
        .put("longBreakAfter", longBreakAfter)

    companion object {
        fun from(o: JSONObject?, d: IntervalSettings = IntervalSettings()) = IntervalSettings(
            workMinutes = o.num("workMinutes", d.workMinutes),
            shortBreakMinutes = o.num("shortBreakMinutes", d.shortBreakMinutes),
            longBreakMinutes = o.num("longBreakMinutes", d.longBreakMinutes),
            longBreakAfter = o.int("longBreakAfter", d.longBreakAfter),
        )
    }
}

/**
 * Sounds are stored as Android sound URIs. [SOUND_DEFAULT] is the phone's
 * default notification sound, [SOUND_NONE] is silence.
 */
data class SoundSettings(
    val workCompletedSound: String = SOUND_DEFAULT,
    val breakEndedSound: String = SOUND_DEFAULT,
    val soundEnabled: Boolean = true,
    val notificationsEnabled: Boolean = true,
    val volume: Double = 0.7,
) {
    fun soundAfterFinishing(phase: Phase): String =
        if (phase == Phase.WORK) workCompletedSound else breakEndedSound

    fun toJson(): JSONObject = JSONObject()
        .put("workCompletedSound", workCompletedSound)
        .put("breakEndedSound", breakEndedSound)
        .put("soundEnabled", soundEnabled)
        .put("notificationsEnabled", notificationsEnabled)
        .put("volume", volume)

    companion object {
        const val SOUND_DEFAULT = ""
        const val SOUND_NONE = "none"

        fun from(o: JSONObject?, d: SoundSettings = SoundSettings()) = SoundSettings(
            workCompletedSound = o.str("workCompletedSound", d.workCompletedSound),
            breakEndedSound = o.str("breakEndedSound", d.breakEndedSound),
            soundEnabled = o.bool("soundEnabled", d.soundEnabled),
            notificationsEnabled = o.bool("notificationsEnabled", d.notificationsEnabled),
            volume = o.num("volume", d.volume).coerceIn(0.0, 1.0),
        )
    }
}
