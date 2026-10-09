package com.healthfit.android.ui.nutrition

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
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.NightsStay
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material.icons.filled.Spa
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.healthfit.android.ui.components.BiotypeSection
import com.healthfit.android.ui.components.ChipRow
import com.healthfit.android.ui.components.DarkCard
import com.healthfit.android.ui.components.GradientButton
import com.healthfit.designsystem.HealthFitColors

@Composable
fun NutritionScreen(
    wellness: com.healthfit.android.ui.home.DailyWellness,
    athlete: com.healthfit.android.ui.home.AthleteProfile,
) {
    var tab by remember { mutableIntStateOf(0) }
    var showShopping by remember { mutableStateOf(false) }
    var deficit by remember { mutableIntStateOf(400) }
    val objective = athlete.objective
    var lactose by remember { mutableStateOf(true) }
    var menuVersion by remember { mutableIntStateOf(0) }
    val eaten = remember { androidx.compose.runtime.mutableStateListOf<String>() }
    var supplement by remember { mutableStateOf("Whey Protein") }
    var amount by remember { mutableIntStateOf(30) }
    var unit by remember { mutableStateOf("g") }
    val supplementLog = remember { androidx.compose.runtime.mutableStateListOf<String>() }
    var analysisMeal by remember { mutableStateOf("Café") }
    var analyzed by remember { mutableStateOf(false) }
    val meta = 2900 - deficit
    if (showShopping) {
        ShoppingListScreen(onBack = { showShopping = false })
        return
    }
    Column(modifier = Modifier.fillMaxSize()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "Nutrição",
                color = Color.White,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
                modifier = Modifier.weight(1f),
            )
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .clickable { showShopping = true },
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Filled.ShoppingCart, contentDescription = "Lista", tint = HealthFitColors.Accent)
            }
        }
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp),
        ) {
            if (tab == 0) {
                DarkCard {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(36.dp)
                                .clip(RoundedCornerShape(10.dp))
                                .background(HealthFitColors.Accent),
                            contentAlignment = Alignment.Center,
                        ) {
                            Icon(Icons.Filled.FitnessCenter, contentDescription = null, tint = Color.Black, modifier = Modifier.size(18.dp))
                        }
                        Column(Modifier.padding(start = 10.dp)) {
                            Text("Cardápio alinhado ao treino", color = Color.White, fontWeight = FontWeight.Bold)
                            Text("Série iniciantes", color = HealthFitColors.Accent, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                            Text(
                                "Manutenção calórica com proteína adequada para adaptação. Iniciante Full Body",
                                color = Color(0xFFB7C0C8),
                                fontSize = 13.sp,
                            )
                        }
                    }
                }
                Spacer(Modifier.height(12.dp))
            }
            ChipRow(
                labels = listOf("Plano", "Cardápio", "Suplementos", "Análise"),
                selected = tab,
                onSelect = { tab = it },
            )
            Spacer(Modifier.height(16.dp))
            when (tab) {
                0 -> PlanTab(deficit, athlete, wellness, lactose, meta, { deficit = it }, { lactose = it }) { menuVersion += 1 }
                1 -> MenuTab(meta, eaten.toSet(), menuVersion) { name ->
                    if (name in eaten) eaten.remove(name) else eaten.add(name)
                }
                2 -> SupplementsTab(supplement, amount, unit, supplementLog.toList(), { supplement = it }, { amount = it }, { unit = it }) {
                    supplementLog.add("$supplement · $amount $unit")
                }
                else -> AnalysisTab(analysisMeal, analyzed, { analysisMeal = it }) { analyzed = true }
            }
            Spacer(Modifier.height(12.dp))
        }
    }
}

