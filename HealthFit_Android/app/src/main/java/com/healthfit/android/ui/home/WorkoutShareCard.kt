package com.healthfit.android.ui.home

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.material3.Text
import com.healthfit.android.R
import com.healthfit.designsystem.HealthFitColors

data class FinishedExercise(
    val name: String,
    val sets: Int,
    val elapsed: String,
    val rest: String,
)

data class FinishedWorkout(
    val title: String,
    val cardDate: String,
    val whenLabel: String,
    val duration: String,
    val durationMinutes: String,
    val calories: Int?,
    val athlete: String = "Berg Limma",
    val motivation: String,
    val isCardio: Boolean,
    val coverRes: Int,
    val completed: Int,
    val total: Int,
    val exercises: List<FinishedExercise>,
    val recentMinutes: List<Int>,
    val exerciseSeconds: String = "58:12",
    val restSeconds: String = "26:36",
) {
    fun methodLabel(): String = when {
        title.contains("Cabo", ignoreCase = true) -> "Método Militar · Cabo"
        title.contains("Soldado", ignoreCase = true) -> "Método Militar · Soldado"
        title.contains("Nível 1") -> "Foco no Shape · Nível 1"
        title.contains("Nível 2") -> "Foco no Shape · Nível 2"
        isCardio -> "Cardio · $title"
        else -> "Musculação"
    }

    fun shareStats(): List<ShareStat> {
        val kcal = calories?.toString() ?: "—"
        val km = Regex("""(\d+[.,]\d+)\s*km""").find(whenLabel)?.groupValues?.get(1)
        val pace = Regex("""(\d+:\d+)\s*/km""").find(whenLabel)?.groupValues?.get(1)
        val kite = title.contains("Kite", ignoreCase = true)
        val surf = title.contains("Surf", ignoreCase = true) && !kite
        val bike = title.contains("bike", ignoreCase = true) || title.contains("Bicicleta", ignoreCase = true)
        val swim = title.contains("Nata", ignoreCase = true)
        val run = title.contains("Corrida") || title.contains("Caminhada") || title.contains("Remo")
        return when {
            kite -> listOf(
                ShareStat(km ?: "—", "Distância"),
                ShareStat(duration, "Duração"),
                ShareStat(kcal, "kcal"),
                ShareStat("—", "Vel. máx"),
            )
            surf -> listOf(
                ShareStat(km ?: "—", "Distância"),
                ShareStat(duration, "Duração"),
                ShareStat(kcal, "kcal"),
            )
            bike -> listOf(
                ShareStat(duration, "Duração"),
                ShareStat(kcal, "kcal"),
                ShareStat(km ?: "—", "km"),
                ShareStat("—", "km/h"),
            )
            swim -> listOf(
                ShareStat(duration, "Duração"),
                ShareStat(kcal, "kcal"),
                ShareStat("—", "/100m"),
            )
            run || (isCardio && km != null) -> listOf(
                ShareStat(duration, "Duração"),
                ShareStat(kcal, "kcal"),
                ShareStat(km ?: "—", "km"),
                ShareStat(pace ?: "—", "/km"),
            )
            title.contains("Luta") -> listOf(
                ShareStat(duration, "Duração"),
                ShareStat(kcal, "kcal"),
                ShareStat("Rounds", "Modo"),
            )
            title.contains("Medita", ignoreCase = true) -> listOf(
                ShareStat(duration, "Duração"),
                ShareStat("Foco", "Modo"),
            )
            isCardio -> listOf(
                ShareStat(duration, "Duração"),
                ShareStat(kcal, "kcal"),
            )
            else -> listOf(
                ShareStat(duration, "Duração"),
                ShareStat("$completed/$total", "Exercícios"),
                ShareStat(methodLabel().substringBefore(" · "), "Método"),
            )
        }
    }
}

data class ShareStat(val value: String, val label: String)

object DemoSessions {
    val strength = FinishedWorkout(
        title = "Militar Masculino E — Peito Ombros Tríceps (Cabo)",
        cardDate = "08 OUT. 2026 · 19:58",
        whenLabel = "8 de out. de 2026, 18:33",
        duration = "1:24:48",
        durationMinutes = "84 min",
        calories = null,
        motivation = "A disciplina de hoje é o progresso de amanhã.",
        isCardio = false,
        coverRes = R.drawable.workoutprogrammale,
        completed = 8,
        total = 8,
        exercises = listOf(
            FinishedExercise("Rotação Externa", 3, "08:40", "01:30"),
            FinishedExercise("Supino Inclinado", 4, "12:10", "01:30"),
            FinishedExercise("Crucifixo", 4, "09:20", "01:00"),
            FinishedExercise("Voador", 3, "07:50", "01:00"),
            FinishedExercise("Crossover", 4, "08:15", "01:00"),
            FinishedExercise("Desenvolvimento", 4, "11:57", "01:30"),
            FinishedExercise("Tríceps Pulley", 3, "07:20", "01:00"),
            FinishedExercise("Tríceps Testa", 3, "06:40", "01:00"),
        ),
        recentMinutes = listOf(42, 55, 38, 61, 48, 84),
    )

