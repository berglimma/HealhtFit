package com.healthfit.android.ui.home

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.healthfit.android.R
import com.healthfit.android.ui.profile.ProfileLinkedProsStore
import com.healthfit.android.ui.workouts.Muscle
import com.healthfit.android.ui.workouts.WorkoutSheet
import com.healthfit.designsystem.HealthFitColors

@Composable
fun WorkoutOfTheDayCard(
    female: Boolean = false,
    onOpenSheet: (WorkoutSheet) -> Unit = {},
    onChooseProgram: (femaleProgram: Boolean) -> Unit = {},
    onOpenCardio: () -> Unit = {},
) {
    val context = LocalContext.current
    var showPreview by remember { mutableStateOf(false) }
    var showGenderPicker by remember { mutableStateOf(false) }
    val linkedPros = remember { ProfileLinkedProsStore.load(context) }
    val hasPersonal = linkedPros.hasTrainer
    val personalName = linkedPros.trainerName.trim().takeIf { it.isNotEmpty() }
    val restWeekdays = linkedPros.restWeekdays
    val suggestion = remember(female, hasPersonal, personalName, restWeekdays) {
        WorkoutDaySuggestionAnalyzer.suggestWorkoutOfTheDay(
            sessions = ConstancyStore.loadSessions(context),
            female = female,
            hasPersonalTrainer = hasPersonal,
            personalName = personalName,
            coachRestWeekdays = restWeekdays,
        )
    }
    val coverRes = if (female) R.drawable.workoutprogramfemale else R.drawable.workoutprogrammale

    if (showGenderPicker) {
        AlertDialog(
            onDismissRequest = { showGenderPicker = false },
            title = { Text("Escolher programa de musculação") },
            text = {
                Text(
                    "Abrimos o programa do seu perfil por padrão. Você pode trocar quando quiser.",
                    color = Color(0xFFB7C0C8),
                    fontSize = 13.sp,
                )
            },
            confirmButton = {
                Column {
                    TextButton(
                        onClick = {
                            showGenderPicker = false
                            onChooseProgram(false)
                        },
                    ) {
                        Text(if (!female) "Masculino (seu perfil)" else "Masculino")
                    }
                    TextButton(
                        onClick = {
                            showGenderPicker = false
                            onChooseProgram(true)
                        },
                    ) {
                        Text(if (female) "Feminino (seu perfil)" else "Feminino")
                    }
                }
            },
            dismissButton = {
                TextButton(onClick = { showGenderPicker = false }) { Text("Cancelar") }
            },
        )
    }

    if (suggestion == null) {
        EmptyWorkoutOfTheDayCard(
            coverRes = coverRes,
            onChoose = { showGenderPicker = true },
            onOpenCardio = onOpenCardio,
        )
        return
    }

    if (showPreview && suggestion.sheet != null) {
        val sheet = suggestion.sheet
        AlertDialog(
            onDismissRequest = { showPreview = false },
            title = { Text(sheet.title) },
            text = {
                Column {
                    Text(suggestion.reason, color = Color(0xFFB7C0C8), fontSize = 13.sp)
                    Spacer(Modifier.height(10.dp))
                    sheet.exercises.take(8).forEach { ex ->
                        Text(
                            "• ${ex.name} · ${ex.sets}x${ex.reps}",
                            color = Color.White,
                            fontSize = 13.sp,
                        )
                    }
                    if (sheet.exercises.size > 8) {
                        Text(
                            "… e mais ${sheet.exercises.size - 8}",
                            color = Color(0xFF8E989F),
                            fontSize = 12.sp,
                        )
                    }
                }
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        showPreview = false
                        onOpenSheet(sheet)
                    },
                ) { Text("Abrir ficha") }
            },
            dismissButton = {
                TextButton(onClick = { showPreview = false }) { Text("Fechar") }
            },
        )
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(HealthFitColors.CardBackground)
            .border(
                width = 1.dp,
                brush = Brush.linearGradient(
                    listOf(Color.White.copy(alpha = 0.12f), HealthFitColors.Accent.copy(alpha = 0.35f)),
                ),
                shape = RoundedCornerShape(20.dp),
            ),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(168.dp),
        ) {
            Image(
                painter = painterResource(coverRes),
                contentDescription = null,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )
            Box(
                Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            listOf(Color.Transparent, Color.Black.copy(alpha = 0.78f)),
                        ),
                    ),
            )
            Column(
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(16.dp),
            ) {
                Text(
                    when (suggestion.source) {
                        WorkoutSuggestionSource.CoachRest -> "DESCANSO · PERSONAL"
                        WorkoutSuggestionSource.RoutineRest -> "DESCANSO · RECUPERAÇÃO"
                        WorkoutSuggestionSource.CoachRoutine -> "TREINO DO DIA · PERSONAL"
                        WorkoutSuggestionSource.UserHistory -> "TREINO DO DIA"
                    },
                    color = HealthFitColors.Accent,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 0.8.sp,
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    suggestion.title,
                    color = Color.White,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    suggestionLabel(suggestion),
                    color = Color.White.copy(alpha = 0.9f),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 2,
                )
            }
        }

        Column(Modifier.padding(16.dp)) {
            Text(suggestion.reason, color = Color(0xFFB7C0C8), fontSize = 13.sp, lineHeight = 18.sp)

            if (suggestion.isRestDay) {
                Spacer(Modifier.height(14.dp))
                Text(
                    "Treinar mesmo assim",
                    color = HealthFitColors.Accent,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(HealthFitColors.Accent.copy(alpha = 0.16f))
                        .clickable { showGenderPicker = true }
                        .padding(vertical = 12.dp),
                )
                Spacer(Modifier.height(10.dp))
                Text(
                    "Cardio leve / caminhada",
                    color = Color(0xFF4DD0E1),
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(Color(0xFF4DD0E1).copy(alpha = 0.16f))
                        .clickable(onClick = onOpenCardio)
                        .padding(vertical = 12.dp),
                )
            } else {
                val sheet = suggestion.sheet
                if (suggestion.focusMuscles.isNotEmpty()) {
                    Spacer(Modifier.height(12.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        suggestion.focusMuscles.forEach { muscle ->
                            MuscleChip(muscle)
                        }
                    }
                }

                if (sheet != null) {
                    Spacer(Modifier.height(14.dp))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.FitnessCenter, contentDescription = null, tint = Color(0xFF8E989F), modifier = Modifier.size(14.dp))
                        Spacer(Modifier.width(4.dp))
                        Text(
                            "${sheet.exercises.size} exercícios",
                            color = Color(0xFF8E989F),
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium,
                        )
                        Spacer(Modifier.width(12.dp))
                        Icon(Icons.Filled.Schedule, contentDescription = null, tint = Color(0xFF8E989F), modifier = Modifier.size(14.dp))
                        Spacer(Modifier.width(4.dp))
                        Text(
                            "~${sheet.minutes} min",
                            color = Color(0xFF8E989F),
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium,
                        )
                    }
                }

                Spacer(Modifier.height(14.dp))
                Row(
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(
                        "Abrir sugestão",
                        color = Color.White,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center,
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(12.dp))
                            .background(HealthFitColors.Accent)
                            .clickable { showPreview = true }
                            .padding(vertical = 12.dp),
                    )
                    Text(
                        "Escolher treino",
                        color = HealthFitColors.Accent,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center,
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(12.dp))
                            .background(HealthFitColors.Accent.copy(alpha = 0.16f))
                            .clickable { showGenderPicker = true }
                            .padding(vertical = 12.dp),
                    )
                }
                Spacer(Modifier.height(10.dp))
                Text(
                    "Realizar cardio",
                    color = Color(0xFF4DD0E1),
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(Color(0xFF4DD0E1).copy(alpha = 0.16f))
                        .clickable(onClick = onOpenCardio)
                        .padding(vertical = 12.dp),
                )
            }
        }
    }
}

