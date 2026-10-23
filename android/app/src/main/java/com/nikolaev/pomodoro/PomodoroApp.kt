package com.nikolaev.pomodoro

import android.app.Application
import android.content.Context
import com.nikolaev.pomodoro.sync.SyncClient
import com.nikolaev.pomodoro.system.Notifier

class PomodoroApp : Application() {
    lateinit var timer: TimerRepository
        private set
    lateinit var sync: SyncClient
        private set

    override fun onCreate() {
        super.onCreate()
        Notifier.createChannels(this)
        timer = TimerRepository(this)
        sync = SyncClient(this, timer)
    }
}

val Context.timer: TimerRepository
    get() = (applicationContext as PomodoroApp).timer

val Context.sync: SyncClient
    get() = (applicationContext as PomodoroApp).sync
