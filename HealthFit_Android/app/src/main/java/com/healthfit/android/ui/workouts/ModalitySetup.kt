package com.healthfit.android.ui.workouts

import androidx.activity.compose.BackHandler
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
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
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.healthfit.android.R
import com.healthfit.android.ui.components.GradientButton
import com.healthfit.designsystem.HealthFitColors
import kotlin.math.roundToInt

private enum class SportKind { Run, Walk, Bike, Treadmill, Swim, Surf, Kite, Row, Climb, Other }

private enum class Intensity(val title: String, val detail: String, val minutes: Int, val multiplier: Float, val pace: String, val color: Color) {
    Low("Baixa", "Ritmo leve, foco em resistência e recuperação", 50, 0.75f, "7:00 /km", Color(0xFF3DDC3A)),
    Medium("Média", "Ritmo moderado, ideal para queima calórica", 40, 1f, "6:00 /km", Color(0xFFFF8C33)),
    High("Alta", "Ritmo intenso, máximo esforço cardiovascular", 30, 1.35f, "5:30 /km", Color(0xFFE85D4C)),
}

private val KmPresets = listOf(3, 5, 8, 10, 15, 20, 30, 40)
private val KcalPresets = listOf(100, 150, 200, 250, 300, 350, 400, 500, 600, 800)

