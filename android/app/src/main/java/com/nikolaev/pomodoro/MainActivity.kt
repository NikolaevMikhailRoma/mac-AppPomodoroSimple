package com.nikolaev.pomodoro

import android.Manifest
import android.content.Intent
import android.content.pm.ApplicationInfo
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
import com.nikolaev.pomodoro.core.PairLink
import com.nikolaev.pomodoro.ui.PairScreen
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
            // "timer", "settings" or "pair".
            var screen by rememberSaveable { mutableStateOf("timer") }
            // Coming back from the scanner lands on the Devices tab, not the first one.
            var settingsTab by rememberSaveable { mutableStateOf<String?>(null) }
            when (screen) {
                "pair" -> {
                    BackHandler { screen = "settings" }
                    PairScreen(
                        onLink = { sync.pair(it); screen = "settings" },
                        onBack = { screen = "settings" },
                    )
                }
                "settings" -> {
                    val close = { screen = "timer"; settingsTab = null }
                    BackHandler(onBack = close)
                    SettingsScreen(
                        timer,
                        sync,
                        onBack = close,
                        onFixNotifications = ::openNotificationSettings,
                        onPair = { screen = "pair"; settingsTab = "DEVICES" },
                        initialTab = settingsTab,
                    )
                }
                else -> TimerScreen(timer, onStart = ::askForNotificationsOnce, onOpenSettings = { screen = "settings" })
            }
        }
        handlePairingLink(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handlePairingLink(intent)
    }

    /**
     * Debug builds only (src/debug/AndroidManifest.xml): the emulator has no
     * camera to read the QR, so the link comes from adb. The check matters:
     * this activity is exported, and an explicit intent reaches it without a filter.
     */
    private fun handlePairingLink(intent: Intent) {
        if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE == 0) return
        if (intent.action != Intent.ACTION_VIEW) return
        PairLink.parse(intent.dataString ?: return)?.let(sync::pair)
    }

    override fun onStart() {
        super.onStart()
        sync.setActive(true)
    }

    override fun onStop() {
        super.onStop()
        sync.setActive(false)
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
