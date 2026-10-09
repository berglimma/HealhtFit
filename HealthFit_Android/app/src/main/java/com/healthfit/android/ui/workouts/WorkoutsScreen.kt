package com.healthfit.android.ui.workouts

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.healthfit.android.R
import com.healthfit.android.ui.components.ChipRow
import com.healthfit.android.ui.components.HeroCard
import com.healthfit.android.ui.components.MetaRow
import com.healthfit.android.ui.components.SectionLabel

private val Gym = Brush.linearGradient(listOf(Color(0xFF102018), Color(0xFF1C3A2A), Color(0xFF0E1814)))
private val Sunset = Brush.linearGradient(listOf(Color(0xFF3A2418), Color(0xFF1A2840)))
private val Night = Brush.linearGradient(listOf(Color(0xFF101820), Color(0xFF1A3050)))
private val Red = Brush.linearGradient(listOf(Color(0xFF3A1014), Color(0xFF1A1214)))
private val Water = Brush.linearGradient(listOf(Color(0xFF0E2438), Color(0xFF123040)))

private sealed interface WorkoutDest {
    data object Browse : WorkoutDest
    data class Program(val key: String) : WorkoutDest
    data class Group(val programKey: String, val title: String, val subtitle: String, val sheets: List<WorkoutSheet>) : WorkoutDest
    data class OpenSheet(val sheet: WorkoutSheet, val programKey: String, val group: Group?) : WorkoutDest
    data class OpenLive(val sheet: WorkoutSheet, val programKey: String, val group: Group?) : WorkoutDest
    data class CreateCustom(val programKey: String) : WorkoutDest
    data class Scan(val programKey: String) : WorkoutDest
    data class Detail(val key: String, val index: Int) : WorkoutDest
    data class Live(val key: String, val index: Int) : WorkoutDest
    data class CardioSetup(val title: String) : WorkoutDest
    data class MeditationSetup(val title: String, val subtitle: String) : WorkoutDest
    data object Fight : WorkoutDest
    data class Activity(val title: String, val detail: String, val cardio: Boolean, val cover: Int) : WorkoutDest
    data class Finished(val session: com.healthfit.android.ui.home.FinishedWorkout) : WorkoutDest
}

private fun sheetsFor(key: String): List<WorkoutSheet> = when (key) {
    "female" -> WorkoutCatalog.female
    "home" -> WorkoutCatalog.home
    "mobility" -> WorkoutCatalog.mobility
    else -> WorkoutCatalog.male
}

private fun programTitle(key: String) = when (key) {
    "female" -> "Programa Feminino"
    "home" -> "Treine em Casa"
    "mobility" -> "Mobilidade"
    else -> "Programa Masculino"
}

