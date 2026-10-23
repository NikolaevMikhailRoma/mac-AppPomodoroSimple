package com.nikolaev.pomodoro.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.nikolaev.pomodoro.TimerRepository
import com.nikolaev.pomodoro.core.Settings
import com.nikolaev.pomodoro.sync.SyncClient
import com.nikolaev.pomodoro.system.SoundPlayer
import com.nikolaev.pomodoro.ui.Design.Settings as S
import kotlin.math.ceil
import kotlin.math.roundToInt

private val labelStyle = TextStyle(color = S.label, fontSize = S.LABEL_SIZE.sp)
private val secondaryStyle = TextStyle(color = S.secondary, fontSize = S.SECONDARY_SIZE.sp)
private val fieldShape = RoundedCornerShape(4.dp)

private enum class Tab(val title: String) {
    GENERAL("General"),
    INTERVALS("Intervals"),
    SOUNDS("Sounds"),
    MAC("Mac"),
}

/** The Mac settings window as a phone screen: the same tabs in the same box, and a tab for the Mac itself. */
@Composable
fun SettingsScreen(
    timer: TimerRepository,
    sync: SyncClient,
    onBack: () -> Unit,
    onFixNotifications: () -> Unit,
    onPair: () -> Unit,
    initialTab: String? = null,
) {
    val settings by timer.settings.collectAsStateWithLifecycle()
    val notificationsAllowed by timer.notificationsAllowed.collectAsStateWithLifecycle()
    var tab by rememberSaveable { mutableStateOf(Tab.entries.firstOrNull { it.name == initialTab } ?: Tab.GENERAL) }
    val boxShape = RoundedCornerShape(S.CORNER_RADIUS.dp)

    MaterialTheme(colorScheme = darkColorScheme(primary = S.accent, surface = S.box, surfaceContainer = S.box, onSurface = S.label)) {
        Column(
            Modifier
                .fillMaxSize()
                .background(S.background)
                .safeDrawingPadding()
                .padding(horizontal = S.MARGIN.dp),
        ) {
            Row(Modifier.fillMaxWidth().height(56.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(40.dp).clickable(onClick = onBack), contentAlignment = Alignment.Center) {
                    BackIcon(22.dp, 1.5.dp, S.label)
                }
                Text("Settings", style = labelStyle.copy(fontSize = 20.sp))
            }

            // The tab bar sits across the box's top edge, as on the Mac.
            Box(Modifier.fillMaxWidth().weight(1f).padding(bottom = S.MARGIN.dp)) {
                Column(
                    Modifier
                        .fillMaxSize()
                        .padding(top = (S.TAB_BAR_HEIGHT / 2).dp)
                        .background(S.box, boxShape)
                        .border(1.dp, S.border, boxShape)
                        .verticalScroll(rememberScrollState())
                        .padding(horizontal = S.BOX_PADDING.dp)
                        .padding(top = (S.TAB_BAR_HEIGHT / 2 + S.BOX_PADDING).dp, bottom = S.BOX_PADDING.dp),
                ) {
                    val update = timer::updateSettings
                    val blocked: @Composable (Boolean) -> Unit = { wanted ->
                        if (wanted && !notificationsAllowed) BlockedHint(onFixNotifications)
                    }
                    when (tab) {
                        Tab.GENERAL -> GeneralTab(settings, update, blocked)
                        Tab.INTERVALS -> IntervalsTab(settings, timer, update)
                        Tab.SOUNDS -> SoundsTab(settings, timer.sound, update, blocked)
                        Tab.MAC -> MacTab(sync, onPair)
                    }
                }
                TabBar(tab, Modifier.align(Alignment.TopCenter)) { tab = it }
            }
        }
    }
}

