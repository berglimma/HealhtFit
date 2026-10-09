package com.healthfit.android.ui.workouts

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.healthfit.android.ui.components.DarkCard
import com.healthfit.android.ui.components.GradientButton
import com.healthfit.android.workout.WorkoutPresence
import com.healthfit.android.ui.components.HeroCard
import androidx.compose.ui.graphics.Brush
import com.healthfit.designsystem.HealthFitColors
import kotlinx.coroutines.delay

@Composable
fun WorkoutProgramScreen(
    title: String,
    subtitle: String,
    sheets: List<WorkoutSheet>,
    imageRes: Int,
    onBack: () -> Unit,
    onOpen: (Int) -> Unit,
) {
    BackHandler(onBack = onBack)
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
    ) {
        ScreenTitle(title, onBack)
        Text(subtitle, color = HealthFitColors.TextSecondary, fontSize = 13.sp)
        Spacer(Modifier.height(14.dp))
        Text("Recomendados", color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
        Text(
            "${sheets.size} fichas · demos em GIF",
            color = HealthFitColors.TextSecondary,
            fontSize = 12.sp,
            modifier = Modifier.padding(top = 2.dp, bottom = 10.dp),
        )
        sheets.forEachIndexed { index, sheet ->
            HeroCard(
                title = sheet.title,
                subtitle = sheet.description,
                brush = Brush.linearGradient(listOf(Color(0xFF102018), Color(0xFF1A2830))),
                imageRes = imageRes,
                height = 150.dp,
                footer = {
                    Text(
                        "${sheet.exercises.size} exercícios · ~${sheet.minutes} min",
                        color = Color.White,
                        fontSize = 12.sp,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                },
                onClick = { onOpen(index) },
            )
            Spacer(Modifier.height(10.dp))
        }
    }
}

@Composable
fun WorkoutDetailScreen(
    sheet: WorkoutSheet,
    onBack: () -> Unit,
    onStart: () -> Unit,
) {
    BackHandler(onBack = onBack)
    var selected by remember(sheet.title) { mutableIntStateOf(0) }
    val exercise = sheet.exercises[selected]
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
    ) {
        ScreenTitle(sheet.title, onBack)
        Text(sheet.description, color = HealthFitColors.TextSecondary, fontSize = 13.sp)
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
            StatPill("${sheet.exercises.size}", "Exercícios", Modifier.weight(1f))
            StatPill("~${sheet.minutes}", "Minutos", Modifier.weight(1f))
            StatPill("${sheet.exercises.sumOf { it.sets }}", "Séries", Modifier.weight(1f))
        }
        Spacer(Modifier.height(14.dp))
        ExerciseGifCard(exercise)
        Spacer(Modifier.height(16.dp))
        Text("Exercícios", color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
        Spacer(Modifier.height(8.dp))
        sheet.exercises.forEachIndexed { index, item ->
            val active = index == selected
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 8.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(if (active) Color(0xFF243028) else HealthFitColors.CardBackground)
                    .clickable { selected = index }
                    .padding(12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "${index + 1}",
                    color = HealthFitColors.Accent,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(end = 10.dp),
                )
                Column(Modifier.weight(1f)) {
                    Text(item.name, color = Color.White, fontWeight = FontWeight.Medium)
                    val load = item.weightKg?.let { " · ${it.toInt()} kg" } ?: ""
                    Text(
                        "${item.sets}x${item.reps}$load · ${item.restSeconds}s",
                        color = HealthFitColors.TextSecondary,
                        fontSize = 12.sp,
                    )
                }
            }
        }
        GradientButton("Iniciar Treino", onClick = onStart, icon = Icons.Filled.PlayArrow)
        Spacer(Modifier.height(18.dp))
    }
}

