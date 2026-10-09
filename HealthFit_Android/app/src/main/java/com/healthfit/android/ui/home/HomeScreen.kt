package com.healthfit.android.ui.home

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Bed
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.NightsStay
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.Watch
import androidx.compose.material.icons.filled.WaterDrop
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material3.Icon
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.healthfit.android.R
import com.healthfit.designsystem.HealthFitColors
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.roundToInt

@Composable
fun HomeScreen(
    userName: String,
    wellness: DailyWellness,
    onOpenPulse: () -> Unit,
) {
    var finished by remember { mutableStateOf<FinishedWorkout?>(null) }
    var reportKind by remember { mutableStateOf<ReportKind?>(null) }
    var weeklySeen by remember { mutableStateOf(false) }
    val goalMl = wellness.goalMl
    val name = userName.ifBlank { "Berg" }
    val today = LocalDate.now()
    val weekStart = today.minusDays((today.dayOfWeek.value % 7).toLong())

    Box(Modifier.fillMaxSize().background(HealthFitColors.Background)) {
        Box(
            Modifier
                .fillMaxWidth()
                .height(320.dp)
                .background(
                    Brush.verticalGradient(
                        listOf(Color(0xFF16321C), Color(0xFF0E1113)),
                    ),
                ),
        )
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp)
            .padding(bottom = 12.dp),
    ) {
        val dateLabel = today.format(DateTimeFormatter.ofPattern("EEEE, d 'de' MMMM", Locale("pt", "BR")))
            .replaceFirstChar { it.titlecase(Locale("pt", "BR")) }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                "HOJE",
                color = HealthFitColors.Accent,
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                style = TextStyle(letterSpacing = 1.4.sp),
            )
            Spacer(Modifier.weight(1f))
            Text(dateLabel, color = Color(0xFF8E989F), fontSize = 12.sp)
        }
        Spacer(Modifier.height(10.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    greeting(name),
                    color = Color.White,
                    fontSize = 26.sp,
                    fontWeight = FontWeight.Bold,
                    lineHeight = 30.sp,
                )
                Text(
                    "Pronto para treinar hoje?",
                    color = Color(0xFFB7C0C8),
                    fontSize = 15.sp,
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
            BrandLogo(onClick = onOpenPulse)
        }

        Spacer(Modifier.height(16.dp))
        PulseHero(onClick = onOpenPulse)
        Spacer(Modifier.height(16.dp))
        WeekStrip(weekStart = weekStart, today = today)
        Spacer(Modifier.height(16.dp))
        SleepCard(hours = wellness.sleepHours, onHours = { wellness.sleepHours = it })
        Spacer(Modifier.height(12.dp))
        WaterCard(
            ml = wellness.waterMl,
            goal = goalMl,
            onMinus = { wellness.addWater(-250) },
            onPlus = { wellness.addWater(250) },
            onCup = { wellness.addWater(250) },
            onBottle = { wellness.addWater(500) },
        )
        DashboardLowerSections(
            onOpenRecent = { finished = it },
            onOpenReport = {
                if (it == ReportKind.Weekly) weeklySeen = true
                reportKind = it
            },
            weeklySeen = weeklySeen,
        )
    }
        finished?.let { session ->
            Box(Modifier.fillMaxSize().background(HealthFitColors.Background)) {
                WorkoutFinishedScreen(session = session, onClose = { finished = null })
            }
        }
        reportKind?.let { kind ->
            Box(Modifier.fillMaxSize().background(HealthFitColors.Background)) {
                ProgressReportScreen(
                    report = buildReport(kind, name, wellness),
                    onClose = { reportKind = null },
                )
            }
        }
    }
}

@Composable
private fun BrandLogo(onClick: () -> Unit) {
    val pulse = rememberInfiniteTransition(label = "brand")
    val scale by pulse.animateFloat(
        initialValue = 1f,
        targetValue = 1.06f,
        animationSpec = infiniteRepeatable(tween(1050), RepeatMode.Reverse),
        label = "brandScale",
    )
    Box(
        modifier = Modifier
            .size(58.dp)
            .clip(CircleShape)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            Modifier
                .size(52.dp)
                .scale(scale)
                .clip(CircleShape)
                .background(HealthFitColors.Accent.copy(alpha = 0.16f))
                .border(2.dp, HealthFitColors.Accent.copy(alpha = 0.55f), CircleShape),
        )
        Image(
            painter = painterResource(R.drawable.brandheart),
            contentDescription = "HealthFit",
            modifier = Modifier.size(42.dp).scale(scale),
            contentScale = ContentScale.Fit,
        )
    }
}

