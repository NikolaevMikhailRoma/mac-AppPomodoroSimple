package com.nikolaev.pomodoro.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.font.FontWeight
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
import kotlin.math.ceil
import kotlin.math.roundToInt

/**
 * The Mac's settings window for a phone, as PhoneConfig.forPhone makes it on
 * the iPhone: text and spacing times `phone.settingsScale`, the phone's own
 * margins and row height; pickers and the slider keep the Mac's widths.
 */
private object M {
    private val s = Design.settings
    private val p = Design.phone
    private val k = p["settingsScale"]

    val rowHeight = maxOf(s["rowHeight"] * k, p["rowHeight"]).dp
    val rowSpacing = (s["rowSpacing"] * k).dp
    val controlWidth = s["controlWidth"].dp
    val fieldWidth = (s["fieldWidth"] * k).dp
    val stepperSpacing = (s["stepperSpacing"] * k).dp
    val sliderWidth = s["sliderWidth"].dp
    val sectionTop = (s["sectionTopPadding"] * k).dp
    val sectionBottom = (s["sectionBottomPadding"] * k).dp
    val tabBarHeight = (s["tabBarHeight"] * k).dp
    val tabInset = (s["tabInset"] * k).dp
    val tabPadding = (s["tabPadding"] * k).dp
    val tabDivider = Pair(s["tabDividerWidth"].dp, (s["tabDividerHeight"] * k).dp)
    val tabTextSize = (s["tabTextSize"] * k).sp
    val corner = (s["cornerRadius"] * k).dp
    val innerCorner = (s["cornerRadius"] * k - s["innerCornerDelta"]).dp
    val border = s["borderWidth"].dp
    val labelSize = (s["labelSize"] * k).sp
    val hintSize = (s["sectionHeaderSize"] * k).sp
    val margin = p["margin"].dp
    val boxPadding = p["boxPadding"].dp
    val top = p["top"].dp

    val background = s.color("background")
    val box = s.color("boxBackground")
    val boxBorder = s.color("boxBorder")
    val label = s.color("labelColor")
    val hint = s.color("sectionHeaderColor")
    val tabBackground = s.color("tabBackground")
    val tabSelected = s.color("tabSelectedFill")
    val tabDividerColor = s.color("tabDivider")
    val tabText = s.color("tabTextColor")
    val tint = p.color("tint")
    val fill = p.color("fill")
}

/** The iPhone's stepper: one capsule, − and + halves. */
private val stepperSize = Pair(94.dp, 32.dp)
private val fieldShape = RoundedCornerShape(8.dp)

private val labelStyle get() = textStyle(M.labelSize, M.label)
private val hintStyle get() = textStyle(M.hintSize, M.hint)
private val actionStyle get() = textStyle(M.labelSize, M.tint)

private enum class Tab(val title: String) {
    GENERAL("General"),
    INTERVALS("Intervals"),
    SOUNDS("Sounds"),
    DEVICES("Devices"),
}