@Composable
fun CardioSetupScreen(
    title: String,
    imageRes: Int,
    onBack: () -> Unit,
    onStart: (minutes: Int, detail: String) -> Unit,
) {
    BackHandler(onBack = onBack)
    val kind = sportKind(title)
    var freeDistance by remember { mutableStateOf(kind == SportKind.Treadmill) }
    var distanceKm by remember { mutableIntStateOf(if (kind == SportKind.Bike) 20 else 5) }
    var intensity by remember { mutableStateOf(Intensity.Medium) }
    var useCalories by remember { mutableStateOf(false) }
    var kcalGoal by remember { mutableIntStateOf(300) }
    var primary by remember { mutableStateOf(defaultPrimary(kind)) }
    var secondary by remember { mutableStateOf(defaultSecondary(kind)) }
    var diary by remember { mutableStateOf(false) }
    val outdoor = kind == SportKind.Run || kind == SportKind.Walk || kind == SportKind.Bike || kind == SportKind.Treadmill
    val water = kind == SportKind.Surf || kind == SportKind.Kite
    val minutes = if (water) 45 else intensity.minutes
    val kcal = (kcalPerMin(title) * intensity.multiplier * minutes).roundToInt()

    if (diary) {
        DiaryScreen(title, onBack = { diary = false })
        return
    }

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
    ) {
        SetupBar(title, onBack)
        IdentityCard(
            imageRes = imageRes,
            title = title,
            description = modalityLead(kind),
            meta = "~${kcalPerMin(title).roundToInt()} kcal/min",
        )
        diaryTitle(title)?.let { label ->
            Spacer(Modifier.height(12.dp))
            DiaryLink(label, diarySubtitle(title)) { diary = true }
        }
        if (kind == SportKind.Treadmill) {
            SectionTitle("Elevação", "A configuração principal da esteira.")
            OptionGrid(listOf("Sem elevação", "Com elevação"), primary) { primary = it }
            SectionTitle("Inclinação")
            OptionGrid(listOf("0%", "2%", "5%", "8%"), secondary) { secondary = it }
        }
        if (outdoor) {
            SectionTitle(distanceTitle(kind))
            FreeDistanceCard(selected = freeDistance, hint = freeHint(kind)) { freeDistance = true }
            Text(
                "Ou escolha uma distância:",
                color = HealthFitColors.TextSecondary,
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(top = 12.dp, bottom = 8.dp),
            )
            KmGrid(selected = if (freeDistance) null else distanceKm) {
                freeDistance = false
                distanceKm = it
            }
        }
        when (kind) {
            SportKind.Swim -> {
                SectionTitle("Piscina")
                OptionGrid(listOf("Piscina 25 m", "Piscina 50 m"), primary) { primary = it }
                SectionTitle("Voltas")
                OptionGrid(listOf("10 voltas", "20 voltas", "40 voltas", "60 voltas"), secondary) { secondary = it }
            }
            SportKind.Surf -> {
                SectionTitle("Setup Surf")
                OptionGrid(listOf("Shortboard", "Funboard", "Longboard"), primary) { primary = it }
                SectionTitle("Vento e maré")
                OptionGrid(listOf("Vento fraco", "Moderado", "Forte"), secondary) { secondary = it }
            }
            SportKind.Kite -> {
                SectionTitle("Setup Kitesurf")
                OptionGrid(listOf("Kite 7 m", "Kite 9 m", "Kite 12 m"), primary) { primary = it }
                SectionTitle("Modo")
                OptionGrid(listOf("Freeride", "Wave", "Freestyle"), secondary) { secondary = it }
            }
            SportKind.Row -> {
                SectionTitle("Barco")
                OptionGrid(listOf("Ergométrico", "Skiff", "Double"), primary) { primary = it }
                SectionTitle("Distância")
                OptionGrid(listOf("Livre", "2 km", "5 km"), secondary) { secondary = it }
            }
            SportKind.Climb -> {
                SectionTitle("Disciplina")
                OptionGrid(listOf("Esportiva", "Boulder", "Via longa"), primary) { primary = it }
                SectionTitle("Grau")
                OptionGrid(listOf("Grau 5", "Grau 6", "Grau 7"), secondary) { secondary = it }
            }
            else -> Unit
        }
        if (!water) {
            CalorieBlock(useCalories, kcalGoal, { useCalories = it }, { kcalGoal = it })
            SectionTitle("Intensidade")
            Intensity.entries.forEach { option ->
                IntensityCard(
                    option = option,
                    selected = intensity == option,
                    pace = if (outdoor) option.pace else "${option.minutes} min sugeridos",
                ) { intensity = option }
                Spacer(Modifier.height(8.dp))
            }
        }
        SummaryCard(
            rows = buildList {
                add("Duração" to "$minutes min")
                if (outdoor) add("Distância" to if (freeDistance) "Livre" else "$distanceKm km")
                if (kind != SportKind.Run && kind != SportKind.Walk && kind != SportKind.Bike) {
                    if (primary.isNotBlank()) add("Ajuste" to primary)
                    if (secondary.isNotBlank() && kind != SportKind.Other) add("Detalhe" to secondary)
                }
                if (!water) add("Intensidade" to intensity.title)
                add("Calorias" to if (useCalories) "Meta $kcalGoal kcal" else "~$kcal kcal")
            },
        )
        Spacer(Modifier.height(16.dp))
        GradientButton(startLabel(kind, title), onClick = {
            val distance = when {
                !outdoor -> ""
                freeDistance -> "distância livre"
                else -> "$distanceKm km"
            }
            val extra = listOf(primary, secondary).filter { it.isNotBlank() && kind != SportKind.Run && kind != SportKind.Walk && kind != SportKind.Bike }
            val parts = listOfNotNull(
                distance.takeIf { it.isNotBlank() },
                extra.takeIf { it.isNotEmpty() }?.joinToString(" · "),
                if (water) null else "intensidade ${intensity.title.lowercase()}",
                if (useCalories) "meta $kcalGoal kcal" else "~$kcal kcal",
            )
            onStart(minutes, parts.joinToString(" · "))
        }, icon = Icons.Filled.PlayArrow)
        Spacer(Modifier.height(28.dp))
    }
}

