package com.healthfit.android.ui.workouts

import androidx.activity.compose.BackHandler
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Timer
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.healthfit.android.ui.components.DarkCard
import com.healthfit.android.ui.components.GradientButton
import com.healthfit.android.ui.components.HeroCard
import com.healthfit.android.workout.WorkoutPresence
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

/**
 * Live strength session — iOS ActiveWorkoutView parity:
 * demo → Começar exercício (can pick any incomplete) → sets → rest →
 * Concluir Exercício / finish last set → choose next exercise → finish workout.
 */
@Composable
fun ActiveWorkoutScreen(
    sheet: WorkoutSheet,
    onClose: () -> Unit,
    onFinished: (elapsedSeconds: Int, completedExercises: Int) -> Unit = { _, _ -> onClose() },
) {
    BackHandler(onBack = onClose)
    val total = sheet.exercises.size
    var index by remember { mutableIntStateOf(0) }
    var showingDemo by remember { mutableStateOf(true) }
    var pickingNext by remember { mutableStateOf(false) }
    var setsDone by remember { mutableIntStateOf(0) }
    var elapsed by remember { mutableIntStateOf(0) }
    var resting by remember { mutableIntStateOf(0) }
    var completed by remember { mutableStateOf(setOf<Int>()) }

    val exercise = sheet.exercises.getOrNull(index) ?: sheet.exercises.first()
    val allDone = completed.size >= total

    LaunchedEffect(showingDemo, resting, pickingNext, allDone) {
        while (!showingDemo && resting == 0 && !pickingNext && !allDone) {
            delay(1000)
            elapsed += 1
        }
    }
    LaunchedEffect(resting) {
        while (resting > 0) {
            delay(1000)
            resting -= 1
        }
    }

    fun goToDemo(exerciseIndex: Int) {
        index = exerciseIndex
        setsDone = 0
        resting = 0
        showingDemo = true
        pickingNext = false
    }

    fun afterExerciseDone() {
        val nextCompleted = completed + index
        completed = nextCompleted
        resting = 0
        showingDemo = false
        val remaining = sheet.exercises.indices.filter { it !in nextCompleted }
        when {
            remaining.isEmpty() -> onFinished(elapsed, nextCompleted.size)
            remaining.size == 1 -> goToDemo(remaining.first())
            else -> pickingNext = true
        }
    }

    fun completeSet() {
        if (setsDone >= exercise.sets) return
        setsDone += 1
        if (setsDone >= exercise.sets) {
            afterExerciseDone()
        } else {
            resting = exercise.restSeconds
        }
    }

    WorkoutPresence(
        enabled = !showingDemo && !pickingNext,
        workoutTitle = sheet.title,
        exerciseName = when {
            pickingNext -> "Escolher exercício"
            resting > 0 -> "Descanso"
            else -> exercise.name
        },
        setsLabel = when {
            pickingNext -> "${completed.size}/$total feitos"
            resting > 0 -> "restante"
            else -> "${setsDone.coerceAtMost(exercise.sets)}/${exercise.sets}"
        },
        elapsedSeconds = elapsed,
        resting = resting > 0,
        paused = false,
        restRemainingSeconds = resting,
        kind = "strength",
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
    ) {
        ScreenTitle(sheet.title, onClose)
        LinearProgressIndicator(
            progress = { completed.size.toFloat() / total.coerceAtLeast(1) },
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp)
                .clip(RoundedCornerShape(99.dp)),
            color = HealthFitColors.Accent,
            trackColor = Color(0xFF2A3138),
        )
        Text(
            "${completed.size} de $total concluídos  ·  ${formatClock(elapsed)}",
            color = HealthFitColors.TextSecondary,
            fontSize = 12.sp,
            modifier = Modifier.padding(top = 8.dp, bottom = 12.dp),
        )

        when {
            pickingNext -> {
                NextExercisePicker(
                    sheet = sheet,
                    completed = completed,
                    suggestedIndex = sheet.exercises.indices.firstOrNull { it !in completed } ?: 0,
                    onPick = { goToDemo(it) },
                    onFinishWorkout = { onFinished(elapsed, completed.size) },
                )
            }
            resting > 0 -> {
                RestOverlay(
                    seconds = resting,
                    exerciseName = exercise.name,
                    onSkip = { resting = 0 },
                )
            }
            showingDemo -> {
                DemoGate(
                    exercise = exercise,
                    onStart = { showingDemo = false },
                )
            }
            else -> {
                ExecutionCard(
                    exercise = exercise,
                    setsDone = setsDone,
                    elapsed = elapsed,
                    onCompleteSet = { completeSet() },
                    onConcludeExercise = { afterExerciseDone() },
                )
            }
        }

        if (!pickingNext) {
            Spacer(Modifier.height(16.dp))
            ExerciseListSection(
                sheet = sheet,
                currentIndex = index,
                completed = completed,
                selectionEnabled = showingDemo && resting == 0,
                onSelect = { selected ->
                    if (showingDemo && selected !in completed) goToDemo(selected)
                },
            )
        }

        Spacer(Modifier.height(14.dp))
        Text(
            "Encerrar treino sem concluir",
            color = Color.White,
            fontWeight = FontWeight.SemiBold,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(Color(0xFFB3261E))
                .clickable(onClick = onClose)
                .padding(vertical = 14.dp),
        )
        Spacer(Modifier.height(20.dp))
    }
}