@Composable
private fun PulseHero(onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(198.dp)
            .clip(RoundedCornerShape(26.dp))
            .clickable(onClick = onClick),
    ) {
        Row(Modifier.matchParentSize()) {
            Image(
                painter = painterResource(R.drawable.cardiocovercorrida),
                contentDescription = null,
                modifier = Modifier.weight(0.55f).fillMaxHeight(),
                contentScale = ContentScale.Crop,
            )
            Column(Modifier.weight(0.45f).fillMaxHeight()) {
                Image(
                    painter = painterResource(R.drawable.cardiocoverkitesurf),
                    contentDescription = null,
                    modifier = Modifier.weight(1f).fillMaxWidth(),
                    contentScale = ContentScale.Crop,
                )
                Row(Modifier.weight(1f).fillMaxWidth()) {
                    Image(
                        painter = painterResource(R.drawable.cardiocoversurf),
                        contentDescription = null,
                        modifier = Modifier.weight(1f).fillMaxHeight(),
                        contentScale = ContentScale.Crop,
                    )
                    Image(
                        painter = painterResource(R.drawable.cardiocovernatacao),
                        contentDescription = null,
                        modifier = Modifier.weight(1f).fillMaxHeight(),
                        contentScale = ContentScale.Crop,
                    )
                }
            }
        }
        Box(
            Modifier
                .matchParentSize()
                .background(
                    Brush.verticalGradient(
                        listOf(Color.Black.copy(alpha = 0.05f), Color.Black.copy(alpha = 0.78f)),
                    ),
                ),
        )
        Column(Modifier.align(Alignment.BottomStart).padding(16.dp)) {
            Text(
                "COMUNIDADE",
                color = HealthFitColors.Accent,
                fontWeight = FontWeight.Bold,
                fontSize = 11.sp,
                style = TextStyle(letterSpacing = 1.2.sp),
            )
            Text("HealthFit Pulse", color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.Bold)
            Text(
                "Sozinho você treina. Junto, você permanece.",
                color = Color.White.copy(alpha = 0.9f),
                fontSize = 13.sp,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(top = 8.dp)) {
                MiniLink(Icons.Filled.NightsStay, "Stories")
                MiniLink(Icons.Filled.Groups, "Comunidades")
                MiniLink(Icons.Filled.Favorite, "Ranking")
            }
        }
    }
}

@Composable
private fun MiniLink(icon: ImageVector, label: String) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(Color.Black.copy(alpha = 0.35f))
            .border(1.dp, Color.White.copy(alpha = 0.16f), RoundedCornerShape(20.dp))
            .padding(horizontal = 8.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, contentDescription = null, tint = Color.White, modifier = Modifier.size(12.dp))
        Text(" $label", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Medium)
    }
}

@Composable
private fun WeekStrip(weekStart: LocalDate, today: LocalDate) {
    val labels = listOf("DOM", "SEG", "TER", "QUA", "QUI", "SEX", "SÁB")
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        labels.forEachIndexed { index, label ->
            val date = weekStart.plusDays(index.toLong())
            val selected = date == today
            val future = date.isAfter(today)
            Column(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(18.dp))
                    .background(if (selected) HealthFitColors.Accent else Color(0xFF171C20))
                    .border(
                        1.dp,
                        when {
                            selected -> HealthFitColors.Accent
                            future -> Color.White.copy(alpha = 0.04f)
                            else -> HealthFitColors.Accent.copy(alpha = 0.28f)
                        },
                        RoundedCornerShape(18.dp),
                    )
                    .padding(vertical = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    label,
                    color = when {
                        selected -> Color.Black
                        future -> Color(0xFF6E777E)
                        else -> Color(0xFFD5DDE3)
                    },
                    fontSize = 9.sp,
                    fontWeight = FontWeight.Bold,
                    style = TextStyle(letterSpacing = 0.4.sp),
                )
                Text(
                    date.dayOfMonth.toString(),
                    color = if (selected) Color.Black else Color.White,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                )
                Box(
                    Modifier
                        .padding(top = 3.dp)
                        .size(4.dp)
                        .clip(CircleShape)
                        .background(
                            when {
                                selected -> Color.Black.copy(alpha = 0.45f)
                                future -> Color.Transparent
                                else -> HealthFitColors.Accent
                            },
                        ),
                )
            }
        }
    }
}