@Composable
private fun TabBar(selected: Tab, modifier: Modifier, onSelect: (Tab) -> Unit) {
    val shape = RoundedCornerShape(S.CORNER_RADIUS.dp)
    Row(
        modifier
            .height(S.TAB_BAR_HEIGHT.dp)
            .background(S.tabBar, shape)
            .border(1.dp, S.border, shape)
            .padding(2.dp),
    ) {
        Tab.entries.forEach { item ->
            Box(
                Modifier
                    .fillMaxHeight()
                    .background(if (item == selected) S.tabSelected else Color.Transparent, RoundedCornerShape((S.CORNER_RADIUS - 1).dp))
                    .clickable { onSelect(item) }
                    .padding(horizontal = 10.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(item.title, style = TextStyle(color = S.tabText, fontSize = S.TAB_TEXT_SIZE.sp))
            }
        }
    }
}

@Composable
private fun GeneralTab(s: Settings, update: (Settings) -> Unit, blocked: @Composable (Boolean) -> Unit) {
    val g = s.general
    CheckRow("Auto-start next interval", g.autoStartNextInterval) {
        update(s.copy(general = g.copy(autoStartNextInterval = it)))
    }
    CheckRow("Show timer in notifications", g.showTimerInNotification) {
        update(s.copy(general = g.copy(showTimerInNotification = it)))
    }
    blocked(g.showTimerInNotification)
}

@Composable
private fun IntervalsTab(s: Settings, timer: TimerRepository, update: (Settings) -> Unit) {
    val i = s.intervals
    MinutesRow("Work interval", i.workMinutes, timer) { update(s.copy(intervals = i.copy(workMinutes = it))) }
    MinutesRow("Short break", i.shortBreakMinutes, timer) { update(s.copy(intervals = i.copy(shortBreakMinutes = it))) }
    MinutesRow("Long break", i.longBreakMinutes, timer) { update(s.copy(intervals = i.copy(longBreakMinutes = it))) }
    FormRow("Long break after") {
        Stepper(i.longBreakAfter, "intervals") { update(s.copy(intervals = i.copy(longBreakAfter = it.coerceIn(1, 12)))) }
    }
}

@Composable
private fun MinutesRow(label: String, minutes: Double, timer: TimerRepository, set: (Double) -> Unit) {
    // The limit as the field shows it: 59:59 reads as 60.
    val limit = ceil(timer.dial.maxMinutes).toInt()
    var hints by remember { mutableIntStateOf(0) }
    Column {
        FormRow(label) {
            Stepper(minutes.roundToInt(), "min") {
                if (it > limit) hints++
                // At least a minute: 0 here would make a one-second interval.
                set(timer.dial.clampMinutes(it.coerceAtLeast(1).toDouble()))
            }
        }
        TransientHint("Max $limit min", hints, secondaryStyle, Modifier.align(Alignment.End))
    }
}

@Composable
private fun SoundsTab(s: Settings, player: SoundPlayer, update: (Settings) -> Unit, blocked: @Composable (Boolean) -> Unit) {
    val sound = s.sound
    val sounds = remember { player.available() }
    val on = sound.soundEnabled
    CheckRow("Play a sound when an interval ends", on) { update(s.copy(sound = sound.copy(soundEnabled = it))) }
    Column(Modifier.alpha(if (on) 1f else 0.4f)) {
        FormRow("Work completed sound") {
            SoundPicker(sound.workCompletedSound, sounds, on) {
                player.play(it, sound.volume)
                update(s.copy(sound = sound.copy(workCompletedSound = it)))
            }
        }
        FormRow("Break ended sound") {
            SoundPicker(sound.breakEndedSound, sounds, on) {
                player.play(it, sound.volume)
                update(s.copy(sound = sound.copy(breakEndedSound = it)))
            }
        }
        FormRow("Volume") {
            Slider(
                value = sound.volume.toFloat(),
                onValueChange = { update(s.copy(sound = sound.copy(volume = it.toDouble()))) },
                onValueChangeFinished = { player.play(sound.workCompletedSound, sound.volume) },
                enabled = on,
                colors = SliderDefaults.colors(thumbColor = S.accent, activeTrackColor = S.accent, inactiveTrackColor = S.border),
                modifier = Modifier.width(160.dp),
            )
        }
    }
    Text("Notifications", style = secondaryStyle, modifier = Modifier.padding(top = 22.dp, bottom = 8.dp))
    CheckRow("Show a notification when an interval ends", sound.notificationsEnabled) {
        update(s.copy(sound = sound.copy(notificationsEnabled = it)))
    }
    blocked(sound.notificationsEnabled)
}

@Composable
private fun MacTab(sync: SyncClient, onPair: () -> Unit) {
    val status by sync.status.collectAsStateWithLifecycle()
    val text = when (val s = status) {
        SyncClient.Status.NotPaired -> "Pair with Pomodoro on your Mac to see and control one timer from both, over your Wi-Fi."
        SyncClient.Status.Pairing -> "Pairing…"
        SyncClient.Status.Searching -> "Looking for the Mac on this Wi-Fi…"
        SyncClient.Status.Connected -> "Connected to the Mac."
        is SyncClient.Status.Failed -> s.message
    }
    Text(text, style = labelStyle, modifier = Modifier.padding(vertical = 12.dp))
    val paired = sync.isPaired
    Text(
        if (paired) "Forget the Mac" else "Pair with Mac",
        style = labelStyle.copy(color = S.accent),
        modifier = Modifier.clickable { if (paired) sync.forget() else onPair() }.padding(vertical = 12.dp),
    )
    if (paired) {
        Text("Pair again", style = labelStyle.copy(color = S.accent), modifier = Modifier.clickable(onClick = onPair).padding(vertical = 12.dp))
    }
}

@Composable
private fun FormRow(label: String, control: @Composable () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = S.ROW_HEIGHT.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(label, style = labelStyle, modifier = Modifier.weight(1f).padding(end = 8.dp))
        control()
    }
}

