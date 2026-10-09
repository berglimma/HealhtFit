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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.DocumentScanner
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.healthfit.android.R
import com.healthfit.android.ui.components.DarkCard
import com.healthfit.android.ui.components.GradientButton
import com.healthfit.android.ui.components.HeroCard
import com.healthfit.designsystem.HealthFitColors

private fun clone(title: String, description: String, source: WorkoutSheet) =
    source.copy(title = title, description = description)

private fun base(index: Int) = WorkoutCatalog.male[index % WorkoutCatalog.male.size]

private fun baseOf(catalog: List<WorkoutSheet>, index: Int) = catalog[index % catalog.size]

data class ProgramContent(
    val screenTitle: String,
    val eyebrow: String,
    val cover: Int,
    val headerLine: String,
    val personal: WorkoutSheet,
    val levels: List<Triple<String, String, List<String>>>,
    val focus: List<Triple<String, String, List<String>>>,
    val shape1: List<WorkoutSheet>,
    val shape2: List<WorkoutSheet>,
    val soldado: List<WorkoutSheet>,
    val cabo: List<WorkoutSheet>,
    val recommended: List<WorkoutSheet>,
    val recent: List<WorkoutSheet>,
    val catalog: List<WorkoutSheet>,
    val recommendedSubtitle: String,
) {
    fun sheets(titles: List<String>, description: String) =
        titles.mapIndexed { index, title -> clone(title, description, baseOf(catalog, index)) }
}

private val sharedFocus = listOf(
    Triple("Ganho de massa muscular", "Hipertrofia com superávit calórico", listOf("Guiado — Massa Peito/Costas", "Guiado — Massa Pernas/Ombros")),
    Triple("Perda de gordura", "Déficit proteico e treino metabólico", listOf("Guiado — Emagrecimento Circuito", "Guiado — Emagrecimento Full Body")),
    Triple("Foco em pernas", "Quadríceps, posteriores e glúteos", listOf("Guiado — Pernas Volume", "Guiado — Pernas e Posterior")),
    Triple("Foco em competição", "Performance, potência e recuperação", listOf("Guiado — Competição Potência", "Guiado — Competição Atleta")),
    Triple("Foco em braços", "Bíceps, tríceps e volume de braços", listOf("Guiado — Braços Pump", "Guiado — Braços e Ombros")),
    Triple("Costas", "Largura, espessura e postura", listOf("Guiado — Costas Largura", "Guiado — Costas Espessura")),
)

private val sharedLevels = listOf(
    Triple("Iniciantes", "Técnica, carga leve e volume controlado", listOf("Guiado — Iniciante Full Body", "Guiado — Iniciante Superiores")),
    Triple("Intermediários", "Volume moderado e progressão de carga", listOf("Guiado — Intermediário Push/Pull", "Guiado — Intermediário Pernas")),
    Triple("Avançados", "Alta intensidade, volume e complexidade", listOf("Guiado — Avançado Força", "Guiado — Avançado Hipertrofia")),
)

object MaleProgram {
    val personal = clone(
        "Treino — Peito + Tríceps",
        "Ficha do personal · prescrita por Berg Limma",
        base(0),
    )
    val shape1 = listOf(
        "A — Superiores (Nível 1)" to "Base do método",
        "B — Inferiores (Nível 1)" to "Base do método",
        "C — Costas e Braços (Nível 1)" to "Base do método",
        "D — Inferiores 2 (Nível 1)" to "Base do método",
    ).mapIndexed { index, (title, description) -> clone(title, description, base(index)) }
    val shape2 = listOf(
        "E — Peito Ombros Tríceps (Nível 2)",
        "F — Inferiores e Abdômen (Nível 2)",
        "G — Costas Bíceps (Nível 2)",
        "H — Inferiores Completo (Nível 2)",
        "I — Ombros Bíceps Tríceps (Nível 2)",
    ).mapIndexed { index, title -> clone(title, "Progressão do método", base(index)) }
    val soldado = listOf(
        "A — Peito Ombros Tríceps (Soldado)",
        "B — Costas Posterior Bíceps (Soldado)",
        "C — Inferiores (Soldado)",
        "D — Condicionamento AEJ (Soldado)",
    ).mapIndexed { index, title -> clone(title, "Base Push / Pull / Inferiores + condicionamento", base(index)) }
    val cabo = listOf(
        "E — Peito Ombros Tríceps (Cabo)",
        "F — Costas Posterior Bíceps (Cabo)",
        "G — Inferiores Força (Cabo)",
        "H — Inferiores Posterior (Cabo)",
        "I — Condicionamento Missão (Cabo)",
    ).mapIndexed { index, title -> clone(title, "Progressão de volume e intensidade", base(index + 4)) }
    val content = ProgramContent(
        screenTitle = "Programa Masculino",
        eyebrow = "MASCULINO",
        cover = R.drawable.workoutprogrammale,
        headerLine = "1 do personal · ${WorkoutCatalog.male.size} recomendados",
        personal = personal,
        levels = sharedLevels,
        focus = sharedFocus,
        shape1 = shape1,
        shape2 = shape2,
        soldado = soldado,
        cabo = cabo,
        recommended = WorkoutCatalog.male,
        recent = listOf(cabo[0], soldado[1]),
        catalog = WorkoutCatalog.male,
        recommendedSubtitle = "Fichas do programa masculino · novas opções em 3 dias",
    )
}