    val walkMorning = cardio("8 de out. de 2026, 7:05", "13 min", "0:13:12", 52, listOf(17, 13))
    val walkYesterday = cardio("7 de out. de 2026, 7:02", "17 min", "0:17:04", 102, listOf(13, 17))

    private fun cardio(
        whenLabel: String,
        minutes: String,
        duration: String,
        kcal: Int,
        recent: List<Int>,
    ) = FinishedWorkout(
        title = "Cardio — Caminhada livre",
        cardDate = whenLabel.uppercase(),
        whenLabel = whenLabel,
        duration = duration,
        durationMinutes = minutes,
        calories = kcal,
        motivation = "Cada passo te aproxima do objetivo.",
        isCardio = true,
        coverRes = R.drawable.cardiocovercaminhada,
        completed = 1,
        total = 1,
        exercises = emptyList(),
        recentMinutes = recent,
    )

    val all = listOf(strength, walkMorning, walkYesterday)
}

@Composable
fun WorkoutShareCard(session: FinishedWorkout, modifier: Modifier = Modifier) {
    val accent = if (session.isCardio) HealthFitColors.AccentSecondary else HealthFitColors.Accent
    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(28.dp))
            .background(
                Brush.linearGradient(
                    listOf(Color(0xFF080D0A), Color(0xFF0D1A14), Color(0xFF0A1210)),
                ),
            ),
    ) {
        Box(
            Modifier
                .size(220.dp)
                .offset(x = (-80).dp, y = (-90).dp)
                .background(Brush.radialGradient(listOf(accent.copy(alpha = 0.28f), Color.Transparent))),
        )
        Box(
            Modifier
                .size(180.dp)
                .align(Alignment.BottomEnd)
                .offset(x = 40.dp, y = 50.dp)
                .background(Brush.radialGradient(listOf(HealthFitColors.AccentSecondary.copy(alpha = 0.22f), Color.Transparent))),
        )
        Column(
            modifier = Modifier.padding(horizontal = 18.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                Image(
                    painter = painterResource(R.drawable.brandheart),
                    contentDescription = null,
                    modifier = Modifier.size(18.dp),
                )
                Text(
                    "HealthFit",
                    color = Color.White,
                    fontWeight = FontWeight.ExtraBold,
                    fontSize = 15.sp,
                    modifier = Modifier.padding(start = 8.dp),
                )
                Spacer(Modifier.weight(1f))
                Text(session.cardDate, color = Color.White.copy(alpha = 0.55f), fontSize = 9.sp, fontWeight = FontWeight.SemiBold)
            }
            Spacer(Modifier.height(10.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(contentAlignment = Alignment.Center, modifier = Modifier.size(58.dp)) {
                    Box(
                        Modifier
                            .size(58.dp)
                            .border(
                                2.5.dp,
                                Brush.sweepGradient(listOf(accent, HealthFitColors.AccentSecondary, accent)),
                                CircleShape,
                            ),
                    )
                    Icon(
                        if (session.isCardio) Icons.Filled.DirectionsWalk else Icons.Filled.FitnessCenter,
                        contentDescription = null,
                        tint = accent,
                        modifier = Modifier.size(22.dp),
                    )
                }
                Image(
                    painter = painterResource(session.coverRes),
                    contentDescription = session.athlete,
                    modifier = Modifier
                        .offset(x = (-8).dp)
                        .size(48.dp)
                        .clip(CircleShape)
                        .border(2.dp, accent, CircleShape),
                    contentScale = ContentScale.Crop,
                )
            }
            Text(
                headline(session),
                color = Color.White,
                fontSize = 22.sp,
                fontWeight = FontWeight.ExtraBold,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 8.dp),
            )
            Text(
                session.motivation,
                color = Color.White.copy(alpha = 0.9f),
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 4.dp),
            )
            Text(
                session.methodLabel(),
                color = HealthFitColors.Accent,
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 0.4.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 6.dp),
            )
            Text(
                session.title,
                color = HealthFitColors.Accent,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 4.dp),
            )
            Column(
                modifier = Modifier
                    .padding(top = 10.dp)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(Color.White.copy(alpha = 0.06f))
                    .border(1.dp, Color.White.copy(alpha = 0.08f), RoundedCornerShape(14.dp))
                    .padding(horizontal = 10.dp, vertical = 9.dp),
            ) {
                if (session.isCardio) {
                    Text("PERFORMANCE", color = Color.White.copy(alpha = 0.45f), fontSize = 8.sp, fontWeight = FontWeight.Bold)
                    PerformanceBar("TEMPO", session.duration, 0.45f, HealthFitColors.Accent)
                    session.calories?.let { PerformanceBar("KCAL", "$it", (it / 180f).coerceIn(0.2f, 1f), HealthFitColors.AccentSecondary) }
                } else {
                    Text("SÉRIES POR EXERCÍCIO", color = Color.White.copy(alpha = 0.45f), fontSize = 8.sp, fontWeight = FontWeight.Bold)
                    val shown = session.exercises.take(6)
                    val maxSets = shown.maxOf { it.sets }.coerceAtLeast(1)
                    Row(
                        modifier = Modifier.fillMaxWidth().height(72.dp).padding(top = 6.dp),
                        verticalAlignment = Alignment.Bottom,
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        shown.forEach { exercise ->
                            Column(
                                modifier = Modifier.weight(1f),
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.Bottom,
                            ) {
                                Box(
                                    Modifier
                                        .fillMaxWidth()
                                        .height((42f * exercise.sets / maxSets).dp.coerceAtLeast(6.dp))
                                        .clip(RoundedCornerShape(3.dp))
                                        .background(
                                            Brush.verticalGradient(
                                                listOf(HealthFitColors.AccentSecondary, HealthFitColors.Accent),
                                            ),
                                        ),
                                )
                                Text(
                                    shortLabel(exercise.name),
                                    color = Color.White.copy(alpha = 0.55f),
                                    fontSize = 7.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    maxLines = 1,
                                    overflow = TextOverflow.Clip,
                                    modifier = Modifier.padding(top = 4.dp),
                                )
                            }
                        }
                    }
                }
                if (session.recentMinutes.size >= 2) {
                    Text(
                        "ÚLTIMOS TREINOS",
                        color = Color.White.copy(alpha = 0.45f),
                        fontSize = 8.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(top = 8.dp),
                    )
                    val max = session.recentMinutes.max().coerceAtLeast(1)
                    Row(
                        modifier = Modifier.fillMaxWidth().height(20.dp).padding(top = 4.dp),
                        verticalAlignment = Alignment.Bottom,
                        horizontalArrangement = Arrangement.spacedBy(3.dp),
                    ) {
                        session.recentMinutes.forEachIndexed { index, minutes ->
                            val current = index == session.recentMinutes.lastIndex
                            Box(
                                Modifier
                                    .weight(1f)
                                    .height((20f * minutes / max).dp.coerceAtLeast(4.dp))
                                    .clip(RoundedCornerShape(2.dp))
                                    .background(
                                        if (current) HealthFitColors.AccentSecondary else HealthFitColors.Accent.copy(alpha = 0.55f),
                                    ),
                            )
                        }
                    }
                }
            }
            Row(modifier = Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                ShareStat(session.duration, "DURAÇÃO", Modifier.weight(1f))
                if (session.isCardio) {
                    session.calories?.let { ShareStat("$it", "KCAL", Modifier.weight(1f)) }
                } else {
                    ShareStat("${session.completed}/${session.total}", "EXERCÍCIOS", Modifier.weight(1f))
                }
            }
            Column(
                modifier = Modifier
                    .padding(top = 8.dp)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(Color.White.copy(alpha = 0.05f))
                    .padding(vertical = 9.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text("Treinei com HealthFit", color = Color.White.copy(alpha = 0.9f), fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
                Text("Disciplina · Evolução · Constância", color = Color.White.copy(alpha = 0.45f), fontSize = 10.sp)
            }
        }
    }
}

