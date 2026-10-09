package com.healthfit.android.ui.home

import android.provider.Settings
import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.sp
import kotlin.math.PI
import kotlin.math.sin
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive

@Composable
fun SleepNightAtmosphere(modifier: Modifier = Modifier) {
    val time = rememberAtmosphereSeconds()
    val textMeasurer = rememberTextMeasurer()
    Canvas(modifier) {
        val w = size.width
        val h = size.height
        if (w < 1f || h < 1f) return@Canvas
        drawRect(
            brush = Brush.linearGradient(
                colors = listOf(
                    Color(0.07f, 0.09f, 0.22f, 0.92f),
                    Color(0.12f, 0.10f, 0.28f, 0.55f),
                    Color(0.18f, 0.12f, 0.32f, 0.18f),
                ),
                start = Offset(w * 0.15f, 0f),
                end = Offset(w * 0.9f, h),
            ),
        )
        val glow = 0.88f + 0.08f * sin(time * 0.55).toFloat()
        val center = Offset(w * 0.06f, h * 0.10f)
        val radius = minOf(w, h) * 0.11f
        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(
                    Color(0.85f, 0.90f, 1f, 0.28f * glow),
                    Color(0.45f, 0.50f, 0.85f, 0.08f),
                    Color.Transparent,
                ),
                center = center,
                radius = radius * 2.6f,
            ),
            radius = radius * 2.6f,
            center = center,
        )
        drawCircle(
            color = Color(0.93f, 0.95f, 1f, 0.55f * glow),
            radius = radius,
            center = center,
        )
        drawOval(
            color = Color.White.copy(alpha = 0.18f),
            topLeft = Offset(center.x + radius * 0.15f, center.y - radius * 0.2f),
            size = Size(radius * 0.28f, radius * 0.22f),
        )
        val stars = listOf(
            Star(0.08f, 0.18f, 1.4f, 0.0),
            Star(0.22f, 0.12f, 1.1f, 0.7),
            Star(0.34f, 0.28f, 1.7f, 1.3),
            Star(0.48f, 0.10f, 1.2f, 2.1),
            Star(0.61f, 0.22f, 1.5f, 0.4),
            Star(0.12f, 0.42f, 1.0f, 1.8),
            Star(0.27f, 0.58f, 1.3f, 2.6),
            Star(0.41f, 0.48f, 1.6f, 0.9),
            Star(0.55f, 0.62f, 1.1f, 1.5),
            Star(0.70f, 0.38f, 1.4f, 2.4),
            Star(0.78f, 0.55f, 1.2f, 0.2),
            Star(0.18f, 0.78f, 1.0f, 1.1),
            Star(0.63f, 0.80f, 1.3f, 2.0),
            Star(0.88f, 0.68f, 1.1f, 0.6),
            Star(0.05f, 0.66f, 1.2f, 1.7),
        )
        stars.forEach { star ->
            val twinkle = 0.35f + 0.65f * (0.5f + 0.5f * sin(time * 1.7 + star.phase).toFloat())
            drawCircle(
                color = Color.White.copy(alpha = 0.22f + 0.45f * twinkle),
                radius = star.radius,
                center = Offset(w * star.x, h * star.y),
            )
        }
        listOf("z", "z", "Z").forEachIndexed { index, glyph ->
            val drift = sin(time * 0.7 + index * 1.4)
            val lift = ((time * 0.12 + index * 0.33) % 1.0).toFloat()
            val x = w * (0.58f + 0.12f * index) + drift.toFloat() * 6f
            val y = h * (0.28f - lift * 0.18f)
            val opacity = 0.12f + 0.22f * (1f - lift)
            val layout = textMeasurer.measure(
                glyph,
                TextStyle(
                    color = Color.White.copy(alpha = opacity),
                    fontSize = (11 + index * 3).sp,
                    fontWeight = FontWeight.SemiBold,
                ),
            )
            drawText(
                layout,
                topLeft = Offset(x - layout.size.width / 2f, y - layout.size.height / 2f),
            )
        }
    }
}

