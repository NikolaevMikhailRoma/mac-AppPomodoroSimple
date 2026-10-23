package com.nikolaev.pomodoro.system

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.provider.Settings
import androidx.core.net.toUri
import com.nikolaev.pomodoro.core.SoundSettings

class SoundPlayer(private val context: Context) {
    data class Sound(val title: String, val key: String)

    /**
     * The phone's own notification sounds; the Mac's are Apple's and do not
     * ship here. The list differs from phone to phone.
     */
    fun available(): List<Sound> {
        val sounds = mutableListOf(Sound("None", SoundSettings.SOUND_NONE), Sound("Default", SoundSettings.SOUND_DEFAULT))
        val manager = RingtoneManager(context).apply { setType(RingtoneManager.TYPE_NOTIFICATION) }
        runCatching {
            manager.cursor.use { cursor ->
                while (cursor.moveToNext()) {
                    val title = cursor.getString(RingtoneManager.TITLE_COLUMN_INDEX)
                    sounds += Sound(title, manager.getRingtoneUri(cursor.position).toString())
                }
            }
        }
        return sounds
    }

    /**
     * Plays on the notification stream, so the phone's silent mode silences it.
     * `volume` is relative to that stream's volume.
     */
    fun play(key: String, volume: Double) {
        if (key == SoundSettings.SOUND_NONE) return
        val uri = if (key == SoundSettings.SOUND_DEFAULT) Settings.System.DEFAULT_NOTIFICATION_URI else key.toUri()
        val player = MediaPlayer()
        runCatching {
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            player.setDataSource(context, uri)
            player.setVolume(volume.toFloat(), volume.toFloat())
            player.setOnPreparedListener { it.start() }
            player.setOnCompletionListener { it.release() }
            player.setOnErrorListener { mp, _, _ -> mp.release(); true }
            player.prepareAsync()
        }.onFailure { player.release() }
    }
}
