package com.healthfit.android.ui.nutrition

import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.Assignment
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Restaurant
import androidx.compose.material.icons.filled.SentimentSatisfied
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material.icons.filled.WaterDrop
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.google.firebase.auth.FirebaseAuth
import com.healthfit.android.ui.components.DarkCard
import com.healthfit.android.ui.components.GradientButton
import com.healthfit.core.coach.CoachCloudGates
import com.healthfit.core.coach.CoachCloudRepository
import com.healthfit.designsystem.HealthFitColors
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.roundToInt
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private val NutriAccent = Color(0xFF8A5A2A)

@Composable
fun NutritionCareTab(
    reloadToken: Int = 0,
    onOpenAnamnesis: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val uid = remember {
        runCatching { FirebaseAuth.getInstance().currentUser?.uid }.getOrNull().orEmpty()
    }

    LaunchedEffect(uid) {
        if (uid.isNotBlank()) CoachCloudRepository.start(uid)
    }
    val cloud by CoachCloudRepository.state.collectAsState()
    val hasNutritionist = cloud.activeNutrition != null

    var refresh by remember { mutableIntStateOf(0) }
    val bundle = remember(reloadToken, refresh) { NutritionCareStore.loadBundle(context) }

    var selectedKind by remember { mutableStateOf<NutritionQuestionnaireKind?>(null) }
    var showNewGoal by remember { mutableStateOf(false) }
    var showCheckIn by remember { mutableStateOf(false) }
    var isSyncing by remember { mutableStateOf(false) }
    var statusMessage by remember { mutableStateOf<String?>(null) }

    selectedKind?.let { kind ->
        Dialog(
            onDismissRequest = {
                selectedKind = null
                refresh += 1
            },
            properties = DialogProperties(
                usePlatformDefaultWidth = false,
                decorFitsSystemWindows = false,
            ),
        ) {
            NutritionQuestionnaireEditorScreen(
                kind = kind,
                onBack = {
                    selectedKind = null
                    refresh += 1
                },
            )
        }
    }

    Text("Acompanhamento", color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold)
    Text(
        if (hasNutritionist) {
            "Questionários, anamnese e metas sincronizam com seu nutricionista."
        } else {
            "Preencha questionários e metas. Ao vincular um nutricionista, você pode sincronizar."
        },
        color = HealthFitColors.TextSecondary,
        fontSize = 13.sp,
        modifier = Modifier.padding(top = 4.dp, bottom = 10.dp),
    )

    GradientButton(
        text = if (isSyncing) "Sincronizando…" else "Sincronizar com nutricionista",
        onClick = {
            if (isSyncing) return@GradientButton
            scope.launch {
                isSyncing = true
                delay(450)
                NutritionCareStore.markGoalsSynced(context)
                statusMessage = when {
                    !hasNutritionist ->
                        "Vincule um nutricionista no HealthFit Coach para sincronizar."
                    CoachCloudGates.WRITES_HARD_DISABLED || !cloud.writeEnabled ->
                        "Dados prontos localmente. Envio ao nutri na nuvem em breve."
                    else -> "Enviado ao nutricionista."
                }
                isSyncing = false
                refresh += 1
                Toast.makeText(context, statusMessage, Toast.LENGTH_SHORT).show()
            }
        },
        icon = Icons.Filled.Sync,
        modifier = Modifier.padding(bottom = 14.dp),
    )

    DarkCard(onClick = onOpenAnamnesis, modifier = Modifier.padding(bottom = 12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                Icons.Filled.Assignment,
                null,
                tint = HealthFitColors.Accent,
                modifier = Modifier
                    .size(36.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(HealthFitColors.Accent.copy(alpha = 0.15f))
                    .padding(8.dp),
            )
            Column(Modifier.weight(1f).padding(start = 12.dp)) {
                Text("Anamnese completa", color = Color.White, fontWeight = FontWeight.SemiBold)
                Text(
                    "${bundle.anamnesis.completionPercent}% preenchida",
                    color = HealthFitColors.TextSecondary,
                    fontSize = 12.sp,
                )
            }
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = HealthFitColors.TextSecondary)
        }
    }

    Text(
        "Questionários de saúde",
        color = Color.White,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier.padding(bottom = 10.dp),
    )
    // Ordem explícita igual ao iOS (6 cards).
    val questionnaireKinds = listOf(
        NutritionQuestionnaireKind.HealthGeneral,
        NutritionQuestionnaireKind.MetabolicTracking,
        NutritionQuestionnaireKind.EatingPattern,
        NutritionQuestionnaireKind.SleepType,
        NutritionQuestionnaireKind.HydrationHabits,
        NutritionQuestionnaireKind.EmotionalEating,
    )
    questionnaireKinds.forEach { kind ->
        val response = bundle.questionnaires.firstOrNull { it.kindId == kind.id }
            ?: NutritionQuestionnaireResponse(kindId = kind.id)
        val answered = response.answeredCount(kind)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 8.dp)
                .clip(RoundedCornerShape(18.dp))
                .background(HealthFitColors.CardBackground)
                .clickable(role = Role.Button) { selectedKind = kind }
                .padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                questionnaireIcon(kind),
                contentDescription = kind.title,
                tint = HealthFitColors.AccentSecondary,
                modifier = Modifier.size(28.dp),
            )
            Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
                Text(kind.title, color = Color.White, fontWeight = FontWeight.SemiBold)
                Text(kind.detail, color = HealthFitColors.TextSecondary, fontSize = 11.sp, maxLines = 2)
            }
            Text(
                if (response.isComplete(kind)) "OK" else "$answered/${kind.questions.size}",
                color = if (response.isComplete(kind)) HealthFitColors.Accent else HealthFitColors.TextSecondary,
                fontWeight = FontWeight.Bold,
                fontSize = 12.sp,
            )
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = HealthFitColors.TextSecondary,
                modifier = Modifier.padding(start = 4.dp),
            )
        }
    }

    Spacer(Modifier.height(8.dp))
    Row(
        Modifier.fillMaxWidth().padding(bottom = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text("Metas e objetivos", color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
        Icon(
            Icons.Filled.AddCircle,
            contentDescription = "Nova meta",
            tint = HealthFitColors.Accent,
            modifier = Modifier
                .size(28.dp)
                .clickable { showNewGoal = true },
        )
    }
    if (bundle.goals.isEmpty()) {
        DarkCard(modifier = Modifier.padding(bottom = 8.dp)) {
            Text(
                "Crie metas (ex.: reduzir açúcar, beber 3 L de água). Com nutricionista, sincronize para acompanhamento.",
                color = HealthFitColors.TextSecondary,
                fontSize = 12.sp,
            )
        }
    } else {
        bundle.goals.forEach { goal ->
            DarkCard(modifier = Modifier.padding(bottom = 8.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(goal.title, color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                    Text(goal.status.title, color = HealthFitColors.Accent, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                }
                if (goal.detail.isNotBlank()) {
                    Text(goal.detail, color = HealthFitColors.TextSecondary, fontSize = 12.sp)
                }
                Row(
                    Modifier.padding(top = 6.dp),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        if (goal.authorIsCoach) "Prescrita pelo nutri" else "Sua meta",
                        color = HealthFitColors.TextSecondary,
                        fontSize = 11.sp,
                    )
                    if (goal.syncedWithCoach) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Filled.CheckCircle, null, tint = HealthFitColors.Accent, modifier = Modifier.size(12.dp))
                            Text(" Sincronizada", color = HealthFitColors.Accent, fontSize = 11.sp)
                        }
                    }
                }
                Row(Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(
                        "Concluir",
                        color = HealthFitColors.Accent,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.clickable {
                            NutritionCareStore.updateGoal(context, goal.copy(status = NutritionGoalStatus.Completed))
                            refresh += 1
                        },
                    )
                    Text(
                        "Pausar",
                        color = HealthFitColors.TextSecondary,
                        fontSize = 12.sp,
                        modifier = Modifier.clickable {
                            NutritionCareStore.updateGoal(context, goal.copy(status = NutritionGoalStatus.Paused))
                            refresh += 1
                        },
                    )
                    Text(
                        "Excluir",
                        color = Color(0xFFFF6B6B),
                        fontSize = 12.sp,
                        modifier = Modifier.clickable {
                            NutritionCareStore.deleteGoal(context, goal.id)
                            refresh += 1
                        },
                    )
                }
            }
        }
    }

    Spacer(Modifier.height(8.dp))
    Row(
        Modifier.fillMaxWidth().padding(bottom = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text("Check-in nutricional", color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
        Text(
            "Registrar",
            color = HealthFitColors.Accent,
            fontWeight = FontWeight.SemiBold,
            fontSize = 12.sp,
            modifier = Modifier.clickable { showCheckIn = true },
        )
    }
    bundle.checkIns.take(5).forEach { item ->
        val dateLabel = SimpleDateFormat("dd MMM yyyy", Locale("pt", "BR")).format(Date(item.dateMillis))
        DarkCard(modifier = Modifier.padding(bottom = 8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(dateLabel, color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
                    Text(
                        "Adesão ${item.adherence}/5 · Fome ${item.hunger}/5 · Energia ${item.energy}/5",
                        color = HealthFitColors.TextSecondary,
                        fontSize = 11.sp,
                    )
                }
                item.weightKg?.let {
                    Text("%.1f kg".format(it), color = HealthFitColors.Accent, fontSize = 12.sp)
                }
            }
        }
    }

    statusMessage?.let {
        Text(it, color = HealthFitColors.Accent, fontSize = 12.sp, modifier = Modifier.padding(top = 8.dp))
    }

    cloud.activeNutrition?.let {
        Spacer(Modifier.height(12.dp))
        Column(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(HealthFitColors.CardBackground)
                .border(1.dp, NutriAccent.copy(alpha = 0.35f), RoundedCornerShape(12.dp))
                .padding(14.dp),
        ) {
            Text("Foto da refeição para o nutricionista", color = Color.White, fontWeight = FontWeight.SemiBold)
            Text(
                "Fluxo: você envia → nutri vê só hoje → ao abrir, a foto é apagada.",
                color = HealthFitColors.TextSecondary,
                fontSize = 12.sp,
                modifier = Modifier.padding(top = 4.dp, bottom = 8.dp),
            )
            listOf(
                "1. Escolha ou tire a foto da refeição",
                "2. Envie com o nome da refeição",
                "3. Nutricionista abre uma vez na Revisão IAssistente",
                "4. Foto apagada após visualização",
            ).forEach { step ->
                Text(step, color = HealthFitColors.TextSecondary, fontSize = 12.sp, modifier = Modifier.padding(bottom = 2.dp))
            }
            Spacer(Modifier.height(10.dp))
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(NutriAccent)
                    .clickable {
                        Toast.makeText(
                            context,
                            "Envio de foto ao nutri em breve (paridade iOS).",
                            Toast.LENGTH_SHORT,
                        ).show()
                    }
                    .padding(vertical = 12.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Filled.CameraAlt, null, tint = Color.White, modifier = Modifier.size(18.dp))
                Text(
                    "  Enviar foto da refeição (só hoje)",
                    color = Color.White,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 14.sp,
                )
            }
        }
    }

    if (showNewGoal) {
        GoalEditorDialog(
            onDismiss = { showNewGoal = false },
            onSave = { title, detail ->
                NutritionCareStore.addGoal(
                    context,
                    NutritionGoal(title = title, detail = detail),
                )
                showNewGoal = false
                refresh += 1
            },
        )
    }
    if (showCheckIn) {
        CheckInDialog(
            onDismiss = { showCheckIn = false },
            onSave = { weight, adherence, hunger, energy, notes ->
                NutritionCareStore.addCheckIn(
                    context,
                    NutritionCheckIn(
                        weightKg = weight,
                        adherence = adherence,
                        hunger = hunger,
                        energy = energy,
                        notes = notes,
                    ),
                )
                showCheckIn = false
                refresh += 1
            },
        )
    }
}

