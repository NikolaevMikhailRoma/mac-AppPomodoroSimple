package com.nikolaev.pomodoro.system

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import com.nikolaev.pomodoro.sync
import com.nikolaev.pomodoro.timer

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Keeps the process alive for the check with the Mac and the sound.
        val pending = goAsync()
        // The Mac may have paused or moved the timer while this app was closed:
        // take its state first, and ring only if the interval still ends now.
        context.sync.quickSync {
            context.timer.onAlarm()
            Handler(Looper.getMainLooper()).postDelayed({ pending.finish() }, SOUND_GRACE_MS)
        }
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
        // A timer that ran out while the process was dead finishes first.
        context.timer.tick()
        context.timer.toggle()
        // With the app closed there is no connection: tell the Mac now.
        val pending = goAsync()
        context.sync.quickSync { pending.finish() }
    }
}