@Composable
fun MeditationSetupScreen(title: String, subtitle: String, onBack: () -> Unit, onStart: (Int) -> Unit) {
    BackHandler(onBack = onBack)
    var minutes by remember { mutableIntStateOf(10) }
    val prompts = meditationPrompts(title)
    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
    ) {
        SetupBar(title, onBack)
        IdentityCard(
            imageRes = meditationCover(title),
            title = title,
            description = subtitle,
            meta = "${prompts.size} etapas guiadas",
        )
        SectionTitle("Duração")
        OptionGrid(listOf("5 min", "10 min", "15 min", "20 min"), "$minutes min") {
            minutes = it.substringBefore(" ").toInt()
        }
        SectionTitle("Tópicos da sessão")
        Column(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(HealthFitColors.CardBackground)
                .padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            prompts.forEachIndexed { index, prompt ->
                Row(verticalAlignment = Alignment.Top) {
                    Box(
                        Modifier
                            .size(22.dp)
                            .clip(CircleShape)
                            .background(HealthFitColors.Accent),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text("${index + 1}", color = Color.Black, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                    }
                    Text(
                        prompt,
                        color = HealthFitColors.TextSecondary,
                        fontSize = 14.sp,
                        modifier = Modifier.padding(start = 10.dp),
                    )
                }
            }
        }
        Spacer(Modifier.height(16.dp))
        GradientButton("Iniciar Meditação", onClick = { onStart(minutes) }, icon = Icons.Filled.PlayArrow)
        Spacer(Modifier.height(28.dp))
    }
}

@Composable
fun FightHubScreen(onBack: () -> Unit, onStart: (String, String) -> Unit) {
    var selected by remember { mutableStateOf<FightStyle?>(null) }
    val style = selected
    if (style != null) {
        FightConfirm(style, onBack = { selected = null }) { plan ->
            onStart(style.name, "${style.reference} · $plan")
        }
        return
    }
    BackHandler(onBack = onBack)
    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
    ) {
        SetupBar("Luta", onBack)
        Row(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(HealthFitColors.CardBackground)
                .padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Image(
                painter = painterResource(R.drawable.fightcoverluta),
                contentDescription = null,
                modifier = Modifier
                    .size(72.dp)
                    .clip(RoundedCornerShape(14.dp)),
                contentScale = ContentScale.Crop,
            )
            Column(Modifier.padding(start = 14.dp)) {
                Text("LUTA", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                Text(
                    "Tempo de combate, BPM e calorias no Galaxy Watch7",
                    color = HealthFitColors.TextSecondary,
                    fontSize = 13.sp,
                )
            }
        }
        SectionTitle("Escolha a modalidade", "O cronômetro abre depois de confirmar o tempo oficial.")
        FightStyles.forEach { item ->
            Column(
                Modifier
                    .fillMaxWidth()
                    .padding(bottom = 10.dp)
                    .clip(RoundedCornerShape(18.dp))
                    .background(HealthFitColors.CardBackground)
                    .clickable { selected = item }
                    .padding(14.dp),
            ) {
                Text(item.reference.uppercase(), color = item.accent, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                Text(item.name, color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 4.dp))
                Text(item.summary, color = HealthFitColors.TextSecondary, fontSize = 13.sp, modifier = Modifier.padding(top = 2.dp))
                Text(
                    "Iniciar cronômetro  ·  ~${item.kcalPerMin} kcal/min",
                    color = HealthFitColors.Accent,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.padding(top = 8.dp),
                )
            }
        }
        Spacer(Modifier.height(16.dp))
    }
}

@Composable
private fun FightConfirm(style: FightStyle, onBack: () -> Unit, onStart: (String) -> Unit) {
    BackHandler(onBack = onBack)
    var plan by remember { mutableStateOf(style.rounds.first()) }
    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
    ) {
        SetupBar(style.name, onBack)
        IdentityCard(
            imageRes = R.drawable.fightcoverluta,
            title = style.name,
            description = style.summary,
            meta = "~${style.kcalPerMin} kcal/min",
        )
        SectionTitle("Tempo oficial", style.reference)
        OptionGrid(style.rounds, plan) { plan = it }
        SummaryCard(listOf("Plano" to plan, "Referência" to style.reference))
        Spacer(Modifier.height(16.dp))
        GradientButton("Iniciar ${style.name}", onClick = { onStart(plan) }, icon = Icons.Filled.PlayArrow)
        Spacer(Modifier.height(28.dp))
    }
}