@Composable
private fun PlanTab(
    deficit: Int,
    athlete: com.healthfit.android.ui.home.AthleteProfile,
    wellness: com.healthfit.android.ui.home.DailyWellness,
    lactose: Boolean,
    meta: Int,
    onDeficit: (Int) -> Unit,
    onLactose: (Boolean) -> Unit,
    onUpdateMenu: () -> Unit,
) {
    val objective = athlete.objective
    val height = athlete.heightCm.toFloatOrNull()?.takeIf { it > 0f } ?: 176f
    val imc = wellness.weight / ((height / 100f) * (height / 100f))
    Text("Plano para ${athlete.bodyType.title}", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold)
    Text("Objetivo: $objective", color = Color(0xFFB7C0C8), modifier = Modifier.padding(bottom = 8.dp))
    BiotypeSection(athlete.bodyType) { athlete.bodyType = it }
    Spacer(Modifier.height(14.dp))
    Text("Objetivo", color = Color.White, fontWeight = FontWeight.SemiBold)
    Spacer(Modifier.height(8.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        ObjectiveTile("Ganho de Massa", Icons.Filled.FitnessCenter, HealthFitColors.Accent, objective == "Ganho de Massa", Modifier.weight(1f)) { athlete.objective = "Ganho de Massa" }
        ObjectiveTile("Perda de Gordura", Icons.Filled.LocalFireDepartment, Color(0xFFFF4D4D), objective == "Perda de Gordura", Modifier.weight(1f)) { athlete.objective = "Perda de Gordura" }
    }
    Spacer(Modifier.height(8.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        ObjectiveTile("Manutenção", Icons.Filled.Remove, Color(0xFF4DA3FF), objective == "Manutenção", Modifier.weight(1f)) { athlete.objective = "Manutenção" }
        ObjectiveTile("Resistência", Icons.Filled.Favorite, Color(0xFFFF9A3C), objective == "Resistência", Modifier.weight(1f)) { athlete.objective = "Resistência" }
    }
    Text(
        "Dados físicos vêm do Perfil (peso, altura, idade e sexo).",
        color = Color(0xFF8E989F),
        fontSize = 12.sp,
        textAlign = TextAlign.Center,
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp),
    )
    Text("Déficit Calórico", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold)
    Text("Gasto diário estimado (TDEE): 2.900 kcal", color = Color(0xFFB7C0C8))
    Spacer(Modifier.height(8.dp))
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text("Déficit diário", color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
        StepButton(Icons.Filled.Remove) { onDeficit((deficit - 50).coerceAtLeast(0)) }
        Text("  -${deficit} kcal  ", color = HealthFitColors.Accent, fontWeight = FontWeight.Bold)
        StepButton(Icons.Filled.Add) { onDeficit((deficit + 50).coerceAtMost(1000)) }
    }
    Spacer(Modifier.height(10.dp))
    DarkCard {
        Row {
            Column(Modifier.weight(1f)) {
                Text("Meta calórica final", color = Color(0xFFB7C0C8), fontSize = 13.sp)
                Text("Perda estimada", color = Color(0xFFB7C0C8), fontSize = 13.sp)
            }
            Column(horizontalAlignment = Alignment.End) {
                Text("$meta kcal/dia", color = HealthFitColors.Accent, fontWeight = FontWeight.Bold)
                Text("~${"%.2f".format(deficit * 7 / 7700f)} kg/semana", color = Color(0xFFFF9A3C), fontWeight = FontWeight.SemiBold)
            }
        }
    }
    Spacer(Modifier.height(10.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        StatTile("Metabolismo Basal", "TMB (repouso)", "1871 kcal/dia", Icons.Filled.Favorite, Color(0xFFFF4D6A), Modifier.weight(1f))
        StatTile("Meta Diária", "TDEE − $deficit kcal", "$meta kcal/dia", Icons.Filled.LocalFireDepartment, Color(0xFFFF9A3C), Modifier.weight(1f))
    }
    Spacer(Modifier.height(8.dp))
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text("IMC: ${"%.1f".format(imc)}", color = Color(0xFFB7C0C8), fontSize = 13.sp)
        Text("TDEE: 2.900 kcal", color = Color(0xFFB7C0C8), fontSize = 13.sp)
    }
    Spacer(Modifier.height(12.dp))
    GradientButton(text = "Atualizar Cardápio", onClick = onUpdateMenu, icon = Icons.Filled.Add)
    Spacer(Modifier.height(16.dp))
    Text("Você tolera lactose?", color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold)
    Spacer(Modifier.height(8.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Choice("Sim", lactose) { onLactose(true) }
        Choice("Não", !lactose) { onLactose(false) }
    }
}

@Composable
private fun MenuTab(meta: Int, eaten: Set<String>, menuVersion: Int, onToggle: (String) -> Unit) {
    val doneKcal = eaten.size * (meta / 6)
    Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom) {
        Column(Modifier.weight(1f)) {
            Text("$meta kcal", color = Color(0xFFFF9A3C), fontWeight = FontWeight.Bold, fontSize = 20.sp)
            Text("vs meta diária", color = Color(0xFF8E989F), fontSize = 12.sp)
        }
        Column(horizontalAlignment = Alignment.End) {
            Text(if (doneKcal >= meta) "Na meta" else "Em andamento", color = HealthFitColors.Accent, fontWeight = FontWeight.Bold)
            Text("$doneKcal kcal feitas", color = Color(0xFF8E989F), fontSize = 12.sp)
        }
    }
    Text("Refeições: ${eaten.size}/6 concluídas", color = Color(0xFFB7C0C8), fontSize = 13.sp, modifier = Modifier.padding(vertical = 6.dp))
    if (menuVersion > 0) {
        Text("Cardápio atualizado para a meta de $meta kcal.", color = HealthFitColors.Accent, fontSize = 12.sp)
    }
    Text(
        "Toque na refeição para selecionar e marque como concluída quando comer.",
        color = Color(0xFFB7C0C8),
        fontSize = 13.sp,
        modifier = Modifier.padding(bottom = 10.dp),
    )
    MealRow("Café da Manhã", "Claras com Vegetais", "500 kcal", "P:57g C:21g G:14g", Icons.Filled.WbSunny, "Café da Manhã" in eaten) { onToggle("Café da Manhã") }
    MealRow("Lanche", "Maçã com Pasta de Amendoim", "250 kcal", "P:8g C:27g G:12g", Icons.Filled.Spa, "Lanche" in eaten) { onToggle("Lanche") }
    MealRow("Almoço", "Carne Magra com Feijão Light", "750 kcal", "P:76g C:53g G:20g", Icons.Filled.WbSunny, "Almoço" in eaten) { onToggle("Almoço") }
    MealRow("Lanche da Tarde", "Tapioca com Queijo", "250 kcal", "P:13g C:30g G:8g", Icons.Filled.Spa, "Lanche da Tarde" in eaten) { onToggle("Lanche da Tarde") }
    MealRow("Jantar", "Atum com Salada", "550 kcal", "P:47g C:36g G:18g", Icons.Filled.NightsStay, "Jantar" in eaten) { onToggle("Jantar") }
    MealRow("Ceia", "Iogurte de Coco", "200 kcal", "P:6g C:12g G:13g", Icons.Filled.NightsStay, "Ceia" in eaten) { onToggle("Ceia") }
}

@Composable
private fun MealRow(
    whenLabel: String,
    title: String,
    kcal: String,
    macros: String,
    icon: ImageVector,
    done: Boolean,
    onToggle: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 8.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(HealthFitColors.CardBackground)
            .clickable(onClick = onToggle)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (done) {
            Icon(Icons.Filled.CheckCircle, contentDescription = null, tint = HealthFitColors.Accent, modifier = Modifier.size(18.dp))
        } else {
            Box(Modifier.size(18.dp).border(1.5.dp, Color(0xFF8E989F), CircleShape))
        }
        Icon(icon, contentDescription = null, tint = Color(0xFFFF9A3C), modifier = Modifier.padding(start = 10.dp).size(22.dp))
        Column(Modifier.weight(1f).padding(start = 8.dp)) {
            Text(whenLabel, color = Color(0xFF8E989F), fontSize = 11.sp)
            Text(title, color = Color.White, fontWeight = FontWeight.SemiBold)
        }
        Column(horizontalAlignment = Alignment.End) {
            Text(kcal, color = Color(0xFFFF9A3C), fontWeight = FontWeight.Bold)
            Text(macros, color = Color(0xFF8E989F), fontSize = 11.sp)
        }
    }
}

