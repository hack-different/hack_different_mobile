package com.hackdifferent.app.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import com.audiencekit.Branding

private val HackGreen = Color(0xFF32D74B)
/** Readable text on [HackGreen]: the SDK's near-black for light fills. */
private val HackOnGreen = Color(0xFF111411)
private val HackCyan = Color(0xFF5AC8FA)
private val HackDarkBg = Color(0xFF0E110E)
private val HackDarkSurface = Color(0xFF181C18)

/**
 * Hack Different is dark-mode only: the palette is designed for dark and the
 * app ignores the system light/dark setting.
 */
@Composable
fun HackDifferentTheme(
    branding: Branding? = null,
    content: @Composable () -> Unit,
) {
    val dynamicAccent = branding?.theme?.color("accent", dark = true)?.let { Color(it.toArgb()) }
    // Text on the accent: the theme's on-accent when it passes WCAG AA, else near-black or white, whichever
    // reads. Lime needs dark text (white on #c5f467 is 1.3:1).
    val onAccent = branding?.theme?.onAccent(dark = true)?.let { Color(it.toArgb()) } ?: HackOnGreen

    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = dynamicAccent ?: HackGreen,
            onPrimary = onAccent,
            secondary = HackCyan,
            background = HackDarkBg,
            surface = HackDarkSurface,
        ),
        content = content,
    )
}