object FemaleProgram {
    private fun sheet(title: String, description: String, index: Int) =
        clone(title, description, baseOf(WorkoutCatalog.female, index))

    val personal = sheet(
        "Treino — Glúteos + Pernas",
        "Ficha do personal · prescrita por Berg Limma",
        0,
    )
    val shape1 = listOf(
        "Shape Feminino A — Inferiores (Nível 1)" to "Base do método",
        "Shape Feminino B — Superiores (Nível 1)" to "Base do método",
        "Shape Feminino C — Posterior e Abdutora (Nível 1)" to "Base do método",
        "Shape Feminino D — Costas e Braços (Nível 1)" to "Base do método",
    ).mapIndexed { index, (title, description) -> sheet(title, description, index) }
    val shape2 = listOf(
        "Shape Feminino E — Posterior e Glúteo (Nível 2)",
        "Shape Feminino F — Superiores Completo (Nível 2)",
        "Shape Feminino G — Quadríceps (Nível 2)",
        "Shape Feminino H — Peito Ombros Braços (Nível 2)",
        "Shape Feminino I — Glúteo (Nível 2)",
    ).mapIndexed { index, title -> sheet(title, "Progressão do método", index) }
    val soldado = listOf(
        "Militar Feminino A — Peito Ombros Tríceps (Soldado)",
        "Militar Feminino B — Costas Posterior Bíceps (Soldado)",
        "Militar Feminino C — Inferiores e Glúteo (Soldado)",
        "Militar Feminino D — Condicionamento AEJ (Soldado)",
    ).mapIndexed { index, title -> sheet(title, "Base Push / Pull / Inferiores + condicionamento", index) }
    val cabo = listOf(
        "Militar Feminino E — Peito Ombros Tríceps (Cabo)",
        "Militar Feminino F — Costas Posterior Bíceps (Cabo)",
        "Militar Feminino G — Inferiores Força (Cabo)",
        "Militar Feminino H — Posterior e Glúteo (Cabo)",
        "Militar Feminino I — Condicionamento Missão (Cabo)",
    ).mapIndexed { index, title -> sheet(title, "Progressão de volume e intensidade", index + 4) }
    val content = ProgramContent(
        screenTitle = "Programa Feminino",
        eyebrow = "FEMININO",
        cover = R.drawable.workoutprogramfemale,
        headerLine = "1 do personal · ${WorkoutCatalog.female.size} recomendados",
        personal = personal,
        levels = sharedLevels,
        focus = sharedFocus,
        shape1 = shape1,
        shape2 = shape2,
        soldado = soldado,
        cabo = cabo,
        recommended = WorkoutCatalog.female,
        recent = listOf(cabo[0], soldado[1]),
        catalog = WorkoutCatalog.female,
        recommendedSubtitle = "Fichas do programa feminino · novas opções em 3 dias",
    )
}