@Composable
private fun SupplementsTab(
    selected: String,
    amount: Int,
    unit: String,
    log: List<String>,
    onSelect: (String) -> Unit,
    onAmount: (Int) -> Unit,
    onUnit: (String) -> Unit,
    onSave: () -> Unit,
) {
    Text("Suplementos de hoje", color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.Bold)
    Text(
        "Registre o que você ingeriu hoje. Os dados ficam salvos no dia atual.",
        color = Color(0xFFB7C0C8),
        modifier = Modifier.padding(top = 4.dp, bottom = 12.dp),
    )
    DarkCard {
        Text("Escolha o suplemento", color = Color.White, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(10.dp))
        val items = listOf(
            "Whey Protein", "Creatina", "BCAA", "Multivitamínico",
            "Ômega-3", "Vitamina D", "Cafeína", "Pré-treino",
            "Glutamina", "Colágeno", "Outro",
        )
        items.chunked(2).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(bottom = 8.dp)) {
                row.forEach { name ->
                    val on = name == selected
                    Text(
                        name,
                        color = if (on) Color.Black else Color.White,
                        fontWeight = FontWeight.SemiBold,
                        textAlign = TextAlign.Center,
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(14.dp))
                            .background(if (on) HealthFitColors.Accent else Color(0xFF12161A))
                            .clickable { onSelect(name) }
                            .padding(vertical = 16.dp),
                    )
                }
                if (row.size == 1) Spacer(Modifier.weight(1f))
            }
        }
    }
    Spacer(Modifier.height(12.dp))
    DarkCard {
        Text("Quantidade ingerida", color = Color.White, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(
                "$amount",
                color = Color.White,
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .background(Color(0xFF12161A))
                    .clickable { onAmount(amount + 5) }
                    .padding(horizontal = 18.dp, vertical = 10.dp),
            )
            listOf("g", "ml", "cápsulas", "scoop").forEach { option ->
                Text(
                    option,
                    color = if (option == unit) Color.Black else Color.White,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(if (option == unit) HealthFitColors.Accent else Color(0xFF12161A))
                        .clickable { onUnit(option) }
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                )
            }
        }
    }
    Spacer(Modifier.height(12.dp))
    GradientButton(text = "Registrar ingestão", onClick = onSave)
    log.forEach { entry ->
        Text(entry, color = HealthFitColors.Accent, modifier = Modifier.padding(top = 8.dp))
    }
}