@Composable
fun SleepCard(hours: Float, onHours: (Float) -> Unit) {
    val whole = hours.toInt()
    val mins = ((hours - whole) * 60).roundToInt()
    val wake = 7 * 60 + 30
    val bed = wake - (hours * 60).roundToInt()
    val (status, statusColor) = when {
        hours in 7f..9f -> "Sono ideal" to HealthFitColors.Accent
        hours in 6f..10f -> "Quase na meta" to HealthFitColors.AccentSecondary
        hours < 6f -> "Sono curto" to Color(0xFFFF6B6B)
        else -> "Sono longo" to HealthFitColors.AccentSecondary
    }
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(26.dp))
            .background(Color(0xFF12181C))
            .border(1.dp, Color.White.copy(alpha = 0.07f), RoundedCornerShape(26.dp)),
    ) {
    SleepNightAtmosphere(Modifier.matchParentSize())
    Column(modifier = Modifier.padding(16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.08f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Filled.NightsStay, contentDescription = null, tint = Color(0xFFC9D4FF), modifier = Modifier.size(20.dp))
            }
            Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
                Text("Sono de hoje", color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 16.sp, maxLines = 1)
                Text("Meta 8 horas", color = Color(0xFFB7C0C8), fontSize = 12.sp, maxLines = 1)
            }
            Column(horizontalAlignment = Alignment.End) {
                Text(
                    String.format(Locale.US, "%.1f h", hours),
                    color = HealthFitColors.Accent,
                    fontSize = 26.sp,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    status,
                    color = statusColor,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier
                        .clip(RoundedCornerShape(20.dp))
                        .background(statusColor.copy(alpha = 0.16f))
                        .padding(horizontal = 8.dp, vertical = 3.dp),
                )
            }
        }
        Slider(
            value = hours,
            onValueChange = onHours,
            valueRange = 0f..12f,
            steps = 23,
            colors = SliderDefaults.colors(
                thumbColor = Color.White,
                activeTrackColor = HealthFitColors.Accent,
                inactiveTrackColor = Color(0xFF3A4550),
            ),
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SleepStat(Icons.Filled.Bed, clock(bed), "Horário de sono", Modifier.weight(1f))
            SleepStat(Icons.Filled.WbSunny, clock(wake), "Acordou às", Modifier.weight(1f))
            SleepStat(
                Icons.Filled.Watch,
                "${whole}h ${mins.toString().padStart(2, '0')}min",
                "Tempo total",
                Modifier.weight(1f),
            )
        }
        Spacer(Modifier.height(12.dp))
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(Color.White.copy(alpha = 0.06f))
                .padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Filled.CheckCircle, contentDescription = null, tint = HealthFitColors.Accent, modifier = Modifier.size(16.dp))
            Column(Modifier.weight(1f).padding(horizontal = 10.dp)) {
                Text("Monitoramento ativo", color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                Text("O Watch atualiza o card após a próxima noite.", color = Color(0xFFB7C0C8), fontSize = 12.sp)
            }
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .background(HealthFitColors.Accent)
                    .padding(horizontal = 8.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Filled.Watch, contentDescription = null, tint = Color.Black, modifier = Modifier.size(12.dp))
                Text(" Watch", color = Color.Black, fontSize = 11.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
    }
}

@Composable
private fun SleepStat(icon: ImageVector, value: String, label: String, modifier: Modifier) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White.copy(alpha = 0.06f))
            .padding(vertical = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(icon, contentDescription = null, tint = HealthFitColors.Accent, modifier = Modifier.size(16.dp))
        Text(value, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp, textAlign = TextAlign.Center)
        Text(label, color = Color(0xFF9AA3AB), fontSize = 10.sp, textAlign = TextAlign.Center)
    }
}