private fun questionnaireIcon(kind: NutritionQuestionnaireKind): ImageVector = when (kind) {
    NutritionQuestionnaireKind.HealthGeneral -> Icons.Filled.Favorite
    NutritionQuestionnaireKind.MetabolicTracking -> Icons.Filled.LocalFireDepartment
    NutritionQuestionnaireKind.EatingPattern -> Icons.Filled.Restaurant
    NutritionQuestionnaireKind.SleepType -> Icons.Filled.Bedtime
    NutritionQuestionnaireKind.HydrationHabits -> Icons.Filled.WaterDrop
    NutritionQuestionnaireKind.EmotionalEating -> Icons.Filled.SentimentSatisfied
}

@Composable
private fun GoalEditorDialog(onDismiss: () -> Unit, onSave: (String, String) -> Unit) {
    var title by remember { mutableStateOf("") }
    var detail by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Nova meta") },
        text = {
            Column {
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it },
                    label = { Text("Título") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
                )
                OutlinedTextField(
                    value = detail,
                    onValueChange = { detail = it },
                    label = { Text("Detalhes") },
                    minLines = 2,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = { onSave(title.trim(), detail.trim()) },
                enabled = title.trim().isNotEmpty(),
            ) { Text("Salvar") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancelar") } },
    )
}

@Composable
private fun CheckInDialog(
    onDismiss: () -> Unit,
    onSave: (Double?, Int, Int, Int, String) -> Unit,
) {
    var weightText by remember { mutableStateOf("") }
    var adherence by remember { mutableFloatStateOf(3f) }
    var hunger by remember { mutableFloatStateOf(3f) }
    var energy by remember { mutableFloatStateOf(3f) }
    var notes by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Check-in nutricional") },
        text = {
            Column {
                OutlinedTextField(
                    value = weightText,
                    onValueChange = { weightText = it },
                    label = { Text("Peso (kg, opcional)") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
                )
                Text("Adesão: ${adherence.roundToInt()}/5", fontSize = 13.sp)
                Slider(value = adherence, onValueChange = { adherence = it }, valueRange = 1f..5f, steps = 3)
                Text("Fome: ${hunger.roundToInt()}/5", fontSize = 13.sp)
                Slider(value = hunger, onValueChange = { hunger = it }, valueRange = 1f..5f, steps = 3)
                Text("Energia: ${energy.roundToInt()}/5", fontSize = 13.sp)
                Slider(value = energy, onValueChange = { energy = it }, valueRange = 1f..5f, steps = 3)
                OutlinedTextField(
                    value = notes,
                    onValueChange = { notes = it },
                    label = { Text("Notas") },
                    minLines = 2,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val w = weightText.replace(',', '.').toDoubleOrNull()
                    onSave(w, adherence.roundToInt(), hunger.roundToInt(), energy.roundToInt(), notes.trim())
                },
            ) { Text("Salvar") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancelar") } },
    )
}

@Composable
fun NutritionQuestionnaireEditorScreen(
    kind: NutritionQuestionnaireKind,
    onBack: () -> Unit,
) {
    BackHandler(onBack = onBack)
    val context = LocalContext.current
    val existing = remember(kind) { NutritionCareStore.responseFor(context, kind) }
    var answers by remember(kind) {
        mutableStateOf(kind.questions.associate { (id, _) -> id to existing.answers[id].orEmpty() })
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
            Text(kind.title, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
        }
        Text(kind.detail, color = HealthFitColors.TextSecondary, fontSize = 13.sp, modifier = Modifier.padding(bottom = 12.dp))
        kind.questions.forEach { (qid, prompt) ->
            Text(prompt, color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, modifier = Modifier.padding(bottom = 6.dp))
            Field("Resposta", answers[qid].orEmpty()) { answers = answers + (qid to it) }
        }
        Spacer(Modifier.height(12.dp))
        GradientButton(
            text = "Salvar",
            onClick = {
                NutritionCareStore.upsertQuestionnaire(
                    context,
                    NutritionQuestionnaireResponse(kindId = kind.id, answers = answers),
                )
                Toast.makeText(context, "Questionário salvo", Toast.LENGTH_SHORT).show()
                onBack()
            },
        )
        Spacer(Modifier.height(28.dp))
    }
}

@Composable
fun NutritionAnamnesisEditorScreen(
    isCoachMode: Boolean,
    onBack: () -> Unit,
) {
    BackHandler(onBack = onBack)
    val context = LocalContext.current
    var draft by remember { mutableStateOf(NutritionCareStore.loadAnamnesis(context)) }

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
            Text(
                if (isCoachMode) "Anamnese do aluno" else "Anamnese",
                color = Color.White,
                fontWeight = FontWeight.Bold,
                fontSize = 18.sp,
            )
        }

        Text(
            "${draft.completionPercent}% preenchida",
            color = HealthFitColors.Accent,
            fontWeight = FontWeight.SemiBold,
            fontSize = 13.sp,
            modifier = Modifier.padding(bottom = 12.dp),
        )

        SectionLabel("Queixa e histórico")
        Field("Queixa principal", draft.chiefComplaint) { draft = draft.copy(chiefComplaint = it) }
        Field("Histórico médico", draft.medicalHistory) { draft = draft.copy(medicalHistory = it) }
        Field("Medicamentos", draft.medications) { draft = draft.copy(medications = it) }
        Field("Alergias", draft.allergies) { draft = draft.copy(allergies = it) }
        Field("Cirurgias", draft.surgeries) { draft = draft.copy(surgeries = it) }
        Field("Histórico familiar", draft.familyHistory) { draft = draft.copy(familyHistory = it) }

        SectionLabel("Digestão e hábitos")
        Field("Questões digestivas", draft.digestiveIssues) { draft = draft.copy(digestiveIssues = it) }
        Field("Função intestinal", draft.bowelFunction) { draft = draft.copy(bowelFunction = it) }
        SliderField(
            label = "Água: ${"%.2f".format(draft.waterIntakeLiters)} L/dia",
            value = draft.waterIntakeLiters.toFloat(),
            range = 0.5f..6f,
            steps = 21,
        ) { draft = draft.copy(waterIntakeLiters = (it * 4).roundToInt() / 4.0) }
        Field("Álcool", draft.alcoholUse) { draft = draft.copy(alcoholUse = it) }
        Field("Tabagismo", draft.smoking) { draft = draft.copy(smoking = it) }
        Field("Atividade física", draft.physicalActivity) { draft = draft.copy(physicalActivity = it) }

        SectionLabel("Sono, estresse e ciclo")
        SliderField(
            label = "Sono: ${"%.1f".format(draft.sleepHours)} h",
            value = draft.sleepHours.toFloat(),
            range = 3f..12f,
            steps = 17,
        ) { draft = draft.copy(sleepHours = (it * 2).roundToInt() / 2.0) }
        SliderField(
            label = "Estresse: ${draft.stressLevel}/10",
            value = draft.stressLevel.toFloat(),
            range = 1f..10f,
            steps = 8,
        ) { draft = draft.copy(stressLevel = it.roundToInt()) }
        Field("Notas menstruais / hormonais", draft.menstrualNotes) { draft = draft.copy(menstrualNotes = it) }

        SectionLabel("Alimentação")
        Field("Aversões alimentares", draft.foodAversions) { draft = draft.copy(foodAversions = it) }
        Field("Frequência de comer fora", draft.eatingOutFrequency) { draft = draft.copy(eatingOutFrequency = it) }
        Field("Suplementos em uso", draft.supplementsInUse) { draft = draft.copy(supplementsInUse = it) }
        Field("Dietas anteriores", draft.previousDiets) { draft = draft.copy(previousDiets = it) }
        Field("Observações", draft.notes) { draft = draft.copy(notes = it) }

        Spacer(Modifier.height(16.dp))
        GradientButton(
            text = "Salvar",
            onClick = {
                NutritionCareStore.saveAnamnesis(context, draft)
                Toast.makeText(context, "Anamnese salva", Toast.LENGTH_SHORT).show()
                onBack()
            },
        )
        Spacer(Modifier.height(28.dp))
    }
}

@Composable
private fun SectionLabel(text: String) {
    Text(
        text,
        color = Color.White,
        fontWeight = FontWeight.Bold,
        fontSize = 15.sp,
        modifier = Modifier.padding(top = 14.dp, bottom = 8.dp),
    )
}

@Composable
private fun Field(label: String, value: String, onChange: (String) -> Unit) {
    OutlinedTextField(
        value = value,
        onValueChange = onChange,
        label = { Text(label) },
        minLines = 2,
        maxLines = 5,
        colors = OutlinedTextFieldDefaults.colors(
            focusedTextColor = Color.White,
            unfocusedTextColor = Color.White,
            focusedBorderColor = HealthFitColors.Accent,
            unfocusedBorderColor = Color(0xFF3A4148),
            focusedLabelColor = HealthFitColors.Accent,
            unfocusedLabelColor = HealthFitColors.TextSecondary,
        ),
        modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
    )
}

@Composable
private fun SliderField(
    label: String,
    value: Float,
    range: ClosedFloatingPointRange<Float>,
    steps: Int,
    onChange: (Float) -> Unit,
) {
    Column(Modifier.padding(bottom = 10.dp)) {
        Text(label, color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
        Slider(
            value = value,
            onValueChange = onChange,
            valueRange = range,
            steps = steps,
            colors = SliderDefaults.colors(
                thumbColor = HealthFitColors.Accent,
                activeTrackColor = HealthFitColors.Accent,
            ),
        )
    }
}
