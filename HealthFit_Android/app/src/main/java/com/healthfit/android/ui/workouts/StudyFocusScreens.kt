package com.healthfit.android.ui.workouts

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.healthfit.android.R
import com.healthfit.android.ui.assistant.AssistantNotifications
import com.healthfit.android.ui.components.GradientButton
import com.healthfit.android.ui.components.SessionClockDial
import com.healthfit.android.workout.PhoneWorkoutSync
import com.healthfit.android.workout.WearRemoteAction
import com.healthfit.android.workout.WorkoutPresence
import com.healthfit.core.workout.WorkoutWearContract
import com.healthfit.designsystem.HealthFitColors
import kotlinx.coroutines.delay

private val StudyAccent = Color(0xFF7B8CFF)

private val StudyDurationPresets = listOf(30, 60, 90, 120, 150, 180, 210)

private fun studyDurationLabel(minutes: Int): String {
    if (minutes < 60) return "$minutes min"
    val h = minutes / 60
    val rem = minutes % 60
    return when {
        rem == 0 && h == 1 -> "1 h"
        rem == 0 -> "$h h"
        h == 1 -> "1 h e $rem min"
        else -> "$h h e $rem min"
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun StudyFocusHubScreen(
    onBack: () -> Unit,
    onStart: (card: StudyFocusCard, minutes: Int) -> Unit,
) {
    BackHandler(onBack = onBack)
    val context = LocalContext.current
    var cards by remember { mutableStateOf(StudyFocusStore.loadCards(context)) }
    var selectedId by remember { mutableStateOf(cards.firstOrNull()?.id) }
    var minutes by remember { mutableIntStateOf(30) }
    var isCustomDuration by remember { mutableStateOf(false) }
    var showCustomDialog by remember { mutableStateOf(false) }
    var customDraft by remember { mutableStateOf("45") }
    var editing by remember { mutableStateOf<StudyFocusCard?>(null) }
    var creating by remember { mutableStateOf(false) }

    val selected = cards.firstOrNull { it.id == selectedId } ?: cards.firstOrNull()

    fun reload() {
        cards = StudyFocusStore.loadCards(context)
        if (cards.none { it.id == selectedId }) {
            selectedId = cards.firstOrNull()?.id
        }
    }

    if (creating || editing != null) {
        StudyFocusEditorDialog(
            initial = editing,
            onDismiss = { creating = false; editing = null },
            onSave = { card ->
                StudyFocusStore.upsert(context, card)
                selectedId = card.id
                creating = false
                editing = null
                reload()
            },
            onDelete = { id ->
                StudyFocusStore.delete(context, id)
                creating = false
                editing = null
                reload()
            },
        )
    }

    if (showCustomDialog) {
        AlertDialog(
            onDismissRequest = { showCustomDialog = false },
            title = { Text("Duração personalizada", color = Color.White) },
            text = {
                OutlinedTextField(
                    value = customDraft,
                    onValueChange = { customDraft = it.filter { ch -> ch.isDigit() }.take(3) },
                    label = { Text("Minutos (1–720)") },
                    singleLine = true,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedTextColor = Color.White,
                        unfocusedTextColor = Color.White,
                        focusedBorderColor = StudyAccent,
                        unfocusedBorderColor = HealthFitColors.TextSecondary.copy(alpha = 0.4f),
                        focusedLabelColor = StudyAccent,
                        unfocusedLabelColor = HealthFitColors.TextSecondary,
                        cursorColor = StudyAccent,
                    ),
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    val parsed = customDraft.toIntOrNull()?.coerceIn(1, 720) ?: minutes
                    minutes = parsed
                    isCustomDuration = true
                    showCustomDialog = false
                }) { Text("Usar", color = StudyAccent) }
            },
            dismissButton = {
                TextButton(onClick = { showCustomDialog = false }) { Text("Cancelar") }
            },
            containerColor = HealthFitColors.CardBackground,
        )
    }

    Column(
        Modifier
            .fillMaxSize()
            .background(HealthFitColors.Background)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp, bottom = 12.dp)) {
            Icon(
                Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = "Voltar",
                tint = Color.White,
                modifier = Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .clickable(onClick = onBack)
                    .padding(8.dp),
            )
            Text("Foco em Estudo", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 20.sp)
            Spacer(Modifier.weight(1f))
            Icon(
                Icons.Filled.Add,
                contentDescription = "Novo card",
                tint = HealthFitColors.Accent,
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .clickable { creating = true; editing = null }
                    .padding(6.dp),
            )
        }

        Box(
            Modifier
                .fillMaxWidth()
                .height(180.dp)
                .clip(RoundedCornerShape(18.dp)),
        ) {
            Image(
                painter = painterResource(R.drawable.studyfocuscover),
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
            )
            Box(
                Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            listOf(Color.Black.copy(alpha = 0.08f), Color.Black.copy(alpha = 0.78f)),
                        ),
                    ),
            )
            Column(
                Modifier
                    .align(Alignment.BottomStart)
                    .padding(16.dp),
            ) {
                Text("ESTUDO", color = StudyAccent, fontWeight = FontWeight.Bold, fontSize = 11.sp)
                Text("Foco em Estudo", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 22.sp)
                Text(
                    "Sessões longas com prioridades, tela acesa e lembretes do IAssistente.",
                    color = Color.White.copy(alpha = 0.85f),
                    fontSize = 12.sp,
                    modifier = Modifier.padding(top = 4.dp),
                )
                Text(
                    studyDurationLabel(minutes),
                    color = Color.White.copy(alpha = 0.9f),
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 11.sp,
                    modifier = Modifier.padding(top = 8.dp),
                )
            }
        }

        Spacer(Modifier.height(14.dp))
        Text(
            "Crie cards com o nome do que vai estudar, marque prioridades e receba lembretes durante a sessão.",
            color = HealthFitColors.TextSecondary,
            fontSize = 13.sp,
        )
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp)) {
            Icon(Icons.Filled.NotificationsActive, null, tint = StudyAccent, modifier = Modifier.size(16.dp))
            Text(
                "Tela acesa · notificações de prioridade",
                color = StudyAccent,
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(start = 6.dp),
            )
        }

        Spacer(Modifier.height(16.dp))
        Text("Duração do foco", color = Color.White, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.height(8.dp))
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            StudyDurationPresets.forEach { m ->
                val on = !isCustomDuration && minutes == m
                Text(
                    studyDurationLabel(m),
                    color = if (on) Color.Black else Color.White,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 13.sp,
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .background(if (on) StudyAccent else HealthFitColors.CardBackground)
                        .clickable {
                            minutes = m
                            isCustomDuration = false
                        }
                        .padding(horizontal = 14.dp, vertical = 12.dp),
                    textAlign = TextAlign.Center,
                )
            }
            val customOn = isCustomDuration
            Text(
                if (customOn) "Personalizado · ${studyDurationLabel(minutes)}" else "Personalizado",
                color = if (customOn) Color.Black else Color.White,
                fontWeight = FontWeight.SemiBold,
                fontSize = 13.sp,
                modifier = Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .background(if (customOn) StudyAccent else HealthFitColors.CardBackground)
                    .clickable {
                        customDraft = minutes.toString()
                        showCustomDialog = true
                    }
                    .padding(horizontal = 14.dp, vertical = 12.dp),
                textAlign = TextAlign.Center,
            )
        }

        Spacer(Modifier.height(16.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Seus cards", color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
            Text(
                "Novo",
                color = HealthFitColors.Accent,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.clickable { creating = true; editing = null },
            )
        }
        Spacer(Modifier.height(8.dp))

        cards.forEach { card ->
            val selectedCard = card.id == selected?.id
            Column(
                Modifier
                    .fillMaxWidth()
                    .padding(bottom = 10.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(HealthFitColors.CardBackground)
                    .border(
                        width = if (selectedCard) 2.dp else 0.dp,
                        color = if (selectedCard) StudyAccent else Color.Transparent,
                        shape = RoundedCornerShape(16.dp),
                    )
                    .clickable { selectedId = card.id }
                    .padding(14.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        Icons.Filled.MenuBook,
                        null,
                        tint = StudyAccent,
                        modifier = Modifier
                            .size(36.dp)
                            .clip(RoundedCornerShape(10.dp))
                            .background(StudyAccent.copy(alpha = 0.15f))
                            .padding(8.dp),
                    )
                    Text(
                        card.name,
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp,
                        modifier = Modifier.padding(start = 8.dp).weight(1f),
                    )
                    Icon(
                        Icons.Filled.Edit,
                        contentDescription = "Editar",
                        tint = HealthFitColors.TextSecondary,
                        modifier = Modifier
                            .size(28.dp)
                            .clickable { editing = card; creating = false }
                            .padding(4.dp),
                    )
                }
                if (card.note.isNotBlank()) {
                    Text(card.note, color = HealthFitColors.TextSecondary, fontSize = 12.sp, modifier = Modifier.padding(top = 6.dp))
                }
                Text(
                    prioritySummary(card),
                    color = StudyAccent,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.padding(top = 6.dp),
                )
            }
        }

        Spacer(Modifier.height(12.dp))
        if (selected != null) {
            GradientButton(
                text = "Iniciar foco em estudo",
                onClick = {
                    val card = selected
                    AssistantNotifications.show(
                        context,
                        9100,
                        "Foco em estudo",
                        card.priorities.firstOrNull()?.let {
                            "Prioridade agora: ${it.title}. Boa sessão de ${card.name}."
                        } ?: "Sessão \"${card.name}\" iniciada. Mantenha o foco.",
                    )
                    if (card.notifyPriorities) {
                        AssistantNotifications.scheduleStudyFocusReminders(context, card, minutes)
                    }
                    onStart(card, minutes)
                },
                icon = Icons.Filled.PlayArrow,
            )
        } else {
            Text(
                "Nenhum card ainda. Crie um com o nome que desejar.",
                color = HealthFitColors.TextSecondary,
                fontSize = 13.sp,
            )
        }
        Spacer(Modifier.height(28.dp))
    }
}

