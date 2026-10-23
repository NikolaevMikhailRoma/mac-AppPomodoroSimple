package com.nikolaev.pomodoro.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.Dp
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

// Thin outline icons drawn by hand in the style of the ultralight SF Symbols
// on the Mac (xmark.circle, forward.end, gearshape): Material icons are
// heavier and would not match.

@Composable
private fun IconCanvas(size: Dp, line: Dp, draw: DrawScope.(Stroke) -> Unit) {
    Canvas(Modifier.size(size)) {
        draw(Stroke(width = line.toPx(), join = StrokeJoin.Round))
    }
}

@Composable
fun ResetIcon(size: Dp, line: Dp, color: Color) = IconCanvas(size, line) { stroke ->
    val s = this.size.minDimension
    val c = center
    drawCircle(color, radius = s * 0.46f - stroke.width / 2, center = c, style = stroke)
    val arm = s * 0.16f
    drawLine(color, c + Offset(-arm, -arm), c + Offset(arm, arm), stroke.width)
    drawLine(color, c + Offset(arm, -arm), c + Offset(-arm, arm), stroke.width)
}

@Composable
fun SkipIcon(size: Dp, line: Dp, color: Color) = IconCanvas(size, line) { stroke ->
    val s = this.size.minDimension
    val triangle = Path().apply {
        moveTo(s * 0.14f, s * 0.18f)
        lineTo(s * 0.14f, s * 0.82f)
        lineTo(s * 0.68f, s * 0.5f)
        close()
    }
    drawPath(triangle, color, style = stroke)
    drawLine(color, Offset(s * 0.84f, s * 0.16f), Offset(s * 0.84f, s * 0.84f), stroke.width)
}

@Composable
fun GearIcon(size: Dp, line: Dp, color: Color) = IconCanvas(size, line) { stroke ->
    val s = this.size.minDimension
    val c = center
    val teeth = 8
    val outer = s * 0.47f - stroke.width / 2
    val root = s * 0.37f
    val step = 2 * PI / teeth
    val tipHalf = step * 0.19
    val rootHalf = step * 0.29
    fun at(r: Float, a: Double) = Offset(c.x + r * cos(a).toFloat(), c.y + r * sin(a).toFloat())
    val rootRect = Rect(c, root)
    val gear = Path()
    for (i in 0 until teeth) {
        val a = i * step - PI / 2
        val start = at(root, a - rootHalf)
        if (i == 0) gear.moveTo(start.x, start.y) else gear.lineTo(start.x, start.y)
        at(outer, a - tipHalf).let { gear.lineTo(it.x, it.y) }
        at(outer, a + tipHalf).let { gear.lineTo(it.x, it.y) }
        at(root, a + rootHalf).let { gear.lineTo(it.x, it.y) }
        val arcStart = Math.toDegrees(a + rootHalf).toFloat()
        val arcSweep = Math.toDegrees(step - 2 * rootHalf).toFloat()
        gear.arcTo(rootRect, arcStart, arcSweep, false)
    }
    gear.close()
    drawPath(gear, color, style = stroke)
    drawCircle(color, radius = s * 0.15f, center = c, style = stroke)
}

@Composable
fun BackIcon(size: Dp, line: Dp, color: Color) = IconCanvas(size, line) { stroke ->
    val s = this.size.minDimension
    val path = Path().apply {
        moveTo(s * 0.62f, s * 0.18f)
        lineTo(s * 0.3f, s * 0.5f)
        lineTo(s * 0.62f, s * 0.82f)
    }
    drawPath(path, color, style = stroke)
}