@Composable
fun WaterCard(
    ml: Int,
    goal: Int,
    onMinus: () -> Unit,
    onPlus: () -> Unit,
    onCup: () -> Unit,
    onBottle: () -> Unit,
) {
    val percent = (ml.toFloat() / goal).coerceIn(0f, 1f)
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(26.dp))
            .background(Color(0xFF10161C))
            .border(1.dp, Color.White.copy(alpha = 0.07f), RoundedCornerShape(26.dp)),
    ) {
        WaterRippleAtmosphere(Modifier.matchParentSize())
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(Color(0xFF4DA3FF).copy(alpha = 0.16f)),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Filled.WaterDrop, contentDescription = null, tint = Color(0xFF7EBEFF), modifier = Modifier.size(20.dp))
                }
                Column(Modifier.weight(1f).padding(start = 12.dp)) {
                    Text("Água de hoje", color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
                    Text("Meta ${formatMl(goal)} ml · 35 ml/kg", color = Color(0xFF8E989F), fontSize = 12.sp)
                }
            }
            Spacer(Modifier.height(14.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                CircleAction(Icons.Filled.Remove, onMinus, ml > 0)
                Text(
                    "${formatMl(ml)} ml",
                    color = Color.White,
                    fontWeight = FontWeight.Bold,
                    fontSize = 28.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.weight(1f),
                )
                CircleAction(Icons.Filled.Add, onPlus, true)
            }
            Spacer(Modifier.height(12.dp))
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(8.dp)
                    .clip(RoundedCornerShape(50))
                    .background(Color.White.copy(alpha = 0.10f)),
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(percent.coerceAtLeast(0.02f))
                        .height(8.dp)
                        .clip(RoundedCornerShape(50))
                        .background(
                            Brush.horizontalGradient(listOf(Color(0xFF2F7CFF), Color(0xFF7EBEFF))),
                        ),
                )
            }
            Spacer(Modifier.height(12.dp))
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                WaterQuick("+1 copo", onCup, Modifier.weight(1f))
                WaterQuick("+1 garrafa", onBottle, Modifier.weight(1f))
                WaterRing(percent)
            }
        }
    }
}

@Composable
private fun CircleAction(icon: ImageVector, onClick: () -> Unit, enabled: Boolean) {
    Box(
        modifier = Modifier
            .size(36.dp)
            .clip(CircleShape)
            .border(
                1.5.dp,
                if (enabled) HealthFitColors.Accent else Color.White.copy(alpha = 0.18f),
                CircleShape,
            )
            .clickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = if (enabled) HealthFitColors.Accent else Color.White.copy(alpha = 0.35f),
            modifier = Modifier.size(16.dp),
        )
    }
}

@Composable
private fun WaterRing(percent: Float) {
    Box(modifier = Modifier.size(58.dp), contentAlignment = Alignment.Center) {
        Canvas(Modifier.matchParentSize()) {
            drawArc(
                color = Color.White.copy(alpha = 0.12f),
                startAngle = 0f,
                sweepAngle = 360f,
                useCenter = false,
                style = Stroke(width = 5.dp.toPx(), cap = StrokeCap.Round),
            )
            drawArc(
                color = HealthFitColors.Accent,
                startAngle = -90f,
                sweepAngle = 360f * percent,
                useCenter = false,
                style = Stroke(width = 5.dp.toPx(), cap = StrokeCap.Round),
            )
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text("${(percent * 100).toInt()}%", color = HealthFitColors.Accent, fontWeight = FontWeight.Bold, fontSize = 12.sp)
            Text("da meta", color = Color(0xFFB7C0C8), fontSize = 9.sp)
        }
    }
}

@Composable
private fun WaterQuick(label: String, onClick: () -> Unit, modifier: Modifier) {
    Text(
        label,
        color = HealthFitColors.Accent,
        fontWeight = FontWeight.SemiBold,
        fontSize = 13.sp,
        textAlign = TextAlign.Center,
        modifier = modifier
            .clip(RoundedCornerShape(20.dp))
            .background(HealthFitColors.Accent.copy(alpha = 0.12f))
            .border(1.dp, HealthFitColors.Accent.copy(alpha = 0.55f), RoundedCornerShape(20.dp))
            .clickable(onClick = onClick)
            .padding(vertical = 11.dp),
    )
}

private fun greeting(name: String): String {
    val hour = java.time.LocalTime.now().hour
    val hello = when {
        hour < 12 -> "Bom dia"
        hour < 18 -> "Boa tarde"
        else -> "Boa noite"
    }
    return "$hello, $name!"
}

private fun clock(totalMinutes: Int): String {
    val day = 24 * 60
    val minutes = ((totalMinutes % day) + day) % day
    return "%02d:%02d".format(minutes / 60, minutes % 60)
}

private fun formatMl(value: Int): String =
    String.format(Locale("pt", "BR"), "%,d", value)
