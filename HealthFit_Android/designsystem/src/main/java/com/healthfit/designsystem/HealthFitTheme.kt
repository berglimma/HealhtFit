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
    val Accent = Color(0xFF3DDC3A)
    val AccentSecondary = Color(0xFFFF8C33)
    val Background = Color(0xFF0E1113)
    val CardBackground = Color(0xFF1C2126)
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