@Composable
private fun DemoGate(
    exercise: WorkoutExercise,
    onStart: () -> Unit,
) {
    Text("Assista a demonstração", color = HealthFitColors.TextSecondary, fontSize = 12.sp)
    Text(
        exercise.name,
        color = Color.White,
        fontSize = 26.sp,
        fontWeight = FontWeight.Bold,
        modifier = Modifier.padding(vertical = 6.dp),
    )
    ExerciseGifCard(exercise)
    Spacer(Modifier.height(12.dp))
    GradientButton("Começar exercício", onClick = onStart, icon = Icons.Filled.PlayArrow)
    Text(
        "A demonstração fica em loop. O cronômetro só começa quando você toca em Começar exercício.",
        color = HealthFitColors.TextSecondary,
        fontSize = 12.sp,
        modifier = Modifier.padding(top = 10.dp),
    )
    Text(
        "Toque em um exercício abaixo para treiná-lo agora (sem precisar seguir a ordem).",
        color = HealthFitColors.Accent.copy(alpha = 0.9f),
        fontSize = 12.sp,
        fontWeight = FontWeight.Medium,
        modifier = Modifier.padding(top = 8.dp),
    )
}

@Composable
private fun ExecutionCard(
    exercise: WorkoutExercise,
    setsDone: Int,
    elapsed: Int,
    onCompleteSet: () -> Unit,
    onConcludeExercise: () -> Unit,
) {
    val last = setsDone + 1 >= exercise.sets
    Text("Exercício atual", color = HealthFitColors.TextSecondary, fontSize = 12.sp)
    Text(
        exercise.name,
        color = Color.White,
        fontSize = 26.sp,
        fontWeight = FontWeight.Bold,
        modifier = Modifier.padding(vertical = 6.dp),
    )
    Text(
        formatClock(elapsed),
        color = HealthFitColors.Accent,
        fontSize = 32.sp,
        fontWeight = FontWeight.Bold,
    )
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
    Row(
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Box(Modifier.weight(1f)) {
            GradientButton(
                text = if (last) "Última série · Finalizar" else "Série Completa",
                onClick = onCompleteSet,
                icon = if (last) Icons.Filled.Flag else Icons.Filled.CheckCircle,
            )
        }
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier
                .clip(RoundedCornerShape(12.dp))
                .background(HealthFitColors.CardBackground)
                .clickable(onClick = onCompleteSet)
                .padding(horizontal = 14.dp, vertical = 10.dp),
        ) {
            Icon(Icons.Filled.Timer, contentDescription = null, tint = HealthFitColors.Accent)
            Text("Pausa", color = HealthFitColors.Accent, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
        }
    }
    Spacer(Modifier.height(10.dp))
    Text(
        "Concluir Exercício",
        color = HealthFitColors.Accent,
        fontWeight = FontWeight.SemiBold,
        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(HealthFitColors.Accent.copy(alpha = 0.15f))
            .clickable(onClick = onConcludeExercise)
            .padding(vertical = 14.dp),
    )
}

@Composable
private fun RestOverlay(
    seconds: Int,
    exerciseName: String,
    onSkip: () -> Unit,
) {
    DarkCard {
        Text("Pausa", color = HealthFitColors.AccentSecondary, fontWeight = FontWeight.Bold, fontSize = 13.sp)
        Text(exerciseName, color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 4.dp))
        Text(
            "${seconds}s",
            color = HealthFitColors.AccentSecondary,
            fontSize = 48.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(vertical = 12.dp),
        )
        if (seconds <= 0) {
            Text("Descanso encerrado!", color = HealthFitColors.Accent, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(8.dp))
            GradientButton("OK vamos lá", onClick = onSkip)
        } else {
            GradientButton("Pular Descanso", onClick = onSkip, icon = Icons.Filled.PlayArrow)
        }
    }
}

