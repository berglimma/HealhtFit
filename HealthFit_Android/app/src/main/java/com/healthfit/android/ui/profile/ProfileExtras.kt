package com.healthfit.android.ui.profile

import androidx.compose.foundation.Image
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.healthfit.android.R
import com.healthfit.android.ui.components.DarkCard
import com.healthfit.designsystem.HealthFitColors

private val FieldColors
    @Composable get() = OutlinedTextFieldDefaults.colors(
        focusedTextColor = Color.White,
        unfocusedTextColor = Color.White,
        focusedBorderColor = HealthFitColors.Accent,
        unfocusedBorderColor = Color(0xFF3A4148),
        cursorColor = HealthFitColors.Accent,
        focusedLabelColor = HealthFitColors.Accent,
        unfocusedLabelColor = Color(0xFF8E989F),
    )

@Composable
fun NicknameSection(name: String, onName: (String) -> Unit) {
    Text("Como você gostaria de ser chamado?", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
    OutlinedTextField(
        value = name,
        onValueChange = onName,
        label = { Text("Seu apelido ou primeiro nome") },
        colors = FieldColors,
        modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
    )
    Text(
        "Usado nas saudações, motivação e mensagens do app.",
        color = Color(0xFF8E989F),
        fontSize = 12.sp,
        modifier = Modifier.padding(top = 4.dp, bottom = 12.dp),
    )
}

@Composable
fun PlanRow(plan: String, onClick: () -> Unit) {
    DarkCard(onClick = onClick) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text("Assinatura", color = Color(0xFF8E989F), fontSize = 12.sp)
                Text("Meu plano", color = Color.White, fontWeight = FontWeight.SemiBold)
                Text(plan, color = HealthFitColors.Accent, fontSize = 13.sp)
            }
            Icon(Icons.Filled.ChevronRight, contentDescription = null, tint = Color(0xFF8E989F))
        }
    }
}

@Composable
fun LinkedProSection(
    title: String,
    question: String,
    enabled: Boolean,
    onEnabled: (Boolean) -> Unit,
    name: String,
    onName: (String) -> Unit,
    email: String,
    onEmail: (String) -> Unit,
    hint: String,
) {
    Text(title, color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 16.dp))
    Spacer(Modifier.height(8.dp))
    DarkCard {
        Text(question, color = Color.White, fontWeight = FontWeight.SemiBold)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 8.dp)) {
            YesNo("Não", !enabled) { onEnabled(false) }
            YesNo("Sim", enabled) { onEnabled(true) }
        }
        if (enabled) {
            OutlinedTextField(name, onName, label = { Text("Nome") }, colors = FieldColors, modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
            OutlinedTextField(email, onEmail, label = { Text("E-mail") }, colors = FieldColors, modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
            Text(hint, color = Color(0xFF8E989F), fontSize = 12.sp, modifier = Modifier.padding(top = 6.dp))
        }
    }
}

@Composable
fun HealthIconSection(healthy: Boolean) {
    val tone = if (healthy) HealthFitColors.Accent else Color(0xFF8E989F)
    Text("Ícone de Saúde", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 16.dp))
    Spacer(Modifier.height(8.dp))
    DarkCard {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Image(
                painter = painterResource(R.drawable.brandheart),
                contentDescription = null,
                modifier = Modifier.size(48.dp).clip(CircleShape),
                contentScale = ContentScale.Fit,
            )
            Column(Modifier.padding(start = 12.dp)) {
                Text(if (healthy) "Ícone saudável" else "Complete sono e água", color = tone, fontWeight = FontWeight.SemiBold)
                Text(
                    if (healthy) "Parabéns, mantenha o foco em sua saúde" else "Registre o sono e a água de hoje para o ícone ficar verde.",
                    color = Color(0xFFB7C0C8),
                    fontSize = 13.sp,
                )
                Text("O mesmo registro da tela inicial.", color = Color(0xFF8E989F), fontSize = 12.sp)
            }
        }
    }
}