@Composable
fun StudyFocusLiveScreen(
    cardName: String,
    minutes: Int,
    priorities: List<StudyPriorityItem>,
    onClose: (elapsedSeconds: Int) -> Unit,
) {
    val context = LocalContext.current
    val targetSeconds = minutes.coerceAtLeast(1) * 60
    var elapsed by remember { mutableIntStateOf(0) }
    var paused by remember { mutableStateOf(false) }
    var closing by remember { mutableStateOf(false) }
    var lockEnabled by remember { mutableStateOf(true) }
    val remaining = (targetSeconds - elapsed).coerceAtLeast(0)
    val ordered = remember(priorities) {
        priorities.sortedBy {
            when (it.level) {
                StudyPriorityLevel.High -> 0
                StudyPriorityLevel.Medium -> 1
                StudyPriorityLevel.Low -> 2
            }
        }
    }

    fun finishSession(seconds: Int = elapsed) {
        if (closing) return
        closing = true
        paused = true
        lockEnabled = false
        runCatching { AssistantNotifications.cancelStudyFocusReminders(context) }
        onClose(seconds.coerceAtLeast(0))
    }

    LaunchedEffect(paused, closing) {
        if (closing) return@LaunchedEffect
        while (!paused) {
            delay(1000)
            if (closing) return@LaunchedEffect
            elapsed += 1
        }
    }
    LaunchedEffect(remaining, paused, closing) {
        if (closing) return@LaunchedEffect
        if (!paused && remaining == 0 && elapsed >= targetSeconds) {
            finishSession(elapsed.coerceAtMost(targetSeconds))
        }
    }
    LaunchedEffect(closing) {
        if (closing) return@LaunchedEffect
        PhoneWorkoutSync.remoteActions.collect { action ->
            if (closing) return@collect
            when (action) {
                WearRemoteAction.Pause -> paused = true
                WearRemoteAction.Resume -> paused = false
                WearRemoteAction.Stop -> finishSession()
            }
        }
    }
    BackHandler(enabled = !closing) { finishSession() }

    WorkoutPresence(
        workoutTitle = "Foco em Estudo",
        exerciseName = cardName,
        setsLabel = if (paused) "Pausado" else "estudo restante",
        elapsedSeconds = remaining,
        resting = remaining > 0 && !paused && !closing,
        paused = paused || closing,
        restRemainingSeconds = remaining,
        kind = WorkoutWearContract.KIND_MEDITATION,
        enabled = lockEnabled && !closing,
    )

    val progress = if (targetSeconds > 0) {
        1f - (remaining.toFloat() / targetSeconds.toFloat()).coerceIn(0f, 1f)
    } else {
        0f
    }
    // Header + relógio no centro + ações fixas embaixo (sem sobrepor a tab bar).
    Column(
        Modifier
            .fillMaxSize()
            .background(HealthFitColors.Background)
            .navigationBarsPadding()
            .padding(horizontal = 16.dp)
            .padding(top = 16.dp, bottom = 88.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("Foco em estudo", color = HealthFitColors.TextSecondary, fontSize = 13.sp)
        Text(
            cardName,
            color = Color.White,
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
            maxLines = 2,
            modifier = Modifier.padding(top = 4.dp),
        )
        Box(
            Modifier
                .weight(1f)
                .fillMaxWidth(),
            contentAlignment = Alignment.Center,
        ) {
            SessionClockDial(
                totalSeconds = remaining,
                caption = if (paused) "Pausado" else "restantes",
                accent = StudyAccent,
                progress = progress,
                paused = paused,
                size = 200.dp,
            )
        }
        if (ordered.isNotEmpty()) {
            Text(
                ordered.take(2).joinToString(" · ") { it.title },
                color = HealthFitColors.TextSecondary,
                fontSize = 12.sp,
                textAlign = TextAlign.Center,
                maxLines = 2,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 10.dp),
            )
        }
        GradientButton(
            text = if (paused) "Retomar" else "Pausar",
            onClick = { paused = !paused },
            icon = if (paused) Icons.Filled.PlayArrow else Icons.Filled.Pause,
        )
        Spacer(Modifier.height(10.dp))
        Text(
            "Finalizar foco",
            color = Color.White,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(Color(0xFF3A1818))
                .clickable(enabled = !closing) { finishSession() }
                .padding(vertical = 14.dp),
        )
    }
}