@Composable
private fun AnalysisTab(meal: String, analyzed: Boolean, onMeal: (String) -> Unit, onAnalyze: () -> Unit) {
    Text("Análise de refeição", color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.Bold)
    Text(
        "Recurso do plano IA Plus. Foto do prato ou do rótulo nutricional — o app lê a tabela quando houver; senão estima pelo visual. Só macros são salvos; a foto é descartada.",
        color = Color(0xFFB7C0C8),
        modifier = Modifier.padding(top = 4.dp, bottom = 12.dp),
    )
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(140.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(HealthFitColors.CardBackground),
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(Icons.Filled.CameraAlt, contentDescription = null, tint = HealthFitColors.Accent, modifier = Modifier.size(28.dp))
            Text(if (analyzed) "Foto estimada · macros abaixo" else "Nenhuma foto selecionada", color = Color(0xFFB7C0C8), modifier = Modifier.padding(top = 8.dp))
        }
    }
    Spacer(Modifier.height(12.dp))
    GradientButton(text = "Adicionar foto", onClick = onAnalyze, icon = Icons.Filled.CameraAlt)
    Spacer(Modifier.height(14.dp))
    Text("Refeição", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
    Spacer(Modifier.height(8.dp))
    val meals = listOf("Café", "Lanche", "Almoço", "Lanche T.", "Janta", "Ceia")
    meals.chunked(3).forEach { row ->
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(bottom = 8.dp)) {
            row.forEach { name ->
                val on = name == meal
                Text(
                    name,
                    color = if (on) Color.Black else Color.White,
                    fontWeight = FontWeight.SemiBold,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(14.dp))
                        .background(if (on) HealthFitColors.Accent else HealthFitColors.CardBackground)
                        .clickable { onMeal(name) }
                        .padding(vertical = 18.dp),
                )
            }
        }
    }
    Text("Registros de hoje", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp, modifier = Modifier.padding(top = 8.dp))
    Text(
        if (analyzed) "$meal · 420 kcal · P 32g · C 38g · G 14g" else "Nenhuma análise registrada hoje.",
        color = if (analyzed) Color.White else Color(0xFFB7C0C8),
        modifier = Modifier.padding(top = 4.dp),
    )
}

