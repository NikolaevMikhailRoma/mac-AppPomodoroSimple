package com.nikolaev.pomodoro.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import com.nikolaev.pomodoro.R
import kotlin.math.roundToInt

/** The timer screen is drawn in the Mac popover's points, multiplied by [scale]. */
class Units(val scale: Float) {
    fun dp(points: Double): Dp = (points * scale).dp
}

val LocalUnits = compositionLocalOf { Units(1f) }

/**
 * Inter shipped with the app, the closest free font to the Mac's: the phone's
 * own may lack the thin weights (Motorola's has none, and the digits came out
 * bold). res/font/inter.ttf is Google Fonts' Inter[opsz,wght] cut down to
 * weights 100-600 and printable ASCII and a few marks, 62 KB; licence in
 * licenses/Inter-OFL.txt. Made with fonttools:
 *   fonttools varLib.instancer 'Inter[opsz,wght].ttf' opsz=14:32 wght=100:600 -o cut.ttf
 *   pyftsubset cut.ttf --unicodes='U+0020-007E,U+00B7,U+2026,U+2013,U+2014,U+2190,U+2192,U+2212' --name-IDs='*' \
 *     --layout-features='tnum,kern' --output-file=inter.ttf
 */
private val weights = listOf(FontWeight.Thin, FontWeight.ExtraLight, FontWeight.Light, FontWeight.Normal, FontWeight.SemiBold)

private val families = mutableMapOf<Int, FontFamily>()

/** Optical size follows the text size: large digits get Inter's display forms. */
private fun inter(size: Float): FontFamily {
    val opsz = size.coerceIn(14f, 32f).roundToInt()
    return families.getOrPut(opsz) {
        FontFamily(
            weights.map {
                val axes = FontVariation.Settings(FontVariation.weight(it.weight), FontVariation.Setting("opsz", opsz.toFloat()))
                Font(R.font.inter, it, variationSettings = axes)
            },
        )
    }
}

/**
 * Text sized like the rest of the layout, in dp rather than sp: the phone's
 * font-size setting would otherwise push the digits out of the ring.
 */
@Composable
fun fontStyle(font: Design.Font, color: Color): TextStyle {
    val size = with(LocalDensity.current) { LocalUnits.current.dp(font.size).toSp() }
    return TextStyle(
        fontFamily = inter(size.value),
        fontWeight = font.weight,
        fontSize = size,
        color = color,
        fontFeatureSettings = "tnum",
    )
}

/** Settings text, in sp: it follows the phone's font-size setting. */
fun textStyle(size: TextUnit, color: Color, weight: FontWeight = FontWeight.Normal) =
    TextStyle(fontFamily = inter(size.value), fontWeight = weight, fontSize = size, color = color)