@Composable
fun WorkoutsScreen() {
    var tab by remember { mutableIntStateOf(0) }
    var dest by remember { mutableStateOf<WorkoutDest>(WorkoutDest.Browse) }
    val maleCustom = remember { mutableStateListOf<WorkoutSheet>() }
    val femaleCustom = remember { mutableStateListOf<WorkoutSheet>() }
    when (val current = dest) {
        is WorkoutDest.Program -> {
            val hub = when (current.key) {
                "female" -> FemaleProgram.content
                "male" -> MaleProgram.content
                else -> null
            }
            if (hub != null) {
                ProgramHubScreen(
                    program = hub,
                    custom = if (current.key == "female") femaleCustom else maleCustom,
                    onBack = { dest = WorkoutDest.Browse },
                    onOpen = { dest = WorkoutDest.OpenSheet(it, current.key, null) },
                    onOpenGroup = { title, subtitle, sheets ->
                        dest = WorkoutDest.Group(current.key, title, subtitle, sheets)
                    },
                    onCreate = { dest = WorkoutDest.CreateCustom(current.key) },
                    onScan = { dest = WorkoutDest.Scan(current.key) },
                )
                return
            }
            WorkoutProgramScreen(
                title = programTitle(current.key),
                subtitle = "Toque em um card para ver os exercícios e o GIF.",
                sheets = sheetsFor(current.key),
                imageRes = if (current.key == "home") R.drawable.workoutprogramhome else R.drawable.workoutprogrammobility,
                onBack = { dest = WorkoutDest.Browse },
                onOpen = { dest = WorkoutDest.Detail(current.key, it) },
            )
            return
        }
        is WorkoutDest.Group -> {
            SheetGroupScreen(
                title = current.title,
                subtitle = current.subtitle,
                sheets = current.sheets,
                imageRes = if (current.programKey == "female") R.drawable.workoutprogramfemale else R.drawable.workoutprogrammale,
                onBack = { dest = WorkoutDest.Program(current.programKey) },
                onOpen = { dest = WorkoutDest.OpenSheet(it, current.programKey, current) },
            )
            return
        }
        is WorkoutDest.OpenSheet -> {
            WorkoutDetailScreen(
                sheet = current.sheet,
                onBack = {
                    dest = current.group ?: WorkoutDest.Program(current.programKey)
                },
                onStart = { dest = WorkoutDest.OpenLive(current.sheet, current.programKey, current.group) },
            )
            return
        }
        is WorkoutDest.OpenLive -> {
            ActiveWorkoutScreen(
                sheet = current.sheet,
                onClose = { dest = WorkoutDest.OpenSheet(current.sheet, current.programKey, current.group) },
            )
            return
        }
        is WorkoutDest.CreateCustom -> {
            CreateSheetScreen(
                onBack = { dest = WorkoutDest.Program(current.programKey) },
                onSave = { name ->
                    val source = if (current.programKey == "female") WorkoutCatalog.female else WorkoutCatalog.male
                    val target = if (current.programKey == "female") femaleCustom else maleCustom
                    target.add(0, source.first().copy(title = name, description = "Ficha personalizada"))
                    dest = WorkoutDest.Program(current.programKey)
                },
            )
            return
        }
        is WorkoutDest.Scan -> {
            ScanSheetScreen(
                onBack = { dest = WorkoutDest.Program(current.programKey) },
                onImport = {
                    val source = if (current.programKey == "female") WorkoutCatalog.female else WorkoutCatalog.male
                    val target = if (current.programKey == "female") femaleCustom else maleCustom
                    val title = if (current.programKey == "female") "Ficha importada — Glúteos" else "Ficha importada — Peito"
                    target.add(0, source.first().copy(title = title, description = "Importada da foto de exemplo"))
                    dest = WorkoutDest.Program(current.programKey)
                },
            )
            return
        }
        is WorkoutDest.Detail -> {
            val sheets = sheetsFor(current.key)
            WorkoutDetailScreen(
                sheet = sheets[current.index],
                onBack = { dest = WorkoutDest.Program(current.key) },
                onStart = { dest = WorkoutDest.Live(current.key, current.index) },
            )
            return
        }
        is WorkoutDest.Live -> {
            ActiveWorkoutScreen(
                sheet = sheetsFor(current.key)[current.index],
                onClose = { dest = WorkoutDest.Detail(current.key, current.index) },
            )
            return
        }
        is WorkoutDest.CardioSetup -> {
            CardioSetupScreen(
                title = current.title,
                imageRes = cardioImage(current.title),
                onBack = { dest = WorkoutDest.Browse },
                onStart = { minutes, detail ->
                    dest = WorkoutDest.Activity(current.title, "$detail · $minutes min", true, cardioImage(current.title))
                },
            )
            return
        }
        is WorkoutDest.MeditationSetup -> {
            MeditationSetupScreen(
                title = current.title,
                subtitle = current.subtitle,
                onBack = { dest = WorkoutDest.Browse },
                onStart = {
                    dest = WorkoutDest.Activity(current.title, "Meditação · $it min", false, meditationCover(current.title))
                },
            )
            return
        }
        WorkoutDest.Fight -> {
            FightHubScreen(
                onBack = { dest = WorkoutDest.Browse },
                onStart = { name, detail ->
                    dest = WorkoutDest.Activity("Luta — $name", detail, true, R.drawable.fightcoverluta)
                },
            )
            return
        }
        is WorkoutDest.Activity -> {
            if (current.cardio && cardioUsesLiveMap(current.title)) {
                CardioLiveScreen(
                    title = current.title,
                    detail = current.detail,
                    onClose = { elapsed, km, pace ->
                        val session = finishedActivity(current.title, elapsed, true, current.cover)
                        dest = WorkoutDest.Finished(
                            session.copy(
                                whenLabel = if (km >= 0.02) "%.2f km · %s /km".format(km, pace) else session.whenLabel,
                            ),
                        )
                    },
                )
            } else {
                LiveActivityScreen(
                    title = current.title,
                    detail = current.detail,
                    onClose = { elapsed ->
                        dest = WorkoutDest.Finished(finishedActivity(current.title, elapsed, current.cardio, current.cover))
                    },
                )
            }
            return
        }
        is WorkoutDest.Finished -> {
            com.healthfit.android.ui.home.WorkoutFinishedScreen(
                session = current.session,
                onClose = { dest = WorkoutDest.Browse },
            )
            return
        }
        WorkoutDest.Browse -> Unit
    }
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
    ) {
        Text("Treinos", color = Color.White, fontSize = 34.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(12.dp))
        ChipRow(
            labels = listOf("Musculação", "Treine em Casa", "Cardio", "Meditação"),
            selected = tab,
            onSelect = { tab = it },
        )
        Spacer(Modifier.height(14.dp))
        when (tab) {
            0 -> StrengthTab(onOpen = { dest = WorkoutDest.Program(it) })
            1 -> HomeTab(onOpen = { index -> dest = WorkoutDest.Detail("home", index) })
            2 -> CardioTab(onOpen = { title ->
                dest = if (title == "Luta") WorkoutDest.Fight else WorkoutDest.CardioSetup(title)
            })
            else -> MeditationTab(onOpen = { title, subtitle -> dest = WorkoutDest.MeditationSetup(title, subtitle) })
        }
        Spacer(Modifier.height(8.dp))
    }
}

