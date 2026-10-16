package com.healthfit.android.ui.kite

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Air
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Water
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.healthfit.designsystem.HealthFitColors
import kotlin.math.cos
import kotlin.math.sin

@Composable
fun WindTideConditionsCard(
    snapshot: WindTideSnapshot?,
    loading: Boolean,
    error: String?,
    isKitesurf: Boolean,
    onRefresh: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val direction = snapshot?.windDirectionDegrees ?: 90.0
    val speed = snapshot?.windSpeedKmh ?: 18.0

    Box(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(
                Brush.verticalGradient(
                    listOf(Color(0xFF0E2438), Color(0xFF123040), Color(0xFF0A1A24)),
                ),
            ),
    ) {
        AnimatedOceanWaves(Modifier.matchParentSize())
        AnimatedWindLines(
            directionDegrees = direction,
            speedKmh = speed,
            modifier = Modifier
                .fillMaxWidth()
                .height(100.dp)
                .align(Alignment.TopCenter),
        )
        Column(Modifier.padding(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.Air, null, tint = Color.Cyan, modifier = Modifier.size(18.dp))
                Text(
                    "Vento e maré",
                    color = Color.White,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 14.sp,
                    modifier = Modifier.padding(start = 6.dp).weight(1f),
                )
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .clip(RoundedCornerShape(10.dp))
                        .clickable(enabled = !loading, onClick = onRefresh)
                        .padding(horizontal = 8.dp, vertical = 4.dp),
                ) {
                    if (loading) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(14.dp),
                            color = HealthFitColors.Accent,
                        )
                    } else {
                        Icon(Icons.Filled.Refresh, null, tint = HealthFitColors.Accent, modifier = Modifier.size(16.dp))
                        Text(
                            "Atualizar",
                            color = HealthFitColors.Accent,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.padding(start = 4.dp),
                        )
                    }
                }
            }

            Spacer(Modifier.height(10.dp))

            when {
                loading && snapshot == null -> {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(18.dp),
                            color = HealthFitColors.Accent,
                        )
                        Text(
                            "Buscando vento e maré (Open-Meteo)…",
                            color = HealthFitColors.TextSecondary,
                            fontSize = 12.sp,
                            modifier = Modifier.padding(start = 10.dp),
                        )
                    }
                }
                snapshot != null -> {
                    Text(
                        snapshot.beachSportMessage(isKitesurf),
                        color = HealthFitColors.Accent,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 14.sp,
                    )
                    Spacer(Modifier.height(8.dp))
                    FavorabilityChip(snapshot.favorabilityLabel(isKitesurf))
                    Spacer(Modifier.height(8.dp))
                    TideTrendRow(snapshot)
                    Spacer(Modifier.height(10.dp))
                    MetricGrid(snapshot)
                    if (snapshot.marineHours.isNotEmpty()) {
                        Spacer(Modifier.height(10.dp))
                        Text("Próximas horas", color = HealthFitColors.TextSecondary, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                        Spacer(Modifier.height(6.dp))
                        Row(
                            Modifier.horizontalScroll(rememberScrollState()),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            snapshot.marineHours.take(6).forEach { hour ->
                                Column(
                                    Modifier
                                        .clip(RoundedCornerShape(8.dp))
                                        .background(Color.Black.copy(alpha = 0.35f))
                                        .padding(horizontal = 8.dp, vertical = 6.dp),
                                ) {
                                    Text(hour.hourLabel, color = HealthFitColors.Accent, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                                    hour.seaLevelMeters?.let {
                                        Text("%+.2f m".format(it), color = Color.White, fontSize = 11.sp)
                                    }
                                    hour.waveHeightMeters?.let {
                                        Text("%.1f m ↗".format(it), color = HealthFitColors.TextSecondary, fontSize = 10.sp)
                                    }
                                }
                            }
                        }
                    }
                    Text(
                        snapshot.locationLabel,
                        color = HealthFitColors.TextSecondary,
                        fontSize = 11.sp,
                        modifier = Modifier.padding(top = 8.dp),
                    )
                }
                error != null -> {
                    Text(error, color = HealthFitColors.TextSecondary, fontSize = 12.sp)
                    Text(
                        "Ative a internet e a localização, depois toque em Atualizar.",
                        color = HealthFitColors.TextSecondary,
                        fontSize = 11.sp,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun FavorabilityChip(label: String) {
    val color = when {
        label.contains("favorável", ignoreCase = true) -> Color(0xFF3DDC4A)
        label.contains("moderad", ignoreCase = true) -> Color(0xFFFF9A3C)
        else -> Color(0xFFE85D4C)
    }
    Text(
        label,
        color = Color.White,
        fontSize = 11.sp,
        fontWeight = FontWeight.Bold,
        modifier = Modifier
            .clip(RoundedCornerShape(99.dp))
            .background(color.copy(alpha = 0.85f))
            .padding(horizontal = 10.dp, vertical = 4.dp),
    )
}

@Composable
private fun TideTrendRow(snapshot: WindTideSnapshot) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.Black.copy(alpha = 0.28f))
            .padding(10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Filled.Water, null, tint = Color.Cyan, modifier = Modifier.size(18.dp))
        Column(Modifier.padding(start = 8.dp).weight(1f)) {
            Text("Maré e ondas", color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
            Text(
                snapshot.estimatedTideLabel,
                color = HealthFitColors.TextSecondary,
                fontSize = 12.sp,
            )
        }
        snapshot.displayTideHeightMeters?.let {
            Text("%.2f m".format(it), color = Color.Cyan, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun MetricGrid(snapshot: WindTideSnapshot) {
    val items = buildList {
        add("Vento" to "${snapshot.windSpeedKmh.toInt()} km/h")
        add("Direção" to "${snapshot.windDirectionDegrees.toInt()}° · ${snapshot.windLabel}")
        snapshot.windGustsKmh?.let { add("Rajadas" to "${it.toInt()} km/h") }
        snapshot.waveHeightMeters?.let { add("Ondas" to "%.1f m".format(it)) }
        snapshot.wavePeriodSeconds?.let { add("Período" to "%.0f s".format(it)) }
        val time = android.text.format.DateFormat.format("HH:mm", snapshot.fetchedAtMs)
        add("Atualizado" to time.toString())
    }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        items.chunked(2).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                row.forEach { (title, value) ->
                    Column(
                        Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(10.dp))
                            .background(Color.Black.copy(alpha = 0.28f))
                            .padding(10.dp),
                    ) {
                        Text(title, color = HealthFitColors.TextSecondary, fontSize = 11.sp)
                        Text(value, color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                    }
                }
                if (row.size == 1) Spacer(Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun AnimatedOceanWaves(modifier: Modifier = Modifier) {
    val transition = rememberInfiniteTransition(label = "waves")
    val phase by transition.animateFloat(
        initialValue = 0f,
        targetValue = (Math.PI * 2).toFloat(),
        animationSpec = infiniteRepeatable(tween(4200, easing = LinearEasing), RepeatMode.Restart),
        label = "wavePhase",
    )
    Canvas(modifier) {
        val cyan = Color.Cyan.copy(alpha = 0.18f)
        for (wave in 0 until 3) {
            val path = Path()
            val yBase = size.height * (0.55f + wave * 0.12f)
            val amp = 10f + wave * 4f
            path.moveTo(0f, yBase)
            var x = 0f
            while (x <= size.width) {
                val y = yBase + sin(x / 42f + phase + wave) * amp
                path.lineTo(x, y)
                x += 6f
            }
            path.lineTo(size.width, size.height)
            path.lineTo(0f, size.height)
            path.close()
            drawPath(path, cyan.copy(alpha = 0.12f + wave * 0.04f))
        }
    }
}

@Composable
private fun AnimatedWindLines(
    directionDegrees: Double,
    speedKmh: Double,
    modifier: Modifier = Modifier,
) {
    val transition = rememberInfiniteTransition(label = "wind")
    val drift by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            tween((2200 - (speedKmh.coerceIn(8.0, 50.0) * 20)).toInt().coerceAtLeast(900), easing = LinearEasing),
            RepeatMode.Restart,
        ),
        label = "windDrift",
    )
    Canvas(modifier) {
        // Meteorological convention: degrees = where wind comes FROM; animate streaks in travel direction (+180).
        val travel = ((directionDegrees + 180.0) % 360.0).toFloat()
        rotate(degrees = travel, pivot = Offset(size.width / 2f, size.height / 2f)) {
            val count = 7
            for (i in 0 until count) {
                val y = size.height * (0.15f + i * 0.12f)
                val len = size.width * (0.28f + (i % 3) * 0.08f)
                val startX = (-size.width * 0.2f) + (size.width * 1.4f) * ((drift + i * 0.13f) % 1f)
                drawLine(
                    color = Color.Cyan.copy(alpha = 0.55f - i * 0.04f),
                    start = Offset(startX, y),
                    end = Offset(startX + len, y + sin(i.toFloat()) * 2f),
                    strokeWidth = 2.2f,
                    cap = StrokeCap.Round,
                )
            }
            // Compass arrow tip indicating wind travel
            val cx = size.width * 0.82f
            val cy = size.height * 0.5f
            drawCircle(Color.Cyan.copy(alpha = 0.85f), radius = 5f, center = Offset(cx, cy))
            drawLine(
                Color.Cyan.copy(alpha = 0.9f),
                Offset(cx - 18f, cy),
                Offset(cx + 10f, cy),
                strokeWidth = 2.5f,
                cap = StrokeCap.Round,
            )
        }
        // Static compass N marker
        drawCircle(Color.White.copy(alpha = 0.2f), radius = 16f, center = Offset(28f, 28f), style = Stroke(width = 1.5f))
        val rad = Math.toRadians(directionDegrees)
        val nx = 28f + cos(rad - Math.PI / 2).toFloat() * 11f
        val ny = 28f + sin(rad - Math.PI / 2).toFloat() * 11f
        drawLine(Color.Cyan, Offset(28f, 28f), Offset(nx, ny), strokeWidth = 2.5f, cap = StrokeCap.Round)
    }
}
