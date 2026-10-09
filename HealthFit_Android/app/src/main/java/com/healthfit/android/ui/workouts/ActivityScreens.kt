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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.healthfit.android.R
import com.healthfit.android.ui.components.GradientButton
import com.healthfit.android.workout.WorkoutPresence
import com.healthfit.android.ui.home.FinishedWorkout
import com.healthfit.designsystem.HealthFitColors
import kotlinx.coroutines.delay

data class FightStyle(
    val name: String,
    val summary: String,
    val reference: String,
    val kcalPerMin: Int,
    val rounds: List<String>,
    val accent: Color,
)

val FightStyles = listOf(
    FightStyle("Boxe", "Trocação de mãos com esquiva e trabalho de pernas", "Rounds de 3 min · 1 min de descanso", 13, listOf("3 rounds", "5 rounds", "10 rounds"), Color(0xFFD13338)),
    FightStyle("Muay Thai", "Oito armas: punhos, cotovelos, joelhos e canelas", "5 rounds de 3 min · 2 min de descanso", 14, listOf("3 rounds", "5 rounds"), Color(0xFFE56B26)),
    FightStyle("Kickboxing", "Punhos e chutes em ritmo contínuo", "3 rounds de 3 min · 1 min de descanso", 13, listOf("3 rounds", "5 rounds"), Color(0xFFE05259)),
    FightStyle("MMA", "Trocação, quedas e chão no mesmo combate", "3 a 5 rounds de 5 min · 1 min de descanso", 15, listOf("3 rounds", "5 rounds"), Color(0xFF8C2947)),
    FightStyle("Jiu-Jitsu", "Solo, raspagens e finalizações", "Luta única de 5 a 10 min", 11, listOf("5 min", "8 min", "10 min"), Color(0xFF3873C7)),
    FightStyle("Judô", "Pegada, desequilíbrio e projeções", "Luta de 4 min · golden score se empatar", 12, listOf("4 min", "5 min"), Color(0xFF4D8CE0)),
    FightStyle("Wrestling", "Quedas, controle e domínio no solo", "2 rounds de 3 min · 30 s de descanso", 13, listOf("2 rounds", "3 rounds"), Color(0xFF6B7A9E)),
    FightStyle("Luta Livre", "Submissão sem kimono, foco em pegadas", "Luta única de 6 a 10 min", 12, listOf("6 min", "8 min", "10 min"), Color(0xFF61948C)),
    FightStyle("Karatê", "Golpes lineares com entrada e recuo explosivos", "Combate de 3 min", 10, listOf("3 min", "5 min"), Color(0xFFB89E4D)),
    FightStyle("Taekwondo", "Chutes altos, giros e mobilidade de quadril", "3 rounds de 2 min · 1 min de descanso", 11, listOf("3 rounds", "5 rounds"), Color(0xFF599E6B)),
    FightStyle("Krav Magá", "Defesa pessoal com respostas curtas e diretas", "Blocos de 2 a 3 min por cenário", 12, listOf("2 min", "3 min"), Color(0xFF736B85)),
    FightStyle("Capoeira", "Ginga, esquiva e movimentos acrobáticos", "Roda contínua, sem round fixo", 11, listOf("Roda livre", "10 min", "20 min"), Color(0xFFD99433)),
)

val MeditationTopics = listOf(
    "Respiração Consciente" to "Respiração calma para começar ou fechar o dia",
    "Relaxamento Corporal" to "Solte a tensão dos pés até a cabeça",
    "Gratidão" to "Três coisas boas do dia, com calma",
    "Foco e Clareza" to "Sessão curta para clareza antes do treino",
    "Redução de Ansiedade" to "Expire mais longo que a inspiração",
    "Sono e Descanso" to "Relaxe o corpo depois do treino",
    "Recuperação Pós-Treino" to "Recupere a frequência e a atenção",
)
fun meditationCover(title: String): Int = when {
    title.contains("Relaxamento") -> R.drawable.meditacaocoverrelaxamento
    title.contains("Gratidão") -> R.drawable.meditacaocovergratidao
    title.contains("Foco") -> R.drawable.meditacaocoverfoco
    title.contains("Ansiedade") -> R.drawable.meditacaocoveransiedade
    title.contains("Sono") -> R.drawable.meditacaocoversono
    title.contains("Recuperação") -> R.drawable.meditacaocoverrecuperacao
    else -> R.drawable.meditacaocoverrespiracao
}
@Composable
fun LiveActivityScreen(
    title: String,
    detail: String,
    onClose: (elapsedSeconds: Int) -> Unit,
) {
    var elapsed by remember { mutableIntStateOf(0) }
    var paused by remember { mutableStateOf(false) }
    LaunchedEffect(paused) {
        while (!paused) {
            delay(1000)
            elapsed += 1
        }
    }
    BackHandler { onClose(elapsed) }
    WorkoutPresence(
        workoutTitle = detail,
        exerciseName = title,
        setsLabel = if (paused) "Pausado" else detail,
        elapsedSeconds = elapsed,
        resting = paused,
    )
    Column(
        Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp)
            .padding(top = 24.dp),
    ) {
        Text(detail, color = HealthFitColors.TextSecondary, fontSize = 13.sp)
        Text(title, color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
        Text(
            "%02d:%02d".format(elapsed / 60, elapsed % 60),
            color = HealthFitColors.Accent,
            fontSize = 64.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(vertical = 18.dp),
        )
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            GradientButton(
                text = if (paused) "Retomar" else "Pausar",
                onClick = { paused = !paused },
                icon = if (paused) Icons.Filled.PlayArrow else Icons.Filled.Pause,
                modifier = Modifier.weight(1f),
            )
        }
        Spacer(Modifier.height(10.dp))
        Text(
            "Encerrar",
            color = Color.White,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(Color(0xFF3A1818))
                .clickable { onClose(elapsed) }
                .padding(vertical = 16.dp),
        )
    }
}

fun finishedActivity(title: String, elapsed: Int, cardio: Boolean, cover: Int): FinishedWorkout {
    val minutes = (elapsed / 60).coerceAtLeast(1)
    val clock = "%d:%02d".format(elapsed / 60, elapsed % 60)
    return FinishedWorkout(
        title = title,
        cardDate = "AGORA",
        whenLabel = "Agora",
        duration = clock,
        durationMinutes = "$minutes min",
        calories = if (cardio) minutes * 8 else null,
        motivation = "Cada sessão conta.",
        isCardio = cardio,
        coverRes = cover,
        completed = 1,
        total = 1,
        exercises = emptyList(),
        recentMinutes = listOf(minutes),
    )
}