@Composable
private fun StrengthTab(onOpen: (String) -> Unit) {
    HeroCard(
        title = "Treino em dupla / equipe",
        subtitle = "2 equipe(s) · chat para marcar treinos",
        brush = Sunset,
        imageRes = R.drawable.duoteamcover,
        height = 180.dp,
        footer = {
            Spacer(Modifier.height(8.dp))
            MetaRow(Icons.Filled.Groups, "Abrir equipes    Ranking")
        },
    )
    Spacer(Modifier.height(16.dp))
    SectionLabel("Escolha o programa")
    Spacer(Modifier.height(10.dp))
    ProgramCard("MASCULINO", "Peito, costas, pernas e ombros", "${WorkoutCatalog.male.size} recomendados", "0 personalizados", R.drawable.workoutprogrammale) {
        onOpen("male")
    }
    Spacer(Modifier.height(10.dp))
    ProgramCard("FEMININO", "Glúteos, pernas, postura e core", "${WorkoutCatalog.female.size} recomendados", "0 personalizados", R.drawable.workoutprogramfemale) {
        onOpen("female")
    }
    Spacer(Modifier.height(10.dp))
    HeroCard(
        title = "MOBILIDADE",
        subtitle = "Aquecimento e pós-treino com demos",
        brush = Brush.linearGradient(listOf(Color(0xFF142030), Color(0xFF1A2838))),
        imageRes = R.drawable.workoutprogrammobility,
        eyebrow = "PARA MUSCULAÇÃO",
        height = 160.dp,
        footer = {
            Spacer(Modifier.height(8.dp))
            MetaRow(Icons.Filled.Star, "${WorkoutCatalog.mobility.size} fichas recomendadas", Color(0xFFFFD60A))
        },
        onClick = { onOpen("mobility") },
    )
    Text(
        "Mobilidade ajuda a preparar articulações para agachamento, terra, supino e desenvolvimento.",
        color = Color(0xFFB7C0C8),
        fontSize = 13.sp,
        modifier = Modifier.padding(top = 10.dp),
    )
}

@Composable
private fun ProgramCard(
    title: String,
    subtitle: String,
    recommended: String,
    custom: String,
    imageRes: Int,
    onClick: () -> Unit,
) {
    HeroCard(
        title = title,
        subtitle = subtitle,
        brush = Night,
        imageRes = imageRes,
        height = 168.dp,
        onClick = onClick,
        footer = {
            Spacer(Modifier.height(8.dp))
            MetaRow(Icons.Filled.Star, "$recommended    $custom", Color(0xFFFFD60A))
        },
    )
}

@Composable
private fun HomeTab(onOpen: (Int) -> Unit) {
    SectionLabel("Treinos com peso corporal — sem academia")
    Spacer(Modifier.height(10.dp))
    WorkoutCatalog.home.forEachIndexed { index, sheet ->
        HeroCard(
            title = sheet.title,
            subtitle = sheet.description,
            brush = Brush.linearGradient(listOf(Color(0xFF1A3028), Color(0xFF243028))),
            imageRes = R.drawable.workoutprogramhome,
            eyebrow = "TREINO EM CASA",
            height = 156.dp,
            footer = {
                Spacer(Modifier.height(6.dp))
                MetaRow(Icons.Filled.Star, "${sheet.exercises.size} exercícios · ~${sheet.minutes} min", Color(0xFFFFD60A))
            },
            onClick = { onOpen(index) },
        )
        Spacer(Modifier.height(10.dp))
    }
}