@Composable
fun WaterRippleAtmosphere(modifier: Modifier = Modifier) {
    val time = rememberAtmosphereSeconds()
    Canvas(modifier) {
        val w = size.width
        val h = size.height
        if (w < 1f || h < 1f) return@Canvas
        drawRect(
            brush = Brush.linearGradient(
                colors = listOf(
                    Color(0.08f, 0.18f, 0.32f, 0.55f),
                    Color(0.10f, 0.32f, 0.52f, 0.28f),
                    Color(0.12f, 0.42f, 0.62f, 0.12f),
                ),
                start = Offset(w * 0.5f, 0f),
                end = Offset(w * 0.5f, h),
            ),
        )
        repeat(3) { index ->
            val amplitude = h * (0.045f + 0.03f * index)
            val baseY = h * (0.58f + 0.10f * index)
            val wavelength = w * (0.78f + 0.14f * index)
            val speed = 0.62 + 0.16 * index
            val phase = time * speed + index * 1.05
            val bob = sin(time * 0.4 + index).toFloat() * (h * 0.01f)
            val path = Path()
            path.moveTo(0f, h + 2f)
            path.lineTo(0f, baseY + bob)
            val steps = maxOf((w / 8f).toInt(), 16)
            for (step in 0..steps) {
                val x = w * step / steps
                val angle = (x / wavelength.coerceAtLeast(1f)) * (PI * 2) + phase
                val y = baseY + bob + sin(angle).toFloat() * amplitude
                path.lineTo(x, y)
            }
            path.lineTo(w, h + 2f)
            path.close()
            drawPath(
                path,
                Color(0.35f, 0.72f, 1f, 0.16f + 0.10f * index),
            )
        }
        val bubbles = listOf(
            Bubble(0.12f, 6f, 0.0, 9.0),
            Bubble(0.28f, 4.5f, 1.2, 11.0),
            Bubble(0.46f, 5.5f, 0.6, 8.0),
            Bubble(0.63f, 3.8f, 2.1, 12.0),
            Bubble(0.81f, 5.0f, 1.5, 10.0),
            Bubble(0.91f, 3.4f, 0.3, 13.0),
        )
        bubbles.forEach { bubble ->
            val progress = ((time + bubble.phase) % bubble.duration) / bubble.duration
            val x = w * bubble.x + sin(time * 1.2 + bubble.phase).toFloat() * 4f
            val y = h * (1.05f - progress.toFloat() * 1.15f)
            val fade = sin(progress * PI).toFloat()
            drawCircle(
                color = Color(0.55f, 0.82f, 1f, 0.12f * fade),
                radius = bubble.radius,
                center = Offset(x, y),
            )
            drawCircle(
                color = Color.White.copy(alpha = 0.18f + 0.28f * fade),
                radius = bubble.radius,
                center = Offset(x, y),
                style = Stroke(width = 1.5f, cap = StrokeCap.Round),
            )
        }
    }
}

@Composable
private fun rememberAtmosphereSeconds(): Double {
    val reduceMotion = rememberReduceMotion()
    var seconds by remember { mutableDoubleStateOf(0.0) }
    LaunchedEffect(reduceMotion) {
        if (reduceMotion) {
            seconds = 0.0
            return@LaunchedEffect
        }
        val start = System.nanoTime()
        while (isActive) {
            seconds = (System.nanoTime() - start) / 1_000_000_000.0
            delay(80)
        }
    }
    return seconds
}

@Composable
private fun rememberReduceMotion(): Boolean {
    val context = LocalContext.current
    return remember {
        Settings.Global.getFloat(
            context.contentResolver,
            Settings.Global.ANIMATOR_DURATION_SCALE,
            1f,
        ) == 0f
    }
}

private data class Star(val x: Float, val y: Float, val radius: Float, val phase: Double)
private data class Bubble(val x: Float, val radius: Float, val phase: Double, val duration: Double)