@Composable
private fun StudyFocusEditorDialog(
    initial: StudyFocusCard?,
    onDismiss: () -> Unit,
    onSave: (StudyFocusCard) -> Unit,
    onDelete: (String) -> Unit,
) {
    var name by remember { mutableStateOf(initial?.name.orEmpty()) }
    var note by remember { mutableStateOf(initial?.note.orEmpty()) }
    var notify by remember { mutableStateOf(initial?.notifyPriorities ?: true) }
    var priorities by remember { mutableStateOf(initial?.priorities.orEmpty()) }
    var draft by remember { mutableStateOf("") }
    var draftLevel by remember { mutableStateOf(StudyPriorityLevel.High) }
    var confirmDelete by remember { mutableStateOf(false) }

    val fieldColors = OutlinedTextFieldDefaults.colors(
        focusedTextColor = Color.White,
        unfocusedTextColor = Color.White,
        focusedBorderColor = HealthFitColors.Accent,
        unfocusedBorderColor = HealthFitColors.TextSecondary.copy(alpha = 0.4f),
        focusedLabelColor = HealthFitColors.Accent,
        unfocusedLabelColor = HealthFitColors.TextSecondary,
        cursorColor = HealthFitColors.Accent,
    )

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (initial == null) "Novo card" else "Editar card", color = Color.White) },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text("Nome do card") }, colors = fieldColors, singleLine = true)
                OutlinedTextField(value = note, onValueChange = { note = it }, label = { Text("Nota (opcional)") }, colors = fieldColors)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Notificar prioridades", color = Color.White, modifier = Modifier.weight(1f))
                    Switch(
                        checked = notify,
                        onCheckedChange = { notify = it },
                        colors = SwitchDefaults.colors(checkedTrackColor = HealthFitColors.Accent),
                    )
                }
                priorities.forEach { item ->
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("${item.level.label}: ${item.title}", color = Color.White, modifier = Modifier.weight(1f), fontSize = 13.sp)
                        Icon(
                            Icons.Filled.Delete,
                            null,
                            tint = Color(0xFFE85D4C),
                            modifier = Modifier
                                .size(22.dp)
                                .clickable { priorities = priorities.filterNot { it.id == item.id } },
                        )
                    }
                }
                OutlinedTextField(value = draft, onValueChange = { draft = it }, label = { Text("Nova prioridade") }, colors = fieldColors, singleLine = true)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    StudyPriorityLevel.entries.forEach { level ->
                        val on = draftLevel == level
                        Text(
                            level.label,
                            color = if (on) Color.Black else Color.White,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier
                                .clip(RoundedCornerShape(10.dp))
                                .background(if (on) HealthFitColors.Accent else HealthFitColors.CardBackground)
                                .clickable { draftLevel = level }
                                .padding(horizontal = 10.dp, vertical = 6.dp),
                        )
                    }
                }
                TextButton(onClick = {
                    val t = draft.trim()
                    if (t.isNotEmpty()) {
                        priorities = priorities + StudyPriorityItem(title = t, level = draftLevel)
                        draft = ""
                    }
                }) { Text("Adicionar prioridade", color = HealthFitColors.Accent) }
                if (initial != null) {
                    TextButton(onClick = { confirmDelete = true }) {
                        Text("Excluir card", color = Color(0xFFE85D4C))
                    }
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val trimmed = name.trim().ifEmpty { return@TextButton }
                    onSave(
                        (initial ?: StudyFocusCard(name = trimmed)).copy(
                            name = trimmed,
                            note = note.trim(),
                            priorities = priorities,
                            notifyPriorities = notify,
                        ),
                    )
                },
            ) { Text("Salvar", color = HealthFitColors.Accent) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancelar", color = HealthFitColors.TextSecondary) }
        },
        containerColor = HealthFitColors.CardBackground,
    )

    if (confirmDelete && initial != null) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("Excluir este card?") },
            confirmButton = {
                TextButton(onClick = { onDelete(initial.id) }) { Text("Excluir", color = Color(0xFFE85D4C)) }
            },
            dismissButton = {
                TextButton(onClick = { confirmDelete = false }) { Text("Cancelar") }
            },
        )
    }
}

private fun prioritySummary(card: StudyFocusCard): String {
    val count = card.priorities.size
    if (count == 0) return if (card.notifyPriorities) "Sem prioridades · avisos ativos" else "Sem prioridades"
    val high = card.priorities.count { it.level == StudyPriorityLevel.High }
    val parts = mutableListOf("$count prioridade${if (count == 1) "" else "s"}")
    if (high > 0) parts += "$high alta"
    if (card.notifyPriorities) parts += "notificações"
    return parts.joinToString(" · ")
}