@Composable
private fun ShoppingListScreen(onBack: () -> Unit) {
    val items = remember {
        androidx.compose.runtime.mutableStateListOf(
            "Claras" to true,
            "Carne magra" to true,
            "Feijão" to true,
            "Atum" to false,
            "Tapioca" to false,
            "Queijo" to false,
            "Maçã" to false,
            "Pasta de amendoim" to false,
            "Iogurte de coco" to false,
            "Whey" to false,
        )
    }
    Column(Modifier.fillMaxSize().verticalScroll(androidx.compose.foundation.rememberScrollState()).padding(16.dp)) {
        Text("Lista de compras", color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold, modifier = Modifier.clickable(onClick = onBack))
        Text("Toque para marcar o que já comprou. Toque no título para voltar.", color = HealthFitColors.TextSecondary, modifier = Modifier.padding(bottom = 12.dp))
        items.forEachIndexed { index, (name, bought) ->
            Row(
                Modifier
                    .fillMaxWidth()
                    .padding(bottom = 8.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(HealthFitColors.CardBackground)
                    .clickable { items[index] = name to !bought }
                    .padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (bought) Icon(Icons.Filled.CheckCircle, null, tint = HealthFitColors.Accent) else Box(Modifier.size(18.dp).border(1.5.dp, Color(0xFF8E989F), CircleShape))
                Text(name, color = Color.White, modifier = Modifier.padding(start = 10.dp))
            }
        }
    }
}

@Composable
private fun ObjectiveTile(
    label: String,
    icon: ImageVector,
    tint: Color,
    selected: Boolean,
    modifier: Modifier,
    onClick: () -> Unit,
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(16.dp))
            .background(if (selected) tint else Color(0xFF1C2126))
            .clickable(onClick = onClick)
            .padding(vertical = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(icon, contentDescription = null, tint = if (selected) Color.White else tint)
        Text(label, color = Color.White, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center, modifier = Modifier.padding(top = 6.dp))
    }
}

@Composable
private fun StatTile(
    title: String,
    subtitle: String,
    value: String,
    icon: ImageVector,
    tint: Color,
    modifier: Modifier,
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(16.dp))
            .background(HealthFitColors.CardBackground)
            .padding(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(16.dp))
            Text(" $title", color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
        }
        Text(subtitle, color = Color(0xFF8E989F), fontSize = 11.sp)
        Text(value, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp, modifier = Modifier.padding(top = 6.dp))
    }
}

@Composable
private fun StepButton(icon: ImageVector, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(28.dp)
            .clip(CircleShape)
            .background(HealthFitColors.Accent)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = Color.Black, modifier = Modifier.size(16.dp))
    }
}

@Composable
private fun Choice(text: String, selected: Boolean, onClick: () -> Unit) {
    Text(
        text,
        color = if (selected) Color.Black else Color.White,
        fontWeight = FontWeight.Bold,
        modifier = Modifier
            .clip(RoundedCornerShape(16.dp))
            .background(if (selected) HealthFitColors.Accent else HealthFitColors.CardBackground)
            .clickable(onClick = onClick)
            .padding(horizontal = 22.dp, vertical = 10.dp),
    )
}
