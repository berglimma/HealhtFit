package com.healthfit.android.ui.nutrition

import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.material.icons.filled.Assignment
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.healthfit.android.ui.components.DarkCard
import com.healthfit.android.ui.components.GradientButton
import com.healthfit.designsystem.HealthFitColors
import kotlin.math.roundToInt

@Composable
fun NutritionCareTab(onOpenAnamnesis: () -> Unit) {
    val context = LocalContext.current
    val anamnesis = NutritionCareStore.loadAnamnesis(context)

    Text("Acompanhamento", color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold)
    Text(
        "Questionários, anamnese e metas. Ao vincular um nutricionista no HealthFit Coach, você pode sincronizar.",
        color = HealthFitColors.TextSecondary,
        fontSize = 13.sp,
        modifier = Modifier.padding(top = 4.dp, bottom = 14.dp),
    )

    DarkCard(onClick = onOpenAnamnesis) {
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
                    "${anamnesis.completionPercent}% preenchida",
                    color = HealthFitColors.TextSecondary,
                    fontSize = 12.sp,
                )
            }
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = HealthFitColors.TextSecondary)
        }
    }

    Spacer(Modifier.height(12.dp))
    Text("Questionários de saúde", color = Color.White, fontWeight = FontWeight.SemiBold)
    Text(
        "Em breve: saúde, metabólico, padrão alimentar, sono, hidratação e fome emocional — igual ao iOS.",
        color = HealthFitColors.TextSecondary,
        fontSize = 12.sp,
        modifier = Modifier.padding(top = 4.dp, bottom = 8.dp),
    )
    listOf(
        "Questionário de saúde" to "Histórico clínico, sintomas e medicamentos.",
        "Rastreamento metabólico" to "Energia, fome, retenção e sinais metabólicos.",
        "Padrão alimentar" to "Horários, porções e frequência de refeições.",
    ).forEach { (title, detail) ->
        DarkCard(modifier = Modifier.padding(bottom = 8.dp)) {
            Text(title, color = Color.White, fontWeight = FontWeight.SemiBold)
            Text(detail, color = HealthFitColors.TextSecondary, fontSize = 12.sp)
        }
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
