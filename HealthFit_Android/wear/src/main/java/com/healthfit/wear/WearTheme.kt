package com.healthfit.wear

import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.Chip
import androidx.wear.compose.material.ChipColors
import androidx.wear.compose.material.ChipDefaults
import androidx.wear.compose.material.Colors
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.healthfit.designsystem.HealthFitColors

/** Cores locais do relógio, derivadas do design system (verde de destaque, fundo escuro). */
object WearColors {
    val Accent = HealthFitColors.Accent
    val Orange = HealthFitColors.AccentSecondary
    val Background = HealthFitColors.Background
    val Card = HealthFitColors.CardBackground
    val Elevated = HealthFitColors.SurfaceElevated
    val TextPrimary = HealthFitColors.TextPrimary
    val TextSecondary = HealthFitColors.TextSecondary
    val Danger = HealthFitColors.Danger
    val Cyan = Color(0xFF32D4DE)
}

@Composable
fun HealthFitWearTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colors = Colors(
            primary = WearColors.Accent,
            primaryVariant = WearColors.Accent,
            secondary = WearColors.Orange,
            secondaryVariant = WearColors.Orange,
            background = WearColors.Background,
            surface = WearColors.Card,
            error = WearColors.Danger,
            onPrimary = Color.Black,
            onSecondary = Color.Black,
            onBackground = WearColors.TextPrimary,
            onSurface = WearColors.TextPrimary,
            onSurfaceVariant = WearColors.TextSecondary,
            onError = Color.Black,
        ),
        content = content,
    )
}

fun meditationColor(name: String): Color = when (name) {
    "blue" -> Color(0xFF0A84FF)
    "teal" -> Color(0xFF30B0C7)
    "pink" -> Color(0xFFFF375F)
    "indigo" -> Color(0xFF5E5CE6)
    "green" -> Color(0xFF30D158)
    "purple" -> Color(0xFFBF5AF2)
    "orange" -> Color(0xFFFF9F0A)
    else -> WearColors.Accent
}

@Composable
fun cardChipColors(): ChipColors = ChipDefaults.chipColors(
    backgroundColor = WearColors.Card,
    contentColor = WearColors.TextPrimary,
    secondaryContentColor = WearColors.TextSecondary,
)

@Composable
fun HFChip(
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    secondary: String? = null,
    enabled: Boolean = true,
    colors: ChipColors = cardChipColors(),
    maxLines: Int = 2,
    trailing: (@Composable BoxScope.() -> Unit)? = null,
) {
    Chip(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier.fillMaxWidth(),
        colors = colors,
        label = {
            Text(label, maxLines = maxLines, overflow = TextOverflow.Ellipsis, fontSize = 13.sp)
        },
        secondaryLabel = secondary?.let {
            { Text(it, maxLines = 2, overflow = TextOverflow.Ellipsis, fontSize = 10.sp) }
        },
        icon = trailing,
    )
}