/** The settings window: tabs across the top edge of a box, form rows inside, as on the Mac and the iPhone. */
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
    val boxShape = RoundedCornerShape(M.corner)

    MaterialTheme(colorScheme = darkColorScheme(primary = M.tint, surface = M.box, surfaceContainer = M.box, onSurface = M.label)) {
        Column(Modifier.fillMaxSize().background(M.background).safeDrawingPadding()) {
            TitleBar("Settings", onBack)

            // The tab bar sits across the box's top edge.
            Box(Modifier.fillMaxWidth().weight(1f).padding(horizontal = M.margin).padding(top = M.top, bottom = M.margin)) {
                Column(
                    Modifier
                        .fillMaxSize()
                        .padding(top = M.tabBarHeight / 2)
                        .background(M.box, boxShape)
                        .border(M.border, M.boxBorder, boxShape)
                        .verticalScroll(rememberScrollState())
                        .padding(horizontal = M.boxPadding)
                        .padding(top = M.tabBarHeight / 2 + M.boxPadding, bottom = M.boxPadding),
                ) {
                    val update = timer::updateSettings
                    val blocked = @Composable { wanted: Boolean ->
                        if (wanted && !notificationsAllowed) {
                            HintRow("Notifications are off for Pomodoro in Android settings", "Allow", onFixNotifications)
                        }
                    }
                    when (tab) {
                        Tab.GENERAL -> {
                            val g = settings.general
                            ToggleRow("Show timer in notifications", g.showTimerInNotification) {
                                update(settings.copy(general = g.copy(showTimerInNotification = it)))
                            }
                            blocked(g.showTimerInNotification)
                            ToggleRow("Auto-start next interval", g.autoStartNextInterval) {
                                update(settings.copy(general = g.copy(autoStartNextInterval = it)))
                            }
                        }
                        Tab.INTERVALS -> IntervalsTab(settings, timer, update)
                        Tab.SOUNDS -> SoundsTab(settings, timer.sound, update) { blocked(settings.sound.notificationsEnabled) }
                        Tab.DEVICES -> DevicesTab(sync, onPair)
                    }
                }
                TabBar(tab, Modifier.align(Alignment.TopCenter)) { tab = it }
            }
        }
    }
}

/** A back arrow and the title in the middle, as the iPhone's navigation bar. */
@Composable
fun TitleBar(title: String, onBack: () -> Unit) {
    Box(Modifier.fillMaxWidth().height(44.dp)) {
        Box(Modifier.size(44.dp).clickable(onClick = onBack), contentAlignment = Alignment.Center) {
            BackIcon(22.dp, 1.5.dp, M.tint)
        }
        Text(title, style = textStyle(17.sp, M.label, FontWeight.SemiBold), modifier = Modifier.align(Alignment.Center))
    }
}

@Composable
private fun TabBar(selected: Tab, modifier: Modifier, onSelect: (Tab) -> Unit) {
    val shape = RoundedCornerShape(M.corner)
    Row(
        modifier
            .height(M.tabBarHeight)
            .background(M.tabBackground, shape)
            .border(M.border, M.boxBorder, shape),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Tab.entries.forEachIndexed { index, item ->
            if (index > 0) Box(Modifier.size(M.tabDivider.first, M.tabDivider.second).background(M.tabDividerColor))
            Box(
                Modifier
                    .height(M.tabBarHeight - M.tabInset)
                    .background(if (item == selected) M.tabSelected else Color.Transparent, RoundedCornerShape(M.innerCorner))
                    .clickable(remember { MutableInteractionSource() }, indication = null) { onSelect(item) }
                    .padding(horizontal = M.tabPadding),
                contentAlignment = Alignment.Center,
            ) {
                Text(item.title, style = textStyle(M.tabTextSize, M.tabText), maxLines = 1)
            }
        }
    }
}

@Composable
private fun IntervalsTab(s: Settings, timer: TimerRepository, update: (Settings) -> Unit) {
    val i = s.intervals
    MinutesRow("Work interval", i.workMinutes, timer) { update(s.copy(intervals = i.copy(workMinutes = it))) }
    MinutesRow("Short break", i.shortBreakMinutes, timer) { update(s.copy(intervals = i.copy(shortBreakMinutes = it))) }
    MinutesRow("Long break", i.longBreakMinutes, timer) { update(s.copy(intervals = i.copy(longBreakMinutes = it))) }
    FormRow("Long break after") {
        NumberField(i.longBreakAfter, "intervals") { update(s.copy(intervals = i.copy(longBreakAfter = it.coerceIn(1, 12)))) }
    }
}

@Composable
private fun MinutesRow(label: String, minutes: Double, timer: TimerRepository, set: (Double) -> Unit) {
    // The limit as the field shows it: 59:59 reads as 60.
    val limit = ceil(timer.dial.maxMinutes).toInt()
    var hints by remember { mutableIntStateOf(0) }
    FormRow(label, hint = { TransientHint("Max $limit min", hints, hintStyle) }) {
        NumberField(minutes.roundToInt(), "min") {
            if (it > limit) hints++
            // At least a minute: 0 here would make a one-second interval.
            set(timer.dial.clampMinutes(it.coerceAtLeast(1).toDouble()))
        }
    }
}

