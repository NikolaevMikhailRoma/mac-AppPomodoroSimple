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
import com.nikolaev.pomodoro.ui.Design.Popover as P
import com.nikolaev.pomodoro.ui.Design.Ring as R
import kotlinx.coroutines.delay

private const val TICK_MS = 250L

/** The Mac popover, laid out for a phone: header at the top, ring in the middle, footer at the bottom. */
@Composable
fun TimerScreen(timer: TimerRepository, onStart: () -> Unit, onOpenSettings: () -> Unit) {
    val state by timer.state.collectAsStateWithLifecycle()
    val running = state.runState == RunState.RUNNING

    val lifecycle = LocalLifecycleOwner.current.lifecycle
    LaunchedEffect(running) {
        if (!running) return@LaunchedEffect
        lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
            while (true) {
                timer.tick()
                delay(TICK_MS)
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

    BoxWithConstraints(Modifier.fillMaxSize().background(P.background)) {
        // Fit the popover's proportions into the screen whichever way the phone is turned.
        val scale = minOf(maxWidth.value / P.WIDTH, maxHeight.value / P.HEIGHT).toFloat()
        val units = Units(scale)
        CompositionLocalProvider(LocalUnits provides units) {
            Column(Modifier.fillMaxSize().safeDrawingPadding().padding(units.dp(P.PADDING))) {
                Row(
                    Modifier.fillMaxWidth().heightIn(min = units.dp(P.HEADER_HEIGHT)),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(state.phase.title, style = fontStyle(Design.Fonts.phase, P.textDim))
                    Spacer(Modifier.weight(1f))
                    IconButton(onClick = { commitIfEditing(); timer.stop() }) {
                        ResetIcon(units.dp(Design.Icons.RESET), units.dp(Design.Icons.LINE_WIDTH), P.textSecondary)
                    }
                }

                Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                    Ring(timer.dial.fraction(state.remaining), accent) {
                        commitIfEditing()
                        timer.setDurationFraction(it)
                    }

                    Box(
                        Modifier.offset(y = units.dp(R.DIGITS_OFFSET)).width(units.dp(R.DIAMETER - R.LINE_WIDTH * 4)),
                        contentAlignment = Alignment.Center,
                    ) {
                        val style = fontStyle(Design.Fonts.digits, accent).copy(textAlign = TextAlign.Center)
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
                        style = fontStyle(Design.Fonts.hint, P.textSecondary),
                        modifier = Modifier.offset(y = units.dp(R.HINT_OFFSET)),
                    )

                    Box(Modifier.offset(y = units.dp(R.PLAY_OFFSET))) {
                        TransportButton(running, accent) {
                            commitIfEditing()
                            if (!running) onStart()
                            timer.toggle()
                        }
                    }
                }

                Row(
                    Modifier.fillMaxWidth().heightIn(min = units.dp(P.FOOTER_HEIGHT)),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(Modifier.width(units.dp(P.FOOTER_SIDE_WIDTH)), contentAlignment = Alignment.CenterStart) {
                        IconButton(onClick = { commitIfEditing(); timer.skip() }) {
                            SkipIcon(units.dp(Design.Icons.SKIP), units.dp(Design.Icons.LINE_WIDTH), P.textSecondary)
                        }
                    }
                    Row(
                        Modifier.weight(1f),
                        horizontalArrangement = Arrangement.spacedBy(units.dp(P.COUNTER_SPACING), Alignment.CenterHorizontally),
                    ) {
                        Text("Today", style = fontStyle(Design.Fonts.counter, P.textSecondary))
                        Text("${state.completedToday}", style = fontStyle(Design.Fonts.counter, accent))
                    }
                    Box(Modifier.width(units.dp(P.FOOTER_SIDE_WIDTH)), contentAlignment = Alignment.CenterEnd) {
                        IconButton(onClick = { commitIfEditing(); onOpenSettings() }) {
                            GearIcon(units.dp(Design.Icons.SETTINGS), units.dp(Design.Icons.LINE_WIDTH), P.textSecondary)
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
