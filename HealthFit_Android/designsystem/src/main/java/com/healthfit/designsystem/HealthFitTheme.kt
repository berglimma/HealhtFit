package com.healthfit.designsystem

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/**
 * Tokens aligned to iOS `AppTheme` / Assets.xcassets:
 * AccentGreen, AccentOrange, Background, CardBackground.
 * Default experience is dark (same as iOS shipping look).
 */
object HealthFitColors {
    val Accent = Color(0xFF33D92E)          // AccentGreen ~ (0.20, 0.85, 0.18)
    val AccentSecondary = Color(0xFFFF8C33) // AccentOrange ~ (1.00, 0.55, 0.20)
    val Background = Color(0xFF14191A)      // Background ~ (0.08, 0.10, 0.10)
    val CardBackground = Color(0xFF24292E)  // CardBackground ~ (0.14, 0.16, 0.18)
    val TextPrimary = Color(0xFFFFFFFF)
    val TextSecondary = Color(0xFFB0B8C0)
    val Danger = Color(0xFFFF453A)
    val SurfaceElevated = Color(0xFF2C333A)
}

private val DarkScheme = darkColorScheme(
    primary = HealthFitColors.Accent,
    secondary = HealthFitColors.AccentSecondary,
    background = HealthFitColors.Background,
    surface = HealthFitColors.CardBackground,
    onPrimary = Color.Black,
    onSecondary = Color.Black,
    onBackground = HealthFitColors.TextPrimary,
    onSurface = HealthFitColors.TextPrimary,
    error = HealthFitColors.Danger,
)

@Composable
fun HealthFitTheme(
    @Suppress("UNUSED_PARAMETER") darkTheme: Boolean = true,
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = DarkScheme, // faithful dark parity with iOS
        typography = HealthFitTypography,
        content = content,
    )
}