@Composable
fun SleepWaterProfileSection(hours: Float, onHours: (Float) -> Unit, weightKg: String) {
    val kg = weightKg.toFloatOrNull() ?: 92f
    val waterMl = (kg * 35f).toInt()
    Text("Sono e Hidratação", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 16.dp))
    Spacer(Modifier.height(8.dp))
    DarkCard {
        Text("Horas de sono (hoje)", color = Color.White, fontWeight = FontWeight.SemiBold)
        Text("%.1f h".format(hours), color = HealthFitColors.Accent, fontWeight = FontWeight.Bold, fontSize = 20.sp)
        Slider(
            value = hours,
            onValueChange = onHours,
            valueRange = 0f..12f,
            steps = 23,
            colors = SliderDefaults.colors(thumbColor = HealthFitColors.Accent, activeTrackColor = HealthFitColors.Accent),
        )
        Text("Água recomendada", color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 8.dp))
        Text("%.1f L / dia · $waterMl ml".format(waterMl / 1000f), color = Color(0xFF4DA3FF), fontWeight = FontWeight.Bold)
        Text(
            "Cálculo: 35 ml por kg de peso corporal (${kg.toInt()} kg).",
            color = Color(0xFF8E989F),
            fontSize = 12.sp,
        )
    }
}

@Composable
fun EnergySection(energy: Int, onEnergy: (Int) -> Unit, pre: Int, onPre: (Int) -> Unit) {
    Text("Energéticos e Pré-treino", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 16.dp))
    Spacer(Modifier.height(8.dp))
    DarkCard {
        Text("Quantos energéticos você bebe durante o dia?", color = Color.White, fontWeight = FontWeight.SemiBold)
        Text(if (energy == 0) "Nenhum · 0 unidades" else "$energy hoje · $energy unidades", color = HealthFitColors.Accent, fontWeight = FontWeight.Bold)
        StepperLine("Energéticos hoje", energy, 0, 10, onEnergy)
        Text(
            when {
                energy > 1 -> "A OMS recomenda limitar bebidas energéticas. Até 400 mg de cafeína por dia."
                energy == 1 -> "Consumo moderado. Evite energéticos à noite para não prejudicar o sono."
                else -> "Ótimo! Menos cafeína ajuda no sono e na recuperação muscular."
            },
            color = Color(0xFF8E989F),
            fontSize = 12.sp,
            modifier = Modifier.padding(top = 6.dp),
        )
        Text("Quantos pré-treinos você tomou hoje?", color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 12.dp))
        Text(if (pre == 0) "Nenhum · 0 doses" else "$pre hoje", color = Color(0xFFFF9A3C), fontWeight = FontWeight.Bold)
        StepperLine("Pré-treino hoje", pre, 0, 5, onPre)
        Text("Até 400 mg de cafeína por dose.", color = Color(0xFF8E989F), fontSize = 12.sp, modifier = Modifier.padding(top = 6.dp))
    }
}

@Composable
fun RestTimerSection(
    rest: Int,
    onRest: (Int) -> Unit,
    alertAfter: Int,
    onAlert: (Int) -> Unit,
    notify: Boolean,
    onNotify: (Boolean) -> Unit,
) {
    Text("Cronômetro de Descanso", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 16.dp))
    Spacer(Modifier.height(8.dp))
    DarkCard {
        StepperLine("Descanso padrão: ${rest}s", rest, 15, 300, onRest, step = 15)
        StepperLine("Alerta após: ${alertAfter}s", alertAfter, 30, 600, onAlert, step = 30)
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp)) {
            Text("Notificações de descanso", color = Color.White, modifier = Modifier.weight(1f))
            Switch(
                checked = notify,
                onCheckedChange = onNotify,
                colors = SwitchDefaults.colors(checkedTrackColor = HealthFitColors.Accent, checkedThumbColor = Color.White),
            )
        }
    }
}

@Composable
fun LanguageSection(selected: String, onSelect: (String) -> Unit) {
    Text("Idioma", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 16.dp))
    Spacer(Modifier.height(8.dp))
    DarkCard {
        listOf(
            "🇧🇷 Português",
            "🇺🇸 English",
            "🇪🇸 Español",
            "🇫🇷 Français",
            "🇩🇪 Deutsch",
            "🇮🇹 Italiano",
        ).forEach { language ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onSelect(language) }
                    .padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(language, color = Color.White, modifier = Modifier.weight(1f))
                if (language == selected) {
                    Icon(Icons.Filled.Check, contentDescription = null, tint = HealthFitColors.Accent)
                }
            }
        }
    }
}

