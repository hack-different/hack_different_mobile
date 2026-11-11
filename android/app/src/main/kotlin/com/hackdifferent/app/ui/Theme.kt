package com.hackdifferent.app.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import com.audiencekit.Branding

private val HackGreen = Color(0xFF32D74B)
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

    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = dynamicAccent ?: HackGreen,
            secondary = HackCyan,
            background = HackDarkBg,
            surface = HackDarkSurface,
        ),
        content = content,
    )
}