@Composable
private fun SetupBar(title: String, onBack: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(top = 4.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
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
        Text(
            title,
            color = Color.White,
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(start = 4.dp),
        )
    }
}

@Composable
private fun IdentityCard(imageRes: Int, title: String, description: String, meta: String) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(HealthFitColors.CardBackground)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Image(
            painter = painterResource(imageRes),
            contentDescription = null,
            modifier = Modifier
                .size(72.dp)
                .clip(RoundedCornerShape(14.dp))
                .border(1.dp, HealthFitColors.Accent.copy(alpha = 0.45f), RoundedCornerShape(14.dp)),
            contentScale = ContentScale.Crop,
        )
        Column(Modifier.padding(start = 14.dp)) {
            Text(title, color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold)
            Text(description, color = HealthFitColors.TextSecondary, fontSize = 13.sp, modifier = Modifier.padding(top = 2.dp))
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 6.dp)) {
                Icon(Icons.Filled.LocalFireDepartment, contentDescription = null, tint = HealthFitColors.AccentSecondary, modifier = Modifier.size(14.dp))
                Text(meta, color = HealthFitColors.AccentSecondary, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(start = 4.dp))
            }
        }
    }
}

@Composable
private fun DiaryLink(title: String, subtitle: String, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(HealthFitColors.CardBackground)
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .size(52.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(Color(0xFF163A46)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.AutoMirrored.Filled.MenuBook, contentDescription = null, tint = Color(0xFF7ED0E0))
        }
        Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
            Text(title, color = Color.White, fontWeight = FontWeight.Bold)
            Text(subtitle, color = HealthFitColors.TextSecondary, fontSize = 12.sp)
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = HealthFitColors.TextSecondary)
    }
}

@Composable
private fun SectionTitle(title: String, subtitle: String? = null) {
    Text(title, color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 18.dp))
    if (subtitle != null) {
        Text(subtitle, color = HealthFitColors.TextSecondary, fontSize = 13.sp, modifier = Modifier.padding(top = 2.dp, bottom = 8.dp))
    }
}

@Composable
private fun FreeDistanceCard(selected: Boolean, hint: String, onClick: () -> Unit) {
    Row(
        Modifier
            .padding(top = 8.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(if (selected) HealthFitColors.Accent.copy(alpha = 0.12f) else HealthFitColors.CardBackground)
            .border(if (selected) 2.dp else 0.dp, if (selected) HealthFitColors.Accent else Color.Transparent, RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text("Sem meta de km", color = if (selected) HealthFitColors.Accent else Color.White, fontWeight = FontWeight.Bold)
            Text(hint, color = HealthFitColors.TextSecondary, fontSize = 12.sp)
        }
        if (selected) Icon(Icons.Filled.CheckCircle, contentDescription = null, tint = HealthFitColors.Accent)
    }
}

@Composable
private fun KmGrid(selected: Int?, onSelect: (Int) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        KmPresets.chunked(4).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                row.forEach { km ->
                    val on = selected == km
                    Column(
                        Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(12.dp))
                            .background(if (on) HealthFitColors.Accent else HealthFitColors.CardBackground)
                            .clickable { onSelect(km) }
                            .padding(vertical = 10.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Text("$km", color = if (on) Color.Black else Color.White, fontWeight = FontWeight.Bold)
                        Text("KM", color = if (on) Color.Black.copy(alpha = 0.7f) else HealthFitColors.TextSecondary, fontSize = 10.sp, fontWeight = FontWeight.SemiBold)
                    }
                }
            }
        }
    }
}