@Composable
private fun PerformanceBar(label: String, value: String, ratio: Float, color: Color) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 5.dp)) {
        Text(label, color = Color.White.copy(alpha = 0.55f), fontSize = 8.sp, fontWeight = FontWeight.Bold, modifier = Modifier.width(42.dp))
        Box(
            Modifier
                .weight(1f)
                .height(7.dp)
                .clip(RoundedCornerShape(99.dp))
                .background(Color.White.copy(alpha = 0.08f)),
        ) {
            Box(
                Modifier
                    .fillMaxWidth(ratio)
                    .height(7.dp)
                    .clip(RoundedCornerShape(99.dp))
                    .background(color),
            )
        }
        Text(value, color = Color.White.copy(alpha = 0.75f), fontSize = 8.sp, fontWeight = FontWeight.Bold, modifier = Modifier.width(52.dp), textAlign = TextAlign.End)
    }
}

@Composable
private fun ShareStat(value: String, label: String, modifier: Modifier) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White.copy(alpha = 0.07f))
            .border(1.dp, Color.White.copy(alpha = 0.08f), RoundedCornerShape(12.dp))
            .padding(vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(value, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 13.sp)
        Text(label, color = Color.White.copy(alpha = 0.5f), fontSize = 7.sp, fontWeight = FontWeight.Bold)
    }
}

private fun headline(session: FinishedWorkout): String =
    if (session.isCardio) "${session.athlete} elevou o ritmo" else "${session.athlete} concluiu o treino"

private fun shortLabel(name: String): String {
    val trimmed = name.trim()
    return if (trimmed.length > 7) trimmed.take(6).uppercase() + "…" else trimmed.uppercase()
}
