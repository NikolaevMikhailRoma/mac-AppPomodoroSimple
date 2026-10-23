package com.nikolaev.pomodoro

import android.app.Application
import android.content.Context
import com.nikolaev.pomodoro.system.Notifier

class PomodoroApp : Application() {
    lateinit var timer: TimerRepository
        private set

    override fun onCreate() {
        super.onCreate()
        Notifier.createChannels(this)
        timer = TimerRepository(this)
    }
}

val Context.timer: TimerRepository
    get() = (applicationContext as PomodoroApp).timer