// Slider's thumb and track are still experimental in Material 3.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SoundsTab(s: Settings, player: SoundPlayer, update: (Settings) -> Unit, notes: @Composable () -> Unit) {
    val sound = s.sound
    val sounds = remember { player.available() }
    val off = !sound.soundEnabled
    ToggleRow("Play a sound when an interval ends", sound.soundEnabled) { update(s.copy(sound = sound.copy(soundEnabled = it))) }
    FormRow("Work completed sound", disabled = off) {
        SoundPicker(sound.workCompletedSound, sounds, !off) {
            player.play(it, sound.volume)
            update(s.copy(sound = sound.copy(workCompletedSound = it)))
        }
    }
    FormRow("Break ended sound", disabled = off) {
        SoundPicker(sound.breakEndedSound, sounds, !off) {
            player.play(it, sound.volume)
            update(s.copy(sound = sound.copy(breakEndedSound = it)))
        }
    }
    FormRow("Volume", disabled = off) {
        // A thin track and a round knob, as on the Mac and the iPhone, not Material's thick bar.
        Slider(
            value = sound.volume.toFloat(),
            onValueChange = { update(s.copy(sound = sound.copy(volume = it.toDouble()))) },
            onValueChangeFinished = { player.play(sound.workCompletedSound, sound.volume) },
            enabled = !off,
            thumb = { Box(Modifier.size(24.dp).shadow(2.dp, CircleShape).background(Color.White, CircleShape)) },
            track = { state ->
                Box(Modifier.fillMaxWidth().height(4.dp).background(M.fill, CircleShape)) {
                    val range = state.valueRange
                    val fraction = (state.value - range.start) / (range.endInclusive - range.start)
                    Box(Modifier.fillMaxWidth(fraction).fillMaxHeight().background(if (off) M.hint else M.tint, CircleShape))
                }
            },
            modifier = Modifier.width(M.sliderWidth),
        )
    }
    SectionHeader("Notifications")
    ToggleRow("Show a notification when an interval ends", sound.notificationsEnabled) {
        update(s.copy(sound = sound.copy(notificationsEnabled = it)))
    }
    notes()
}

/** Like the Mac's Devices tab: the paired Mac in a row, with its state and Forget. */
@Composable
private fun DevicesTab(sync: SyncClient, onPair: () -> Unit) {
    val status by sync.status.collectAsStateWithLifecycle()
    if (sync.isPaired) {
        FormRow(sync.pairedTitle) {
            val state = when (status) {
                SyncClient.Status.Connected -> "Connected"
                SyncClient.Status.Pairing -> "Pairing…"
                SyncClient.Status.Searching -> "Looking…"
                else -> ""
            }
            Text(state, style = hintStyle, modifier = Modifier.padding(end = M.rowSpacing))
            Action("Forget", sync::forget)
        }
    } else {
        Text(
            "Pair with Pomodoro on your Mac to see and control one timer from both, over your Wi-Fi.",
            style = labelStyle,
            modifier = Modifier.padding(vertical = M.rowSpacing),
        )
    }
    (status as? SyncClient.Status.Failed)?.let { Text(it.message, style = hintStyle, modifier = Modifier.padding(vertical = M.rowSpacing)) }
    Box(Modifier.fillMaxWidth().padding(top = M.sectionTop), contentAlignment = Alignment.Center) {
        Action(if (sync.isPaired) "Pair again" else "Pair with Mac", onPair)
    }
}

/** A label on the left, its control on the right; a long label wraps. `hint` shows over the label's free end. */
@Composable
private fun FormRow(label: String, disabled: Boolean = false, hint: @Composable () -> Unit = {}, control: @Composable () -> Unit) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = M.rowHeight),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(M.rowSpacing),
    ) {
        Box(Modifier.weight(1f), contentAlignment = Alignment.CenterEnd) {
            Text(label, style = textStyle(M.labelSize, if (disabled) M.hint else M.label), modifier = Modifier.fillMaxWidth())
            hint()
        }
        control()
    }
}

