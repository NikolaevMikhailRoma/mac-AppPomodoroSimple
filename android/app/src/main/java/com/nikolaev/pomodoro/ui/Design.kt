package com.nikolaev.pomodoro.ui

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import com.nikolaev.pomodoro.core.Phase

/**
 * The look of the app, in one place. Colours and timer-screen sizes are copied
 * from the Mac's config.json (measured off its screenshots); the timer-screen
 * numbers are the popover's points, which [Units] scales to the phone.
 */
object Design {
    private val work = Color(0xFFEC958C)
    private val pause = Color(0xFF8CD3A2)

    /** Text and ring colour: red-ish while working, green on a break. */
    fun accent(phase: Phase): Color = if (phase == Phase.WORK) work else pause

    object Popover {
        const val WIDTH = 256.0
        const val HEIGHT = 335.0
        const val PADDING = 14.0
        const val HEADER_HEIGHT = 22.0
        const val FOOTER_HEIGHT = 22.0
        const val FOOTER_SIDE_WIDTH = 44.0
        const val COUNTER_SPACING = 6.0
        val background = Color(0xFF252525)
        val textSecondary = Color(0xFFC8C8C8)
        val textDim = Color(0xFF646464)
    }

    object Ring {
        const val DIAMETER = 196.0
        const val LINE_WIDTH = 4.0
        const val HANDLE_DIAMETER = 22.0
        const val HANDLE_LINE_WIDTH = 2.0
        /**
         * How far inside the ring a touch still grabs it, as a fraction of the
         * radius. The Mac takes clicks over the whole disc; on a phone that turns
         * every stray touch near the digits into a new duration.
         */
        const val TOUCH_BAND = 0.3
        val track = Color(0xFF3D3D3D)
        const val DIGITS_OFFSET = -9.5
        const val PLAY_OFFSET = 57.75
        const val HINT_OFFSET = 26.0
        const val PLAY_SIDE = 34.0
        const val PLAY_LINE_WIDTH = 1.0
        const val PLAY_TRIANGLE_RATIO = 0.866
        const val PLAY_BAR_WIDTH_RATIO = 0.26
        const val PLAY_BAR_HEIGHT_RATIO = 0.82
        const val PLAY_GAP_RATIO = 0.24
    }

    data class Font(val size: Double, val weight: FontWeight)

    object Fonts {
        val digits = Font(55.0, FontWeight.Thin)
        val counter = Font(20.0, FontWeight.Light)
        val hint = Font(13.0, FontWeight.Light)
        val phase = Font(15.0, FontWeight.Light)
    }

    object Icons {
        const val SETTINGS = 18.0
        const val SKIP = 18.0
        const val RESET = 22.0
        const val LINE_WIDTH = 0.9
    }

    /** The settings screen is in dp: a phone needs finger-sized rows, not the Mac's 27 points. */
    object Settings {
        val background = Color(0xFF303132)
        val box = Color(0xFF373738)
        val border = Color(0xFF505051)
        val label = Color(0xFFD1D1D1)
        val secondary = Color(0xFF8C8C8C)
        val tabBar = Color(0xFF333333)
        val tabSelected = Color(0xFF666666)
        val tabText = Color(0xFFE0E0E0)
        val accent = work
        const val MARGIN = 16.0
        const val BOX_PADDING = 16.0
        const val ROW_HEIGHT = 52.0
        const val LABEL_SIZE = 16.0
        const val SECONDARY_SIZE = 13.0
        const val TAB_BAR_HEIGHT = 36.0
        const val TAB_TEXT_SIZE = 14.0
        const val CORNER_RADIUS = 6.0
    }
}