@Composable
fun PlanPage(current: String, onSelect: (String) -> Unit, onBack: () -> Unit) {
    val plans = listOf(
        "Gratuito" to "R$ 0",
        "Básico" to "R$ 9,90/mês",
        "Fit" to "R$ 12,90/mês",
        "IA Plus" to "R$ 19,90/mês",
        "Completo" to "R$ 24,90/mês",
    )
    PageColumn(onBack) {
        Text("Meu plano", color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
        plans.forEach { (name, price) ->
            val selected = name == current
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(if (selected) HealthFitColors.Accent else HealthFitColors.CardBackground)
                    .clickable { onSelect(name) }
                    .padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(name, color = if (selected) Color.Black else Color.White, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                Text(price, color = if (selected) Color.Black else Color(0xFFB7C0C8))
            }
        }
    }
}

@Composable
fun MeasuresPage(values: MutableMap<String, String>, onBack: () -> Unit) {
    val groups = listOf(
        "Superior" to listOf("Pescoço", "Ombros", "Peito", "Braço direito", "Braço esquerdo"),
        "Tronco" to listOf("Cintura", "Abdômen", "Quadril"),
        "Inferior" to listOf("Coxa direita", "Coxa esquerda", "Panturrilha direita", "Panturrilha esquerda"),
    )
    PageColumn(onBack) {
        Text("Medidas corporais", color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
        Text(
            "Digite as circunferências em centímetros. Campos vazios não entram no relatório.",
            color = Color(0xFFB7C0C8),
        )
        groups.forEach { (title, fields) ->
            Text(title, color = HealthFitColors.Accent, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 14.dp))
            fields.forEach { field ->
                OutlinedTextField(
                    value = values[field].orEmpty(),
                    onValueChange = { values[field] = it.filter { char -> char.isDigit() || char == '.' }.take(5) },
                    label = { Text("$field (cm)") },
                    colors = FieldColors,
                    modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                )
            }
        }
    }
}

@Composable
fun InfoPage(title: String, body: String, onBack: () -> Unit) {
    PageColumn(onBack) {
        Text(title, color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
        Text(body, color = Color(0xFFD5DDE3), modifier = Modifier.padding(top = 8.dp))
    }
}

@Composable
private fun PageColumn(onBack: () -> Unit, content: @Composable () -> Unit) {
    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
    ) {
        Text("Voltar", color = HealthFitColors.Accent, fontWeight = FontWeight.SemiBold, modifier = Modifier.clickable(onClick = onBack))
        Spacer(Modifier.height(12.dp))
        content()
    }
}

@Composable
private fun YesNo(label: String, selected: Boolean, onClick: () -> Unit) {
    Text(
        label,
        color = if (selected) Color.Black else Color.White,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(if (selected) HealthFitColors.Accent else Color(0xFF2A3138))
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 8.dp),
    )
}

@Composable
private fun StepperLine(label: String, value: Int, min: Int, max: Int, onChange: (Int) -> Unit, step: Int = 1) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp)) {
        Text(label, color = Color.White, modifier = Modifier.weight(1f))
        StepIcon(Icons.Filled.Remove) { onChange((value - step).coerceAtLeast(min)) }
        StepIcon(Icons.Filled.Add) { onChange((value + step).coerceAtMost(max)) }
    }
}

@Composable
private fun StepIcon(icon: androidx.compose.ui.graphics.vector.ImageVector, onClick: () -> Unit) {
    Icon(
        icon,
        contentDescription = null,
        tint = Color.Black,
        modifier = Modifier
            .padding(start = 8.dp)
            .size(32.dp)
            .clip(CircleShape)
            .background(HealthFitColors.Accent)
            .clickable(onClick = onClick)
            .padding(6.dp),
    )
}