/** On or off: the platform's own switch, in the Mac's green. */
@Composable
private fun ToggleRow(label: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    FormRow(label) {
        Switch(
            checked,
            onChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = M.tint,
                checkedBorderColor = M.tint,
                uncheckedThumbColor = Color.White,
                uncheckedTrackColor = M.fill,
                uncheckedBorderColor = Color.Transparent,
            ),
        )
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        title.uppercase(),
        style = hintStyle.copy(textAlign = TextAlign.Center),
        modifier = Modifier.fillMaxWidth().padding(top = M.sectionTop, bottom = M.sectionBottom),
    )
}

/** Something switched off in the system's settings, and the button that goes there. */
@Composable
private fun HintRow(text: String, button: String, action: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = M.rowHeight), verticalAlignment = Alignment.CenterVertically) {
        Text(text, style = hintStyle, modifier = Modifier.weight(1f))
        Action(button, action)
    }
}

/** A button as text in the controls' colour, as on the iPhone. */
@Composable
private fun Action(title: String, onClick: () -> Unit) {
    Text(title, style = actionStyle, modifier = Modifier.clickable(onClick = onClick).padding(horizontal = 4.dp, vertical = 8.dp))
}

/** A number to type, − and + beside it, and its unit. Typing commits on Done or when the field loses focus. */
@Composable
private fun NumberField(value: Int, unit: String, onChange: (Int) -> Unit) {
    var draft by remember(value) { mutableStateOf(value.toString()) }
    var focused by remember { mutableStateOf(false) }
    fun commit() = draft.toIntOrNull()?.takeIf { it != value }?.let(onChange)
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(M.stepperSpacing)) {
        BasicTextField(
            value = draft,
            onValueChange = { draft = it.filter(Char::isDigit).take(3) },
            singleLine = true,
            textStyle = labelStyle.copy(textAlign = TextAlign.End),
            cursorBrush = SolidColor(M.tint),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { commit() }),
            modifier = Modifier
                .width(M.fieldWidth)
                .background(M.fill, fieldShape)
                .padding(horizontal = 8.dp, vertical = 6.dp)
                .onFocusChanged {
                    if (focused && !it.isFocused) commit()
                    focused = it.isFocused
                },
        )
        Row(
            Modifier.size(stepperSize.first, stepperSize.second).background(M.fill, fieldShape),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            StepButton("−", Modifier.weight(1f)) { onChange(value - 1) }
            Box(Modifier.size(1.dp, stepperSize.second / 2).background(M.boxBorder))
            StepButton("+", Modifier.weight(1f)) { onChange(value + 1) }
        }
        Text(unit, style = textStyle(M.labelSize, M.hint))
    }
}

@Composable
private fun StepButton(symbol: String, modifier: Modifier, onClick: () -> Unit) {
    Box(modifier.height(stepperSize.second).clickable(onClick = onClick), contentAlignment = Alignment.Center) {
        Text(symbol, style = textStyle(20.sp, M.label))
    }
}

/** The chosen sound in the controls' colour and two chevrons, as the iPhone's pop-up menu. */
@Composable
private fun SoundPicker(selected: String, sounds: List<SoundPlayer.Sound>, enabled: Boolean, onSelect: (String) -> Unit) {
    var open by remember { mutableStateOf(false) }
    val color = if (enabled) M.tint else M.hint
    Box(Modifier.width(M.controlWidth), contentAlignment = Alignment.Center) {
        Row(
            Modifier.clickable(enabled = enabled) { open = true }.padding(vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            val title = sounds.firstOrNull { it.key == selected }?.title ?: "Custom"
            Text(title, maxLines = 1, style = textStyle(M.labelSize, color), modifier = Modifier.weight(1f, fill = false))
            UpDownIcon(12.dp, 1.5.dp, color)
        }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            sounds.forEach { sound ->
                DropdownMenuItem(text = { Text(sound.title, style = labelStyle) }, onClick = { open = false; onSelect(sound.key) })
            }
        }
    }
}