private fun suggestionLabel(suggestion: WorkoutOfTheDaySuggestion): String {
    val focus = suggestion.focusMuscles
    return when (suggestion.source) {
        WorkoutSuggestionSource.CoachRest -> "Rotina do personal · dia livre"
        WorkoutSuggestionSource.RoutineRest -> "Sugestão de recuperação"
        WorkoutSuggestionSource.CoachRoutine -> {
            if (focus.isEmpty()) "Rotina do personal"
            else {
                val names = focus.joinToString(" · ") { WorkoutDaySuggestionAnalyzer.muscleLabel(it) }
                "Rotina do personal · $names"
            }
        }
        WorkoutSuggestionSource.UserHistory -> {
            if (focus.isEmpty()) "Sugestão com base no seu histórico"
            else {
                val names = focus.joinToString(" · ") { WorkoutDaySuggestionAnalyzer.muscleLabel(it) }
                "Sugestão · foco em $names"
            }
        }
    }
}

@Composable
private fun MuscleChip(muscle: Muscle) {
    Text(
        WorkoutDaySuggestionAnalyzer.muscleLabel(muscle),
        color = HealthFitColors.Accent,
        fontSize = 12.sp,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(HealthFitColors.Accent.copy(alpha = 0.14f))
            .padding(horizontal = 10.dp, vertical = 6.dp),
    )
}

@Composable
private fun EmptyWorkoutOfTheDayCard(
    coverRes: Int,
    onChoose: () -> Unit,
    onOpenCardio: () -> Unit = {},
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(HealthFitColors.CardBackground),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(140.dp),
        ) {
            Image(
                painter = painterResource(coverRes),
                contentDescription = null,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )
            Box(
                Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            listOf(Color.Transparent, Color.Black.copy(alpha = 0.75f)),
                        ),
                    ),
            )
            Column(
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(16.dp),
            ) {
                Text("TREINO DO DIA", color = HealthFitColors.Accent, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(4.dp))
                Text("Sem fichas disponíveis", color = Color.White, fontSize = 17.sp, fontWeight = FontWeight.Bold)
            }
        }
        Column(Modifier.padding(16.dp)) {
            Text(
                "Abra um programa em Treinos para receber a sugestão do dia.",
                color = Color(0xFFB7C0C8),
                fontSize = 13.sp,
            )
            Spacer(Modifier.height(12.dp))
            Text(
                "Escolher treino",
                color = Color.White,
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(HealthFitColors.Accent)
                    .clickable(onClick = onChoose)
                    .padding(vertical = 12.dp),
            )
            Spacer(Modifier.height(10.dp))
            Text(
                "Realizar cardio",
                color = Color(0xFF4DD0E1),
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(Color(0xFF4DD0E1).copy(alpha = 0.16f))
                    .clickable(onClick = onOpenCardio)
                    .padding(vertical = 12.dp),
            )
        }
    }
}