@Composable
fun ProgramHubScreen(
    program: ProgramContent,
    custom: List<WorkoutSheet>,
    onBack: () -> Unit,
    onOpen: (WorkoutSheet) -> Unit,
    onOpenGroup: (String, String, List<WorkoutSheet>) -> Unit,
    onCreate: () -> Unit,
    onScan: () -> Unit,
) {
    BackHandler(onBack = onBack)
    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = "Voltar",
                tint = Color.White,
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(Color(0xFF2A3138))
                    .clickable(onClick = onBack)
                    .padding(8.dp),
            )
            Text(
                program.screenTitle,
                color = Color.White,
                fontWeight = FontWeight.Bold,
                fontSize = 18.sp,
                modifier = Modifier.weight(1f).padding(horizontal = 8.dp),
            )
            Icon(
                Icons.Filled.DocumentScanner,
                contentDescription = "Escanear ficha",
                tint = HealthFitColors.Accent,
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(Color(0xFF2A3138))
                    .clickable(onClick = onScan)
                    .padding(8.dp),
            )
            Spacer(Modifier.size(8.dp))
            Icon(
                Icons.Filled.Add,
                contentDescription = "Criar ficha",
                tint = Color.Black,
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(HealthFitColors.Accent)
                    .clickable(onClick = onCreate)
                    .padding(8.dp),
            )
        }
        Spacer(Modifier.height(16.dp))
        DarkCard {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.FitnessCenter, contentDescription = null, tint = HealthFitColors.Accent)
                Column(Modifier.padding(start = 10.dp).weight(1f)) {
                    Text(program.eyebrow, color = Color.White, fontWeight = FontWeight.Bold)
                    Text(program.headerLine, color = Color(0xFFB7C0C8), fontSize = 12.sp)
                }
            }
            Text(
                "Já treino",
                color = HealthFitColors.Accent,
                fontWeight = FontWeight.Bold,
                fontSize = 13.sp,
                modifier = Modifier.padding(top = 8.dp),
            )
        }
        Spacer(Modifier.height(16.dp))
        SectionHead("Fichas do seu personal", "Em destaque · prescritas por Berg Limma")
        HeroCard(
            title = program.personal.title,
            subtitle = "${program.personal.exercises.size} exercícios · ~${program.personal.minutes} min · Berg",
            brush = Brush.linearGradient(listOf(Color(0xFF102018), Color(0xFF1A2830))),
            imageRes = program.cover,
            eyebrow = "MÉTODO DO PERSONAL",
            height = 148.dp,
            onClick = { onOpen(program.personal) },
            modifier = Modifier.padding(top = 8.dp),
            footer = {
                Text("Personal", color = HealthFitColors.Accent, fontWeight = FontWeight.Bold, fontSize = 12.sp, modifier = Modifier.padding(top = 4.dp))
            },
        )
        Spacer(Modifier.height(16.dp))
        SectionHead("Personalizados", "Treinos criados para este programa")
        if (custom.isEmpty()) {
            Text(
                "Nenhum personalizado ainda. Toque em + para criar ou importe uma ficha (câmera, foto ou PDF).",
                color = Color(0xFFB7C0C8),
                fontSize = 13.sp,
                modifier = Modifier.padding(top = 6.dp),
            )
        } else {
            custom.forEach { sheet ->
                PhotoSheetCard(sheet, program.cover, "Personalizado") { onOpen(sheet) }
            }
        }
        Spacer(Modifier.height(16.dp))
        SectionHead("Séries por nível", "Escolha a intensidade e abra as fichas guiadas")
        program.levels.forEach { (title, subtitle, names) ->
            FocusCard(title, subtitle, "${names.size} fichas", "MÉTODO · $title", program.cover) {
                onOpenGroup(title, subtitle, program.sheets(names, subtitle))
            }
        }
        Spacer(Modifier.height(8.dp))
        SectionHead(
            "Foco do treino",
            "A primeira ficha alinha o cardápio; outro treino ou objetivo remove esse alinhamento",
        )
        program.focus.forEach { (title, subtitle, names) ->
            FocusCard(title, subtitle, "${names.size} fichas", "MÉTODO · $title", program.cover) {
                onOpenGroup(title, subtitle, program.sheets(names, subtitle))
            }
        }
        Spacer(Modifier.height(8.dp))
        SectionHead("Foco no Shape · Nível 1", "Base do método")
        program.shape1.forEach { PhotoSheetCard(it, program.cover, "Foco no Shape · Nível 1") { onOpen(it) } }
        Spacer(Modifier.height(12.dp))
        SectionHead("Foco no Shape · Nível 2", "Progressão do método")
        program.shape2.forEach { PhotoSheetCard(it, program.cover, "Foco no Shape · Nível 2") { onOpen(it) } }
        Spacer(Modifier.height(12.dp))
        SectionHead("Método Militar · Soldado", "Base Push / Pull / Inferiores + condicionamento")
        program.soldado.forEach { PhotoSheetCard(it, program.cover, "Método Militar · Soldado") { onOpen(it) } }
        Spacer(Modifier.height(12.dp))
        SectionHead("Método Militar · Cabo", "Progressão de volume e intensidade")
        program.cabo.forEach { PhotoSheetCard(it, program.cover, "Método Militar · Cabo") { onOpen(it) } }
        Spacer(Modifier.height(12.dp))
        SectionHead("Recomendados", program.recommendedSubtitle)
        program.recommended.forEach { PhotoSheetCard(it, program.cover, "Recomendado") { onOpen(it) } }
        Spacer(Modifier.height(12.dp))
        SectionHead("Últimos treinos", "Até 4 sessões concluídas neste programa")
        program.recent.forEach { sheet ->
            PhotoSheetCard(sheet, program.cover, "Último treino") { onOpen(sheet) }
        }
        Spacer(Modifier.height(16.dp))
    }
}