@Composable
private fun CardioTab(onOpen: (String) -> Unit) {
    val items = listOf(
        Triple("Corrida", "Corrida ao ar livre com mapa GPS, ritmo e rota", "Mapa GPS"),
        Triple("Esteira Ergométrica", "Indoor · configure se tem elevação · sem mapa GPS", "Elevação: sim ou não"),
        Triple("Caminhada", "Caminhada outdoor com mapa GPS, ritmo e passos", "Mapa GPS"),
        Triple("Mountain bike", "Mountain bike em trilha ou terreno irregular", "Mapa GPS"),
        Triple("Bicicleta pedal", "Ciclismo outdoor em rua ou ciclovia", "Mapa GPS"),
        Triple("Bicicleta ergométrica", "Bike estacionária indoor, sem GPS", "Indoor"),
        Triple("Surf", "Sessão de surf com GPS, spot e registro de condições", "Mapa GPS"),
        Triple("Kitesurf", "Kitesurf com equipamento, modos, saltos e mapa", "Mapa GPS"),
        Triple("Elíptico", "Movimento fluido de corpo inteiro", "~8 kcal/min"),
        Triple("Pular Corda", "Saltos contínuos com corda", "~12 kcal/min"),
        Triple("Escada", "Simulador de escadas ou degraus", "~11 kcal/min"),
        Triple("Escalada", "Escalada em parede indoor ou rocha", "~11 kcal/min"),
        Triple("Remo", "Remo na água ou ergométrico · SPM, split / 500 m", "Mapa GPS"),
        Triple("Natação", "Nados em piscina com voltas, distância e ritmo", "Piscina e voltas"),
        Triple("Polichinelo", "Jumping jacks em ritmo constante", "~9 kcal/min"),
        Triple("Burpees", "Exercício funcional de alta intensidade", "~13 kcal/min"),
        Triple("Luta", "Boxe, Muay Thai, Jiu-Jitsu, MMA e mais — cronômetro de combate", "Cronômetro de luta"),
    )
    items.forEachIndexed { index, (title, subtitle, meta) ->
        val brush = if (index % 2 == 0) Night else if (index % 3 == 0) Red else Water
        HeroCard(
            title = title,
            subtitle = subtitle,
            brush = brush,
            imageRes = cardioImage(title),
            height = 168.dp,
            eyebrow = if (title == "Luta") "CRONÔMETRO DE LUTA" else null,
            eyebrowColor = Color(0xFFFF6B6B),
            footer = {
                Spacer(Modifier.height(6.dp))
                MetaRow(
                    if (meta.contains("kcal")) Icons.Filled.LocalFireDepartment else Icons.Filled.Map,
                    meta,
                    if (meta.contains("kcal")) Color(0xFFFF9A3C) else Color.White,
                )
            },
            onClick = { onOpen(title) },
        )
        Spacer(Modifier.height(10.dp))
    }
}

@Composable
private fun MeditationTab(onOpen: (String, String) -> Unit) {
    SectionLabel("Sessões guiadas para recuperar e focar")
    Spacer(Modifier.height(10.dp))
    val covers = listOf(
        R.drawable.meditacaocoverrespiracao,
        R.drawable.meditacaocoverrelaxamento,
        R.drawable.meditacaocovergratidao,
        R.drawable.meditacaocoverfoco,
        R.drawable.meditacaocoveransiedade,
        R.drawable.meditacaocoversono,
        R.drawable.meditacaocoverrecuperacao,
    )
    MeditationTopics.forEachIndexed { index, (title, subtitle) ->
        HeroCard(
            title = title,
            subtitle = subtitle,
            brush = Brush.linearGradient(listOf(Color(0xFF141E38), Color(0xFF1A2848))),
            imageRes = covers[index],
            eyebrow = "MEDITAÇÃO",
            height = 168.dp,
            onClick = { onOpen(title, subtitle) },
        )
        Spacer(Modifier.height(10.dp))
    }
}

private fun cardioImage(title: String): Int = when (title) {
    "Corrida" -> R.drawable.cardiocovercorrida
    "Esteira Ergométrica" -> R.drawable.cardiocoveresteira
    "Caminhada" -> R.drawable.cardiocovercaminhada
    "Mountain bike" -> R.drawable.cardiocovermountainbike
    "Bicicleta pedal" -> R.drawable.cardiocoverbicicletapedal
    "Bicicleta ergométrica" -> R.drawable.cardiocoverbicicletaergometrica
    "Surf" -> R.drawable.cardiocoversurf
    "Kitesurf" -> R.drawable.cardiocoverkitesurf
    "Elíptico" -> R.drawable.cardiocovereliptico
    "Pular Corda" -> R.drawable.cardiocoverpularcorda
    "Escada" -> R.drawable.cardiocoverescada
    "Escalada" -> R.drawable.cardiocoverescalada
    "Remo" -> R.drawable.cardiocoverremo
    "Natação" -> R.drawable.cardiocovernatacao
    "Polichinelo" -> R.drawable.cardiocoverpolichinelo
    "Burpees" -> R.drawable.cardiocoverburpees
    "Luta" -> R.drawable.fightcoverluta
    else -> R.drawable.cardiocovercorrida
}
