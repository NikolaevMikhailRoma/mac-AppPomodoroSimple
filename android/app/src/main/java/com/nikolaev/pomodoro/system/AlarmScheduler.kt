package com.nikolaev.pomodoro.system

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.nikolaev.pomodoro.core.EngineState
import com.nikolaev.pomodoro.core.RunState

/**
 * Wakes the app at the end of an interval even when it is closed and the
 * phone is dozing. Exact alarms need no dialog; the manifest says why.
 */
class AlarmScheduler(private val context: Context) {
    private val manager = context.getSystemService(AlarmManager::class.java)

    fun sync(state: EngineState) {
        val endsAt = state.endsAt
        if (state.runState != RunState.RUNNING || endsAt == null) {
            manager.cancel(pendingIntent())
            return
        }
        val at = (endsAt * 1000).toLong()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || manager.canScheduleExactAlarms()) {
            manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pendingIntent())
        } else {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pendingIntent())
        }
    }

    private fun pendingIntent(): PendingIntent = PendingIntent.getBroadcast(
        context,
        0,
        Intent(context, AlarmReceiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}
