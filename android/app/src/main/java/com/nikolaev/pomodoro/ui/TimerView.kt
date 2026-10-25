package com.nikolaev.pomodoro.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.repeatOnLifecycle
import com.nikolaev.pomodoro.TimerRepository
import com.nikolaev.pomodoro.core.RunState
import com.nikolaev.pomodoro.core.TimeFormat
import kotlinx.coroutines.delay

/** A tick comes this long after the shown second turned: a delay can run late, never early. */
private const val TICK_MARGIN_MS = 10L

/** Until the shown time turns next: it is rounded up, so it turns when whole seconds are left. */
private fun untilTurn(endsAt: Double): Long =
    Math.floorMod((endsAt * 1000).toLong() - System.currentTimeMillis(), 1000L) + TICK_MARGIN_MS

/** The Mac popover, laid out for a phone: header at the top, ring in the middle, footer at the bottom. */
@Composable
fun TimerView(timer: TimerRepository, onStart: () -> Unit, onOpenSettings: () -> Unit) {
    val state by timer.state.collectAsStateWithLifecycle()
    val running = state.runState == RunState.RUNNING

    val lifecycle = LocalLifecycleOwner.current.lifecycle
    // While running, one tick each time the shown time turns, and none in between;
    // a new end (a drag, a state from the Mac) starts the count again.
    LaunchedEffect(state.endsAt) {
        val endsAt = state.endsAt ?: return@LaunchedEffect
        lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
            while (true) {
                timer.tick()
                delay(untilTurn(endsAt))
            }
        }
    }

    val accent = Design.accent(state.phase)
    var limitHints by remember { mutableIntStateOf(0) }
    var draft by remember { mutableStateOf<TextFieldValue?>(null) }

    fun commitIfEditing() {
        draft?.let { if (timer.setDurationText(it.text)) limitHints++ }
        draft = null
    }

    BoxWithConstraints(Modifier.fillMaxSize().background(Design.popover.color("background"))) {
        // Fit the popover's proportions into the screen whichever way the phone is turned.
        val scale = minOf(maxWidth.value / Design.popover["width"], maxHeight.value / Design.popover["height"]).toFloat()
        val units = Units(scale)
        CompositionLocalProvider(LocalUnits provides units) {
            Column(Modifier.fillMaxSize().safeDrawingPadding().padding(units.dp(Design.popover["padding"]))) {
                Row(
                    Modifier.fillMaxWidth().heightIn(min = units.dp(Design.popover["headerHeight"])),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(state.phase.title, style = fontStyle(Design.fonts.font("phase"), Design.popover.color("textDim")))
                    Spacer(Modifier.weight(1f))
                    IconButton(onClick = { commitIfEditing(); timer.stop() }) {
                        ResetIcon(units.dp(Design.icons.iconSize("reset")), units.dp(ICON_LINE_WIDTH), Design.popover.color("textSecondary"))
                    }
                }

                // Below the middle by as much as the popover's gaps differ, as on the Mac.
                val lower = units.dp(Design.popover["headerToRing"] - Design.popover["ringToFooter"])
                Box(Modifier.weight(1f).fillMaxWidth().padding(top = lower), contentAlignment = Alignment.Center) {
                    RingView(timer.dial.fraction(state.remaining), accent) {
                        commitIfEditing()
                        timer.setDurationFraction(it)
                    }

                    Box(
                        Modifier.offset(y = units.dp(Design.ring["digitsOffset"])).width(units.dp(Design.ring["diameter"] - Design.ring["lineWidth"] * 4)),
                        contentAlignment = Alignment.Center,
                    ) {
                        val style = fontStyle(Design.fonts.font("digits"), accent).copy(textAlign = TextAlign.Center)
                        val current = draft
                        if (current == null) {
                            Text(
                                TimeFormat.string(state.remaining),
                                style = style,
                                maxLines = 1,
                                modifier = Modifier.clickable(remember { MutableInteractionSource() }, indication = null) {
                                    val text = TimeFormat.string(state.remaining)
                                    draft = TextFieldValue(text, TextRange(0, text.length))
                                },
                            )
                        } else {
                            DigitsField(current, style, onChange = { draft = it }, onDone = ::commitIfEditing)
                        }
                    }

                    TransientHint(
                        text = "Max ${TimeFormat.string(timer.dial.maxSeconds)}",
                        trigger = limitHints,
                        style = fontStyle(Design.fonts.font("hint"), Design.popover.color("textSecondary")),
                        modifier = Modifier.offset(y = units.dp(Design.ring["hintOffset"])),
                    )

                    Box(Modifier.offset(y = units.dp(Design.ring["playOffset"]))) {
                        TransportButton(running, accent) {
                            commitIfEditing()
                            if (!running) onStart()
                            timer.toggle()
                        }
                    }
                }

                Row(
                    Modifier.fillMaxWidth().heightIn(min = units.dp(Design.popover["footerHeight"])),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(Modifier.width(units.dp(Design.popover["footerSideWidth"])), contentAlignment = Alignment.CenterStart) {
                        IconButton(onClick = { commitIfEditing(); timer.skip() }) {
                            SkipIcon(units.dp(Design.icons.iconSize("skip")), units.dp(ICON_LINE_WIDTH), Design.popover.color("textSecondary"))
                        }
                    }
                    Row(
                        Modifier.weight(1f),
                        horizontalArrangement = Arrangement.spacedBy(units.dp(Design.popover["counterSpacing"]), Alignment.CenterHorizontally),
                    ) {
                        Text("Today", style = fontStyle(Design.fonts.font("counter"), Design.popover.color("textSecondary")))
                        Text("${state.completedToday}", style = fontStyle(Design.fonts.font("counter"), accent))
                    }
                    Box(Modifier.width(units.dp(Design.popover["footerSideWidth"])), contentAlignment = Alignment.CenterEnd) {
                        IconButton(onClick = { commitIfEditing(); onOpenSettings() }) {
                            GearIcon(units.dp(Design.icons.iconSize("settings")), units.dp(ICON_LINE_WIDTH), Design.popover.color("textSecondary"))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DigitsField(value: TextFieldValue, style: TextStyle, onChange: (TextFieldValue) -> Unit, onDone: () -> Unit) {
    val focus = remember { FocusRequester() }
    var focused by remember { mutableStateOf(false) }
    BasicTextField(
        value = value,
        onValueChange = onChange,
        textStyle = style,
        singleLine = true,
        cursorBrush = SolidColor(style.color),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal, imeAction = ImeAction.Done),
        keyboardActions = KeyboardActions(onDone = { onDone() }),
        modifier = Modifier
            .focusRequester(focus)
            .onFocusChanged {
                // Leaving the field commits, like clicking away on the Mac.
                if (focused && !it.isFocused) onDone()
                focused = it.isFocused
            },
    )
    LaunchedEffect(Unit) { focus.requestFocus() }
}

/** A finger-sized touch area around a small drawn icon, without the Material ripple. */
@Composable
private fun IconButton(onClick: () -> Unit, content: @Composable () -> Unit) {
    Box(
        Modifier
            .clickable(remember { MutableInteractionSource() }, indication = null, onClick = onClick)
            .padding(8.dp),
        contentAlignment = Alignment.Center,
    ) { content() }
}

/**
 * A hint that appears and fades out on its own. To show it, raise `trigger`.
 * It always holds its space, so neighbours never jump.
 */
@Composable
fun TransientHint(text: String, trigger: Int, style: TextStyle, modifier: Modifier = Modifier) {
    var visible by remember { mutableStateOf(false) }
    val alpha by animateFloatAsState(if (visible) 1f else 0f, tween(if (visible) 150 else 400), label = "hint")
    LaunchedEffect(trigger) {
        if (trigger == 0) return@LaunchedEffect
        visible = true
        delay(2_000)
        visible = false
    }
    Text(text, style = style, modifier = modifier.alpha(alpha))
}
