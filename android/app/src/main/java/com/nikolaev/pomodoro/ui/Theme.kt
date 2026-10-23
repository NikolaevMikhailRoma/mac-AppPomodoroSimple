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
import androidx.compose.ui.unit.dp
import com.nikolaev.pomodoro.R

/** The timer screen is drawn in the Mac popover's points, multiplied by [scale]. */
class Units(val scale: Float) {
    fun dp(points: Double): Dp = (points * scale).dp
}

val LocalUnits = compositionLocalOf { Units(1f) }

/**
 * Roboto shipped with the app: the phone's own font may have no thin weight
 * (Motorola's has none, and the digits came out bold). res/font/roboto.ttf is
 * Google Fonts' Roboto[wdth,wght] cut down to weights 100-300 and printable
 * ASCII, 29 KB; licence in licenses/Roboto-OFL.txt. Made with fonttools:
 *   fonttools varLib.instancer Roboto[wdth,wght].ttf wdth=100 wght=100:300 -o cut.ttf
 *   pyftsubset cut.ttf --unicodes='U+0020-007E,U+00B7' --name-IDs='*' --layout-features='tnum,kern' --output-file=roboto.ttf
 */
private val roboto = FontFamily(
    listOf(FontWeight.Thin, FontWeight.ExtraLight, FontWeight.Light).map {
        Font(R.font.roboto, it, variationSettings = FontVariation.Settings(FontVariation.weight(it.weight)))
    },
)

/**
 * Text sized like the rest of the layout, in dp rather than sp: the phone's
 * font-size setting would otherwise push the digits out of the ring.
 */
@Composable
fun fontStyle(font: Design.Font, color: Color): TextStyle {
    val size = with(LocalDensity.current) { LocalUnits.current.dp(font.size).toSp() }
    return TextStyle(
        fontFamily = roboto,
        fontWeight = font.weight,
        fontSize = size,
        color = color,
        fontFeatureSettings = "tnum",
    )
}
