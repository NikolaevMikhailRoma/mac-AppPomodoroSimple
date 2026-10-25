package com.nikolaev.pomodoro.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.drag
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import com.nikolaev.pomodoro.core.DialDrag
import kotlin.math.PI
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin

/**
 * The ring with its handle. The canvas is wider than the ring by one handle,
 * because the handle sits centred on the ring's edge and its outer half must
 * still take a touch.
 */
@Composable
fun RingView(turnFraction: Double, color: Color, onDrag: (Double) -> Unit) {
    val units = LocalUnits.current
    val fraction by rememberUpdatedState(turnFraction)
    val dragTo by rememberUpdatedState(onDrag)

    Canvas(
        Modifier
            .size(units.dp(Design.ring["diameter"] + Design.ring["handleDiameter"]))
            .pointerInput(units.scale) {
                val radius = units.dp(Design.ring["diameter"] / 2).toPx()
                val handle = units.dp(Design.ring["handleDiameter"] / 2).toPx()
                awaitEachGesture {
                    val down = awaitFirstDown()
                    val center = Offset(size.width / 2f, size.height / 2f)
                    val distance = (down.position - center).getDistance()
                    // Only the band along the ring answers, not the whole disc.
                    if (distance < radius * (1 - Design.phone["ringTouchBand"]).toFloat() || distance > radius + handle) {
                        return@awaitEachGesture
                    }
                    down.consume()
                    val raw = angleFraction(down.position, center)
                    // A touch on the handle picks it up as it is; elsewhere it moves the handle there.
                    val dial = if (DialDrag.distance(raw, fraction) < DialDrag.GRAB_DISTANCE) {
                        DialDrag(fraction)
                    } else {
                        dragTo(raw)
                        DialDrag(raw)
                    }
                    drag(down.id) { change ->
                        val before = dial.fraction
                        val after = dial.move(angleFraction(change.position, center))
                        if (after != before) dragTo(after)
                        change.consume()
                    }
                }
            },
    ) {
        val radius = units.dp(Design.ring["diameter"] / 2).toPx()
        val line = Stroke(units.dp(Design.ring["lineWidth"]).toPx())
        drawCircle(Design.ring.color("trackColor"), radius, center, style = line)
        drawArc(
            color,
            startAngle = -90f,
            sweepAngle = 360f * maxOf(fraction, 0.0001).toFloat(),
            useCenter = false,
            topLeft = Offset(center.x - radius, center.y - radius),
            size = Size(radius * 2, radius * 2),
            style = line,
        )
        val angle = fraction * 2 * PI
        val handleCenter = Offset(center.x + radius * sin(angle).toFloat(), center.y - radius * cos(angle).toFloat())
        val handleRadius = units.dp(Design.ring["handleDiameter"] / 2).toPx()
        val handleLine = units.dp(Design.ring["handleLineWidth"]).toPx()
        drawCircle(Design.popover.color("background"), handleRadius, handleCenter)
        drawCircle(color, handleRadius - handleLine / 2, handleCenter, style = Stroke(handleLine))
    }
}

/** The angle from the centre, clockwise from twelve o'clock, as a fraction of a turn. */
private fun angleFraction(point: Offset, center: Offset): Double {
    val angle = atan2((point.x - center.x).toDouble(), (center.y - point.y).toDouble())
    return (if (angle < 0) angle + 2 * PI else angle) / (2 * PI)
}

/** Play and pause in one button. Every size inside is a fraction of the button's side. */
@Composable
fun TransportButton(isRunning: Boolean, color: Color, onClick: () -> Unit) {
    val units = LocalUnits.current
    Canvas(
        Modifier
            .size(units.dp(Design.ring["playSide"]))
            .clickable(remember { MutableInteractionSource() }, indication = null, onClick = onClick),
    ) {
        val side = size.minDimension
        val line = units.dp(Design.ring["playLineWidth"]).toPx()
        if (isRunning) {
            val barW = side * Design.ring["playBarWidthRatio"].toFloat()
            val barH = side * Design.ring["playBarHeightRatio"].toFloat()
            val gap = side * Design.ring["playGapRatio"].toFloat()
            val left = (side - (2 * barW + gap)) / 2
            for (x in listOf(left, left + barW + gap)) {
                drawRoundRect(color, Offset(x, (side - barH) / 2), Size(barW, barH), CornerRadius(line), style = Stroke(line))
            }
        } else {
            val width = side * Design.ring["playTriangleRatio"].toFloat()
            val left = (side - width) / 2
            val triangle = Path().apply {
                moveTo(left, 0f)
                lineTo(left, side)
                lineTo(left + width, side / 2)
                close()
            }
            drawPath(triangle, color, style = Stroke(line))
        }
    }
}
