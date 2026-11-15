package com.healthfit.android.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.healthfit.designsystem.HealthFitColors

@Composable
fun MuscleGroupStatsCard() {
    val context = LocalContext.current
    var periodWeek by remember { mutableStateOf(true) }
    val sessions = remember { ConstancyStore.loadSessions(context) }
    val report = remember(periodWeek, sessions) {
        WorkoutDaySuggestionAnalyzer.report(
            sessions = sessions,
            days = if (periodWeek) 7 else 30,
            periodLabel = if (periodWeek) "Últimos 7 dias" else "Últimos 30 dias",
        )
    }
    val maxHits = remember(report) { maxOf(report.stats.maxOfOrNull { it.sessionHits } ?: 1, 1) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(HealthFitColors.CardBackground)
            .padding(16.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = Modifier.weight(1f)) {
                Text("Grupos musculares", color = Color.White, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                Text(report.periodLabel, color = Color(0xFF8E989F), fontSize = 12.sp)
            }
            PeriodToggle(periodWeek = periodWeek, onChange = { periodWeek = it })
        }

        Spacer(Modifier.height(10.dp))
        Text(
            "${report.totalStrengthSessions} treinos de musculação no período",
            color = Color(0xFF8E989F),
            fontSize = 12.sp,
            fontWeight = FontWeight.Medium,
        )
        Spacer(Modifier.height(12.dp))

        report.stats.forEach { stat ->
            MuscleStatRow(stat = stat, maxHits = maxHits)
            Spacer(Modifier.height(10.dp))
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(Color(0xFF4DD0E1).copy(alpha = 0.08f))
                .padding(12.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Cardio", color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.weight(1f))
                Text(
                    "${report.totalCardioSessions}× no período",
                    color = Color(0xFF4DD0E1),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                )
            }
            Spacer(Modifier.height(8.dp))
            if (report.cardioByType.isEmpty()) {
                Text(
                    "Nenhum cardio registrado neste período.",
                    color = Color(0xFF8E989F),
                    fontSize = 12.sp,
                )
            } else {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    report.cardioByType.forEach { item ->
                        Text(
                            "${item.name} · ${item.count}×",
                            color = Color(0xFF4DD0E1),
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier
                                .clip(RoundedCornerShape(50))
                                .background(Color(0xFF4DD0E1).copy(alpha = 0.14f))
                                .padding(horizontal = 10.dp, vertical = 6.dp),
                        )
                    }
                }
            }
        }
        Spacer(Modifier.height(12.dp))

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(Color(0xFFFF9A3C).copy(alpha = 0.08f))
                .padding(12.dp),
        ) {
            Text("Sugestões para melhorar", color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.height(8.dp))
            report.suggestions.forEach { tip ->
                Row(verticalAlignment = Alignment.Top) {
                    Icon(
                        Icons.Filled.Lightbulb,
                        contentDescription = null,
                        tint = Color(0xFFFF9A3C),
                        modifier = Modifier.padding(top = 2.dp),
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(tip, color = Color(0xFFB7C0C8), fontSize = 13.sp, lineHeight = 18.sp)
                }
                Spacer(Modifier.height(8.dp))
            }
        }
    }
}

@Composable
private fun PeriodToggle(periodWeek: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(10.dp))
            .background(Color.White.copy(alpha = 0.06f))
            .padding(3.dp),
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        PeriodChip("Semana", selected = periodWeek) { onChange(true) }
        PeriodChip("Mês", selected = !periodWeek) { onChange(false) }
    }
}

@Composable
private fun PeriodChip(label: String, selected: Boolean, onClick: () -> Unit) {
    Text(
        label,
        color = if (selected) Color.White else Color(0xFF8E989F),
        fontSize = 12.sp,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .background(if (selected) HealthFitColors.Accent.copy(alpha = 0.35f) else Color.Transparent)
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 6.dp),
    )
}

@Composable
private fun MuscleStatRow(stat: MuscleGroupStat, maxHits: Int) {
    Column {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                WorkoutDaySuggestionAnalyzer.muscleLabel(stat.group),
                color = Color.White,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.weight(1f),
            )
            Text(
                "${stat.sessionHits}×",
                color = HealthFitColors.Accent,
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
            )
            Spacer(Modifier.width(6.dp))
            Text("· ${stat.exerciseHits} ex.", color = Color(0xFF8E989F), fontSize = 11.sp)
        }
        Spacer(Modifier.height(6.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(8.dp)
                .clip(RoundedCornerShape(50))
                .background(Color.White.copy(alpha = 0.08f)),
        ) {
            val fraction = (stat.sessionHits.toFloat() / maxHits.toFloat()).coerceIn(0f, 1f)
            Box(
                modifier = Modifier
                    .fillMaxHeight()
                    .fillMaxWidth(fraction)
                    .clip(RoundedCornerShape(50))
                    .background(
                        Brush.horizontalGradient(
                            listOf(HealthFitColors.Accent, Color.Cyan.copy(alpha = 0.85f)),
                        ),
                    ),
            )
        }
    }
}