@Composable
private fun CheckRow(label: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    FormRow(label) {
        Checkbox(checked, onChange, colors = CheckboxDefaults.colors(checkedColor = S.accent, checkmarkColor = S.box))
    }
}

@Composable
private fun BlockedHint(onFix: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 40.dp), verticalAlignment = Alignment.CenterVertically) {
        Text("Notifications are off for Pomodoro in Android settings", style = secondaryStyle, modifier = Modifier.weight(1f))
        Text("Allow", style = labelStyle.copy(color = S.accent), modifier = Modifier.clickable(onClick = onFix).padding(8.dp))
    }
}

/** − field + : typing commits on Done or when the field loses focus. */
@Composable
private fun Stepper(value: Int, unit: String, onChange: (Int) -> Unit) {
    var draft by remember(value) { mutableStateOf(value.toString()) }
    var focused by remember { mutableStateOf(false) }
    fun commit() = draft.toIntOrNull()?.takeIf { it != value }?.let(onChange)
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        StepButton("−") { onChange(value - 1) }
        BasicTextField(
            value = draft,
            onValueChange = { draft = it.filter(Char::isDigit).take(3) },
            singleLine = true,
            textStyle = labelStyle.copy(textAlign = TextAlign.Center),
            cursorBrush = SolidColor(S.accent),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { commit() }),
            modifier = Modifier
                .width(40.dp)
                .border(1.dp, S.border, fieldShape)
                .padding(vertical = 6.dp)
                .onFocusChanged {
                    if (focused && !it.isFocused) commit()
                    focused = it.isFocused
                },
        )
        StepButton("+") { onChange(value + 1) }
        Text(unit, style = labelStyle.copy(color = S.secondary))
    }
}

@Composable
private fun StepButton(symbol: String, onClick: () -> Unit) {
    Box(
        Modifier.size(36.dp).border(1.dp, S.border, fieldShape).clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(symbol, style = labelStyle.copy(fontSize = 18.sp))
    }
}

@Composable
private fun SoundPicker(selected: String, sounds: List<SoundPlayer.Sound>, enabled: Boolean, onSelect: (String) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        Row(
            Modifier
                .width(140.dp)
                .border(1.dp, S.border, fieldShape)
                .clickable(enabled = enabled) { open = true }
                .padding(horizontal = 10.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            val title = sounds.firstOrNull { it.key == selected }?.title ?: "Custom"
            Text(title, maxLines = 1, style = labelStyle, modifier = Modifier.weight(1f, fill = false))
            Spacer(Modifier.width(6.dp))
            Text("▾", style = labelStyle.copy(color = S.secondary))
        }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            sounds.forEach { sound ->
                DropdownMenuItem(text = { Text(sound.title) }, onClick = { open = false; onSelect(sound.key) })
            }
        }
    }
}