@Composable
fun SheetGroupScreen(
    title: String,
    subtitle: String,
    sheets: List<WorkoutSheet>,
    imageRes: Int,
    onBack: () -> Unit,
    onOpen: (WorkoutSheet) -> Unit,
) {
    BackHandler(onBack = onBack)
    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
    ) {
        Text("Voltar", color = HealthFitColors.Accent, fontWeight = FontWeight.SemiBold, modifier = Modifier.clickable(onClick = onBack))
        Text(title, color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 8.dp))
        Text(subtitle, color = Color(0xFFB7C0C8), modifier = Modifier.padding(bottom = 8.dp))
        sheets.forEach { PhotoSheetCard(it, imageRes, title) { onOpen(it) } }
    }
}

@Composable
fun CreateSheetScreen(onBack: () -> Unit, onSave: (String) -> Unit) {
    var title by remember { mutableStateOf("") }
    BackHandler(onBack = onBack)
    Column(Modifier.fillMaxSize().padding(16.dp)) {
        Text("Voltar", color = HealthFitColors.Accent, fontWeight = FontWeight.SemiBold, modifier = Modifier.clickable(onClick = onBack))
        Text("Nova ficha", color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(vertical = 12.dp))
        OutlinedTextField(
            title,
            { title = it },
            label = { Text("Nome do treino") },
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = Color.White,
                unfocusedTextColor = Color.White,
                focusedBorderColor = HealthFitColors.Accent,
                unfocusedBorderColor = Color(0xFF3A4148),
            ),
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(16.dp))
        GradientButton("Salvar personalizado", { if (title.isNotBlank()) onSave(title.trim()) })
    }
}

@Composable
fun ScanSheetScreen(onBack: () -> Unit, onImport: () -> Unit) {
    BackHandler(onBack = onBack)
    Column(Modifier.fillMaxSize().padding(16.dp)) {
        Text("Voltar", color = HealthFitColors.Accent, fontWeight = FontWeight.SemiBold, modifier = Modifier.clickable(onClick = onBack))
        Text("Escanear ficha", color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 12.dp))
        Text(
            "A câmera lê a ficha em papel. Neste aparelho, importe a foto de exemplo para criar a ficha no programa.",
            color = Color(0xFFB7C0C8),
            modifier = Modifier.padding(vertical = 12.dp),
        )
        GradientButton("Importar foto de exemplo", onImport)
    }
}

@Composable
private fun SectionHead(title: String, subtitle: String) {
    Text(title, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 20.sp)
    Text(subtitle, color = Color(0xFF8E989F), fontSize = 13.sp, modifier = Modifier.padding(bottom = 4.dp))
}

@Composable
private fun FocusCard(
    title: String,
    subtitle: String,
    count: String,
    eyebrow: String,
    imageRes: Int,
    onClick: () -> Unit,
) {
    Spacer(Modifier.height(8.dp))
    HeroCard(
        title = title,
        subtitle = subtitle,
        brush = Brush.linearGradient(listOf(Color(0xFF102018), Color(0xFF1A2830))),
        imageRes = imageRes,
        eyebrow = eyebrow,
        height = 148.dp,
        footer = {
            Text(count, color = Color.White, fontSize = 12.sp, modifier = Modifier.padding(top = 4.dp))
        },
        onClick = onClick,
    )
}

@Composable
private fun PhotoSheetCard(sheet: WorkoutSheet, imageRes: Int, method: String, onClick: () -> Unit) {
    Spacer(Modifier.height(8.dp))
    HeroCard(
        title = sheet.title,
        subtitle = "${sheet.exercises.size} exercícios · ~${sheet.minutes} min",
        brush = Brush.linearGradient(listOf(Color(0xFF102018), Color(0xFF1A2830))),
        imageRes = imageRes,
        eyebrow = method,
        height = 168.dp,
        onClick = onClick,
    )
}

