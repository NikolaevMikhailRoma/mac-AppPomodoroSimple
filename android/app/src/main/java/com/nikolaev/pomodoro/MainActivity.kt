package com.nikolaev.pomodoro

import android.Manifest
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.getValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.nikolaev.pomodoro.ui.SettingsScreen
import com.nikolaev.pomodoro.ui.TimerScreen

class MainActivity : ComponentActivity() {
    private val askNotifications =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { timer.refreshPermissions() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
        )
        setContent {
            var settingsOpen by rememberSaveable { mutableStateOf(false) }
            if (settingsOpen) {
                BackHandler { settingsOpen = false }
                SettingsScreen(timer, onBack = { settingsOpen = false }, onFixNotifications = ::openNotificationSettings)
            } else {
                TimerScreen(timer, onStart = ::askForNotificationsOnce, onOpenSettings = { settingsOpen = true })
            }
        }
    }

    override fun onResume() {
        super.onResume()
        timer.refreshPermissions()
        timer.tick()
    }

    /** Asked when the timer first starts, not at launch: that is when a notification is first due. */
    private fun askForNotificationsOnce() {
        // Before Android 13 notifications need no permission.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (timer.takeNotificationPrompt()) askNotifications.launch(Manifest.permission.POST_NOTIFICATIONS)
    }

    private fun openNotificationSettings() {
        startActivity(
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName),
        )
    }
}