@Composable
private fun OptionGrid(options: List<String>, selected: String, onSelect: (String) -> Unit) {
    val columns = if (options.size <= 3) options.size else 2
    Column(verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 8.dp)) {
        options.chunked(columns).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                row.forEach { option ->
                    val on = option == selected
                    Text(
                        option,
                        color = if (on) Color.Black else Color.White,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 14.sp,
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(12.dp))
                            .background(if (on) HealthFitColors.Accent else HealthFitColors.CardBackground)
                            .clickable { onSelect(option) }
                            .padding(vertical = 14.dp),
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    )
                }
                repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

@Composable
private fun IntensityCard(option: Intensity, selected: Boolean, pace: String, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(if (selected) option.color else HealthFitColors.CardBackground)
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(option.title, color = if (selected) Color.White else Color.White, fontWeight = FontWeight.Bold, fontSize = 17.sp)
            Text(option.detail, color = if (selected) Color.White.copy(alpha = 0.9f) else HealthFitColors.TextSecondary, fontSize = 12.sp)
            Text(pace, color = if (selected) Color.White else option.color, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 4.dp))
        }
        if (selected) Icon(Icons.Filled.CheckCircle, contentDescription = null, tint = Color.White)
    }
}

@Composable
private fun CalorieBlock(enabled: Boolean, goal: Int, onToggle: (Boolean) -> Unit, onGoal: (Int) -> Unit) {
    Row(
        Modifier.fillMaxWidth().padding(top = 18.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text("Meta de calorias", color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
        Switch(
            checked = enabled,
            onCheckedChange = onToggle,
            colors = SwitchDefaults.colors(checkedTrackColor = HealthFitColors.AccentSecondary, checkedThumbColor = Color.White),
        )
    }
    if (enabled) {
        Text(
            "Ao atingir a meta o treino continua. Ele só encerra quando você finalizar.",
            color = HealthFitColors.TextSecondary,
            fontSize = 12.sp,
        )
        OptionGrid(KcalPresets.map { "$it" }, "$goal") { onGoal(it.toInt()) }
    } else {
        Text(
            "Sem meta definida — as calorias acompanham a sessão no Galaxy Watch7.",
            color = HealthFitColors.TextSecondary,
            fontSize = 12.sp,
            modifier = Modifier.padding(top = 4.dp),
        )
    }
}

@Composable
private fun SummaryCard(rows: List<Pair<String, String>>) {
    Column(
        Modifier
            .padding(top = 8.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(HealthFitColors.CardBackground)
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        rows.forEach { (label, value) ->
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(label, color = HealthFitColors.TextSecondary, fontSize = 13.sp, modifier = Modifier.weight(1f))
                Text(value, color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
            }
        }
    }
}

@Composable
private fun DiaryScreen(title: String, onBack: () -> Unit) {
    BackHandler(onBack = onBack)
    val rows = when {
        title.contains("Natação") -> listOf("Ontem · 20 voltas · 25 m · 32 min", "3 out · 40 voltas · 50 m · 48 min")
        title.contains("bike") || title.contains("Bicicleta") -> listOf("Ontem · 18,4 km · 210 m de elevação", "2 out · 32 km · ritmo 22 km/h")
        title == "Surf" -> listOf("Ontem · 11 ondas · spot praia · vento fraco", "1 out · 8 ondas · maré enchente")
        title == "Kitesurf" -> listOf("Ontem · kite 9 m · 6 saltos · vento 18 nós", "30 set · wave · 42 min")
        else -> listOf("Ontem · via esportiva · grau 6", "28 set · boulder · 5 problemas")
    }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp)) {
        SetupBar(diaryTitle(title) ?: "Diário", onBack)
        rows.forEach { row ->
            Text(
                row,
                color = Color.White,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier
                    .padding(bottom = 8.dp)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(HealthFitColors.CardBackground)
                    .padding(16.dp),
            )
        }
    }
}

private fun sportKind(title: String) = when {
    title.contains("Esteira") -> SportKind.Treadmill
    title.contains("Natação") -> SportKind.Swim
    title == "Surf" -> SportKind.Surf
    title == "Kitesurf" -> SportKind.Kite
    title == "Remo" -> SportKind.Row
    title == "Escalada" -> SportKind.Climb
    title.contains("Caminhada") -> SportKind.Walk
    title.contains("bike", ignoreCase = true) || title.contains("Bicicleta pedal") -> SportKind.Bike
    title.contains("Corrida") -> SportKind.Run
    else -> SportKind.Other
}

private fun distanceTitle(kind: SportKind) = when (kind) {
    SportKind.Bike -> "Meta de pedal (km)"
    SportKind.Walk -> "Meta de caminhada (km)"
    SportKind.Treadmill -> "Meta na esteira (km)"
    else -> "Modo da corrida"
}

private fun freeHint(kind: SportKind) = when (kind) {
    SportKind.Bike -> "Pedale sem meta e encerre quando quiser."
    SportKind.Walk -> "Caminhe livremente — encerre quando quiser."
    else -> "Acompanhe livremente — encerre quando quiser."
}

private fun startLabel(kind: SportKind, title: String) = when (kind) {
    SportKind.Run -> "Iniciar Corrida"
    SportKind.Walk -> "Iniciar Caminhada"
    SportKind.Bike -> "Iniciar Pedal"
    SportKind.Treadmill -> "Iniciar Esteira"
    SportKind.Swim -> "Iniciar Natação"
    SportKind.Surf -> "Iniciar Surf"
    SportKind.Kite -> "Iniciar Kitesurf"
    else -> "Iniciar $title"
}

private fun defaultPrimary(kind: SportKind) = when (kind) {
    SportKind.Treadmill -> "Sem elevação"
    SportKind.Swim -> "Piscina 25 m"
    SportKind.Surf -> "Shortboard"
    SportKind.Kite -> "Kite 9 m"
    SportKind.Row -> "Ergométrico"
    SportKind.Climb -> "Esportiva"
    else -> ""
}

private fun defaultSecondary(kind: SportKind) = when (kind) {
    SportKind.Treadmill -> "0%"
    SportKind.Swim -> "20 voltas"
    SportKind.Surf -> "Vento fraco"
    SportKind.Kite -> "Freeride"
    SportKind.Row -> "Livre"
    SportKind.Climb -> "Grau 6"
    else -> ""
}

private fun diaryTitle(title: String) = when {
    title.contains("Natação") -> "Diário de natação"
    title.contains("bike", ignoreCase = true) || title.contains("Bicicleta pedal") -> "Diário de bike"
    title == "Kitesurf" -> "Diário de kite surf"
    title == "Surf" -> "Diário de surf"
    title == "Escalada" -> "Diário de escalada"
    else -> null
}

private fun diarySubtitle(title: String) = when {
    title.contains("Natação") -> "Histórico, distância, ritmo e calorias"
    title.contains("bike", ignoreCase = true) || title.contains("Bicicleta") -> "Problemas, manutenção e vida útil das peças"
    title == "Kitesurf" -> "Saltos, spot, vento e comparativo"
    title == "Surf" -> "Spot, condições e comparativo de sessões"
    else -> "Progressão por grau, vias e equipamento"
}

private fun modalityLead(kind: SportKind) = when (kind) {
    SportKind.Treadmill -> "Indoor · configure se tem elevação · sem mapa GPS"
    SportKind.Swim -> "Nados em piscina com voltas, distância e ritmo"
    SportKind.Surf -> "Sessão de surf com spot e registro de condições"
    SportKind.Kite -> "Kitesurf com equipamento, modos e vento"
    SportKind.Row -> "Remo na água ou ergométrico, distância e split"
    SportKind.Climb -> "Escalada em parede indoor ou rocha"
    SportKind.Walk -> "Caminhada outdoor com mapa, ritmo e passos"
    SportKind.Bike -> "Ciclismo outdoor em rua, ciclovia ou trilha"
    SportKind.Run -> "Corrida ao ar livre com mapa, ritmo e rota"
    SportKind.Other -> "Meta da sessão e intensidade"
}

private fun kcalPerMin(title: String) = when {
    title.contains("Burpee") -> 13.0
    title.contains("Kitesurf") || title.contains("Corda") -> 12.0
    title.contains("Escada") || title.contains("Escalada") || title.contains("Natação") -> 11.0
    title.contains("Corrida") || title.contains("Mountain") || title == "Remo" || title == "Surf" -> 10.0
    title.contains("Esteira") || title.contains("Polichinelo") || title.contains("pedal") -> 9.0
    title.contains("Caminhada") -> 6.0
    else -> 8.0
}

private fun meditationPrompts(title: String): List<String> = when {
    title.contains("Relaxamento") -> listOf(
        "Deite-se ou sente-se com a coluna ereta.",
        "Traga atenção aos dedos dos pés. Relaxe-os completamente.",
        "Suba pelas pernas, soltando qualquer tensão muscular.",
        "Relaxe quadris, abdômen e costas.",
        "Solte os ombros — deixe-os caírem naturalmente.",
        "Suavize o rosto: mandíbula, testa e olhos.",
        "Quando terminar, mova os dedos e abra os olhos devagar.",
    )
    title.contains("Gratidão") -> listOf(
        "Respire fundo e traga à mente algo pelo qual é grato.",
        "Pode ser uma pessoa, uma conquista ou um momento simples.",
        "Sinta a gratidão se expandir no peito.",
        "Agradeça pela saúde, mesmo que em pequenas vitórias.",
        "Pense em alguém que te apoia.",
        "Carregue essa sensação pelo resto do dia.",
    )
    title.contains("Foco") -> listOf(
        "Sente-se em postura alerta, mas relaxada.",
        "Deixe de lado distrações e compromissos futuros.",
        "Visualize seu objetivo principal com clareza.",
        "Imagine-se executando com confiança e disciplina.",
        "Afirme: eu tenho foco, eu tenho força.",
        "Abra os olhos pronto para agir com intenção.",
    )
    title.contains("Ansiedade") -> listOf(
        "Nomeie mentalmente 3 coisas que você vê.",
        "Sinta o contato do corpo com a cadeira ou o chão.",
        "Inspire por 4 segundos. Segure por 2. Expire por 6.",
        "Repita: eu estou seguro neste momento.",
        "Os pensamentos são nuvens — deixe-os passar.",
        "Retorne ao dia com mais leveza.",
    )
    title.contains("Sono") -> listOf(
        "Deite-se confortavelmente e feche os olhos.",
        "Diminua a respiração. Inspire e expire mais devagar.",
        "Relaxe a testa, as pálpebras e a mandíbula.",
        "Conte lentamente de 10 até 1 a cada expiração.",
        "Seu corpo sabe descansar. Confie nele.",
        "Permita-se adormecer em paz.",
    )
    title.contains("Recuperação") -> listOf(
        "Após o esforço, sente-se e respire profundamente.",
        "Agradeça ao corpo pelo trabalho realizado.",
        "Leve atenção aos músculos que trabalharam hoje.",
        "Seu corpo está se reconstruindo agora. Descanse.",
        "O coração volta ao ritmo de repouso.",
        "Você treinou bem. Agora é hora de recuperar.",
    )
    else -> listOf(
        "Sente-se confortavelmente e feche os olhos.",
        "Inspire lentamente pelo nariz contando até quatro.",
        "Segure o ar por um instante, sem tensão.",
        "Expire suavemente pela boca contando até seis.",
        "Quando a mente divagar, volte à respiração.",
        "Finalize agradecendo por este momento de pausa.",
    )
}
