package com.nikolaev.pomodoro.system

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import androidx.compose.ui.graphics.toArgb
import com.nikolaev.pomodoro.MainActivity
import com.nikolaev.pomodoro.R
import com.nikolaev.pomodoro.core.EngineState
import com.nikolaev.pomodoro.core.Phase
import com.nikolaev.pomodoro.core.RunState
import com.nikolaev.pomodoro.core.Settings
import com.nikolaev.pomodoro.core.TimeFormat
import com.nikolaev.pomodoro.ui.Design

/**
 * Two kinds of notification: the running timer (the phone's counterpart of
 * the Mac's menu bar timer) and the "interval finished" alert. Both are
 * silent; the app plays its own sound at its own volume, as on the Mac.
 */
class Notifier(private val context: Context) {
    private val manager = context.getSystemService(NotificationManager::class.java)

    /** False both when the permission was never granted and when it was switched off later. */
    fun canPost(): Boolean = manager.areNotificationsEnabled()

    /**
     * The status bar gets only an icon, one per state: Android paints all
     * status bar icons in a single colour, so the shape tells work, break and
     * pause apart. The shade shows a media-player-like row: phase, countdown
     * and one pause/resume button.
     */
    fun showTimer(state: EngineState, settings: Settings) {
        if (!settings.general.showTimerInNotification || state.runState == RunState.IDLE || !canPost()) {
            manager.cancel(ID_TIMER)
            return
        }
        val running = state.runState == RunState.RUNNING
        val icon = when {
            !running -> R.drawable.ic_stat_paused
            state.phase == Phase.WORK -> R.drawable.ic_stat_work
            else -> R.drawable.ic_stat_break
        }
        val toggle = Notification.Action.Builder(
            Icon.createWithResource(context, if (running) R.drawable.ic_pause else R.drawable.ic_play),
            if (running) "Pause" else "Resume",
            toggleIntent(),
        ).build()
        val builder = Notification.Builder(context, CHANNEL_TIMER)
            .setSmallIcon(icon)
            .setColor(Design.accent(state.phase).toArgb())
            .setContentTitle(state.phase.title)
            .setContentIntent(openApp())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .addAction(toggle)
            .setStyle(Notification.MediaStyle().setShowActionsInCompactView(0))
        val endsAt = state.endsAt
        if (running && endsAt != null) {
            builder.setUsesChronometer(true)
                .setChronometerCountDown(true)
                .setWhen((endsAt * 1000).toLong())
                .setShowWhen(true)
        } else {
            builder.setContentText("Paused · ${TimeFormat.string(state.remaining)}").setShowWhen(false)
        }
        manager.notify(ID_TIMER, builder.build())
    }

    fun postFinished(finished: Phase, next: Phase) {
        if (!canPost()) return
        val notification = Notification.Builder(context, CHANNEL_ALERTS)
            .setSmallIcon(if (next == Phase.WORK) R.drawable.ic_stat_work else R.drawable.ic_stat_break)
            .setContentTitle(if (finished == Phase.WORK) "Work interval finished" else "Break finished")
            .setContentText(if (next == Phase.WORK) "Time to work." else "Time for a ${next.title.lowercase()}.")
            .setContentIntent(openApp())
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .build()
        manager.notify(ID_FINISHED, notification)
    }

    private fun openApp(): PendingIntent = PendingIntent.getActivity(
        context,
        0,
        Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun toggleIntent(): PendingIntent = PendingIntent.getBroadcast(
        context,
        0,
        Intent(context, ToggleReceiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    companion object {
        private const val CHANNEL_TIMER = "timer"
        private const val CHANNEL_ALERTS = "alerts"
        private const val ID_TIMER = 1
        private const val ID_FINISHED = 2

        fun createChannels(context: Context) {
            // DEFAULT rather than LOW keeps the timer out of the shade's collapsed
            // "Silent" section; it still makes no sound.
            val timer = NotificationChannel(CHANNEL_TIMER, "Running timer", NotificationManager.IMPORTANCE_DEFAULT).apply {
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
            }
            val alerts = NotificationChannel(CHANNEL_ALERTS, "Interval finished", NotificationManager.IMPORTANCE_HIGH).apply {
                setSound(null, null)
                enableVibration(true)
            }
            context.getSystemService(NotificationManager::class.java)
                .createNotificationChannels(listOf(timer, alerts))
        }
    }
}
