package com.nikolaev.pomodoro.system

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import com.nikolaev.pomodoro.timer

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Keeps the process alive long enough for the end-of-interval sound.
        val pending = goAsync()
        context.timer.onAlarm()
        Handler(Looper.getMainLooper()).postDelayed({ pending.finish() }, SOUND_GRACE_MS)
    }

    private companion object {
        const val SOUND_GRACE_MS = 5_000L
    }
}

/** Alarms do not survive a reboot or an app update; creating the timer puts them back. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action == Intent.ACTION_BOOT_COMPLETED || action == Intent.ACTION_MY_PACKAGE_REPLACED) context.timer.tick()
    }
}

/** The pause/resume button on the timer notification. */
class ToggleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        context.timer.toggle()
    }
}