@Composable
private fun NextExercisePicker(
    sheet: WorkoutSheet,
    completed: Set<Int>,
    suggestedIndex: Int,
    onPick: (Int) -> Unit,
    onFinishWorkout: () -> Unit,
) {
    Text("Próximo exercício", color = Color.White, fontSize = 24.sp, fontWeight = FontWeight.Bold)
    Text(
        "Escolha qual exercício fazer agora. Você não precisa seguir a ordem da ficha.",
        color = HealthFitColors.TextSecondary,
        fontSize = 13.sp,
        modifier = Modifier.padding(top = 4.dp, bottom = 12.dp),
    )
    sheet.exercises.forEachIndexed { i, item ->
        if (i in completed) return@forEachIndexed
        val suggested = i == suggestedIndex
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 8.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(if (suggested) Color(0xFF243028) else HealthFitColors.CardBackground)
                .border(
                    width = if (suggested) 1.dp else 0.dp,
                    color = if (suggested) HealthFitColors.Accent else Color.Transparent,
                    shape = RoundedCornerShape(14.dp),
                )
                .clickable { onPick(i) }
                .padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                Modifier
                    .size(32.dp)
                    .clip(CircleShape)
                    .background(HealthFitColors.Accent.copy(alpha = 0.2f)),
                contentAlignment = Alignment.Center,
            ) {
                Text("${i + 1}", color = HealthFitColors.Accent, fontWeight = FontWeight.Bold)
            }
            Column(Modifier.weight(1f).padding(start = 12.dp)) {
                Text(item.name, color = Color.White, fontWeight = FontWeight.SemiBold)
                Text(
                    "${item.sets}x${item.reps}" + (item.weightKg?.let { " · ${it.toInt()} kg" } ?: ""),
                    color = HealthFitColors.TextSecondary,
                    fontSize = 12.sp,
                )
                if (suggested) {
                    Text("Sugerido (próximo da ficha)", color = HealthFitColors.Accent, fontSize = 11.sp)
                }
            }
            Text("Fazer", color = HealthFitColors.Accent, fontWeight = FontWeight.Bold)
        }
    }
    Spacer(Modifier.height(8.dp))
    Text(
        "Finalizar treino",
        color = Color.White,
        fontWeight = FontWeight.SemiBold,
        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color(0xFF3A1818))
            .clickable(onClick = onFinishWorkout)
            .padding(vertical = 14.dp),
    )
}

@Composable
private fun ExerciseListSection(
    sheet: WorkoutSheet,
    currentIndex: Int,
    completed: Set<Int>,
    selectionEnabled: Boolean,
    onSelect: (Int) -> Unit,
) {
    Text("Exercícios da ficha", color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
    Text(
        if (selectionEnabled) {
            "Toque em um exercício para treiná-lo agora (sem precisar seguir a ordem)."
        } else {
            "Finalize ou conclua o exercício atual para trocar. A troca só fica disponível na tela Começar exercício."
        },
        color = HealthFitColors.TextSecondary,
        fontSize = 12.sp,
        modifier = Modifier.padding(top = 4.dp, bottom = 8.dp),
    )
    sheet.exercises.forEachIndexed { i, item ->
        val done = i in completed
        val current = i == currentIndex && !done
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 8.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(
                    when {
                        done -> Color(0xFF1A2820)
                        current -> Color(0xFF243028)
                        else -> HealthFitColors.CardBackground
                    },
                )
                .then(
                    if (selectionEnabled && !done) Modifier.clickable { onSelect(i) }
                    else Modifier,
                )
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (done) {
                Icon(Icons.Filled.CheckCircle, null, tint = HealthFitColors.Accent, modifier = Modifier.size(22.dp))
            } else {
                Text(
                    "${i + 1}",
                    color = if (current) HealthFitColors.Accent else HealthFitColors.TextSecondary,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.size(22.dp),
                )
            }
            Column(Modifier.weight(1f).padding(start = 10.dp)) {
                Text(
                    item.name,
                    color = if (done) HealthFitColors.TextSecondary else Color.White,
                    fontWeight = FontWeight.Medium,
                )
                Text(
                    when {
                        done -> "Concluído"
                        current -> "Atual"
                        else -> "${item.sets}x${item.reps}"
                    },
                    color = HealthFitColors.TextSecondary,
                    fontSize = 12.sp,
                )
            }
        }
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