@Composable
fun ActiveWorkoutScreen(
    sheet: WorkoutSheet,
    onClose: () -> Unit,
) {
    BackHandler(onBack = onClose)
    var index by remember { mutableIntStateOf(0) }
    var showingDemo by remember { mutableStateOf(true) }
    var setsDone by remember { mutableIntStateOf(0) }
    var elapsed by remember { mutableIntStateOf(0) }
    var resting by remember { mutableIntStateOf(0) }
    val exercise = sheet.exercises[index]
    val finished = index >= sheet.exercises.lastIndex && setsDone >= exercise.sets && !showingDemo && resting == 0

    LaunchedEffect(showingDemo, resting, finished) {
        while (!showingDemo && resting == 0 && !finished) {
            delay(1000)
            elapsed += 1
        }
    }
    LaunchedEffect(resting) {
        if (resting > 0) {
            while (resting > 0) {
                delay(1000)
                resting -= 1
            }
        }
    }
    WorkoutPresence(
        enabled = !showingDemo,
        workoutTitle = sheet.title,
        exerciseName = exercise.name,
        setsLabel = "${setsDone.coerceAtMost(exercise.sets)}/${exercise.sets}",
        elapsedSeconds = elapsed,
        resting = resting > 0,
        restRemainingSeconds = resting,
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
    ) {
        ScreenTitle(sheet.title, onClose)
        LinearProgressIndicator(
            progress = { index.toFloat() / sheet.exercises.size.coerceAtLeast(1) },
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp)
                .clip(RoundedCornerShape(99.dp)),
            color = HealthFitColors.Accent,
            trackColor = Color(0xFF2A3138),
        )
        Text(
            "${index + 1} de ${sheet.exercises.size}  ·  ${formatClock(elapsed)}",
            color = HealthFitColors.TextSecondary,
            fontSize = 12.sp,
            modifier = Modifier.padding(top = 8.dp, bottom = 12.dp),
        )

        if (showingDemo) {
            Text("Assista a demonstração", color = HealthFitColors.TextSecondary, fontSize = 12.sp)
            Text(exercise.name, color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(vertical = 6.dp))
            ExerciseGifCard(exercise)
            Spacer(Modifier.height(12.dp))
            GradientButton("Começar exercício", onClick = { showingDemo = false }, icon = Icons.Filled.PlayArrow)
            Text(
                "A demonstração fica em loop. O cronômetro só começa quando você toca em Começar exercício.",
                color = HealthFitColors.TextSecondary,
                fontSize = 12.sp,
                modifier = Modifier.padding(top = 10.dp),
            )
        } else {
            Text("Exercício atual", color = HealthFitColors.TextSecondary, fontSize = 12.sp)
            Text(exercise.name, color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(vertical = 6.dp))
            Text(
                formatClock(elapsed),
                color = if (resting > 0) HealthFitColors.AccentSecondary else HealthFitColors.Accent,
                fontSize = 32.sp,
                fontWeight = FontWeight.Bold,
            )
            if (resting > 0) {
                Text("Descanso ${resting}s", color = HealthFitColors.AccentSecondary, fontWeight = FontWeight.SemiBold)
            }
            Spacer(Modifier.height(8.dp))
            ExerciseGifCard(exercise)
            Spacer(Modifier.height(12.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                Metric("${setsDone}/${exercise.sets}", if (setsDone >= exercise.sets) "Séries concluídas" else "Série ${setsDone + 1}")
                Metric("${exercise.sets}", "Total")
                Metric("${exercise.reps}", "Reps")
                exercise.weightKg?.let { Metric("${it.toInt()} kg", "Carga") }
            }
            Spacer(Modifier.height(14.dp))
            val last = setsDone + 1 >= exercise.sets
            GradientButton(
                text = if (last) "Última série · Finalizar" else "Série completa",
                onClick = {
                    if (setsDone < exercise.sets) {
                        setsDone += 1
                        if (setsDone >= exercise.sets) {
                            if (index < sheet.exercises.lastIndex) {
                                index += 1
                                setsDone = 0
                                showingDemo = true
                                resting = 0
                            }
                        } else {
                            resting = exercise.restSeconds
                        }
                    }
                },
            )
        }
        Spacer(Modifier.height(20.dp))
    }
}

@Composable
private fun ScreenTitle(title: String, onBack: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp, bottom = 8.dp),
    ) {
        Icon(
            Icons.AutoMirrored.Filled.ArrowBack,
            contentDescription = "Voltar",
            tint = Color.White,
            modifier = Modifier
                .clip(RoundedCornerShape(12.dp))
                .clickable(onClick = onBack)
                .padding(8.dp),
        )
        Text(title, color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(start = 4.dp))
    }
}

@Composable
private fun StatPill(value: String, label: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .background(HealthFitColors.CardBackground)
            .padding(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Text(value, color = Color.White, fontWeight = FontWeight.Bold)
        Text(label, color = HealthFitColors.TextSecondary, fontSize = 11.sp)
    }
}

@Composable
private fun Metric(value: String, label: String) {
    Column {
        Text(value, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Text(label, color = HealthFitColors.TextSecondary, fontSize = 11.sp)
    }
}

private fun formatClock(seconds: Int): String {
    val m = seconds / 60
    val s = seconds % 60
    return "%d:%02d".format(m, s)
}
