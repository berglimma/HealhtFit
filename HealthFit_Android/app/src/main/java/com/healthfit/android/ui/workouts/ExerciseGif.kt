package com.healthfit.android.ui.workouts

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Circle
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
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
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.ImageLoader
import coil.compose.AsyncImage
import coil.decode.ImageDecoderDecoder
import coil.request.ImageRequest
import com.healthfit.designsystem.HealthFitColors
import java.text.Normalizer

private const val GifCdn = "https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/"

fun gifImageLoader(context: Context): ImageLoader =
    ImageLoader.Builder(context)
        .components { add(ImageDecoderDecoder.Factory()) }
        .build()

object ExerciseGifCatalog {
    fun remoteUrl(exercise: WorkoutExercise): String = GifCdn + filePath(exercise)

    fun bundledUrl(exercise: WorkoutExercise): String =
        "file:///android_asset/gifs/${bundledName(exercise)}.gif"

    private fun filePath(exercise: WorkoutExercise): String {
        val name = fold(exercise.name)
        for ((keywords, path) in keywordPaths) {
            if (keywords.any { name.contains(it) }) return path
        }
        return when (exercise.muscle) {
            Muscle.chest -> "pectorals/barbell-bench-press.gif"
            Muscle.back -> "upper-back/barbell-bent-over-row.gif"
            Muscle.legs -> "glutes/barbell-full-squat.gif"
            Muscle.shoulders -> "delts/dumbbell-lateral-raise.gif"
            Muscle.arms -> "biceps/barbell-curl.gif"
            Muscle.core -> "abs/crunch-floor.gif"
            Muscle.fullBody -> "glutes/barbell-deadlift.gif"
        }
    }

    private fun bundledName(exercise: WorkoutExercise): String {
        val name = fold(exercise.name)
        return when {
            name.contains("triceps") || name.contains("mergulho") || name.contains("diamante") -> "triceps"
            name.contains("rosca") -> "biceps"
            name.contains("encolhimento") || name.contains("trapezio") -> "trapezio"
            name.contains("ombro") || name.contains("desenvolvimento") || name.contains("elevacao") -> "ombros"
            exercise.muscle == Muscle.chest -> "peito"
            exercise.muscle == Muscle.back -> "costas"
            exercise.muscle == Muscle.legs -> "pernas"
            exercise.muscle == Muscle.shoulders -> "ombros"
            exercise.muscle == Muscle.arms -> "bracos"
            exercise.muscle == Muscle.core -> "abdomen"
            else -> "corpo_inteiro"
        }
    }

    private fun fold(value: String): String =
        Normalizer.normalize(value, Normalizer.Form.NFD)
            .replace("\\p{Mn}+".toRegex(), "")
            .lowercase()

    private val keywordPaths = listOf(
        listOf("supino reto") to "pectorals/barbell-bench-press.gif",
        listOf("supino inclinado") to "pectorals/barbell-incline-bench-press.gif",
        listOf("supino declinado") to "pectorals/barbell-decline-bench-press.gif",
        listOf("crucifixo inverso") to "delts/lever-seated-reverse-fly.gif",
        listOf("crucifixo") to "pectorals/dumbbell-fly.gif",
        listOf("crossover", "cross over") to "pectorals/cable-standing-up-straight-crossovers.gif",
        listOf("voador") to "pectorals/lever-seated-fly.gif",
        listOf("flexao diamante") to "triceps/diamond-push-up.gif",
        listOf("flexao inclinada") to "pectorals/incline-push-up.gif",
        listOf("flexao") to "pectorals/push-up.gif",
        listOf("triceps corda", "triceps pulley", "triceps pushdown") to "triceps/cable-pushdown.gif",
        listOf("triceps testa") to "triceps/barbell-lying-triceps-extension-skull-crusher.gif",
        listOf("triceps frances") to "triceps/cable-overhead-triceps-extension-rope-attachment.gif",
        listOf("mergulho") to "triceps/bench-dip-knees-bent.gif",
        listOf("rosca martelo", "martelo") to "biceps/dumbbell-hammer-curl.gif",
        listOf("rosca") to "biceps/barbell-curl.gif",
        listOf("remada baixa") to "upper-back/cable-seated-row.gif",
        listOf("remada") to "upper-back/barbell-bent-over-row.gif",
        listOf("pulldown triangulo", "puxada triangulo") to "lats/cable-lateral-pulldown-with-v-bar.gif",
        listOf("puxada", "pulldown", "barra fixa") to "lats/cable-pulldown.gif",
        listOf("hip thrust", "elevacao pelvica") to "glutes/resistance-band-hip-thrusts-on-knees-female.gif",
        listOf("agachamento sumo", "sumo") to "glutes/smith-sumo-squat.gif",
        listOf("afundo") to "quads/dumbbell-single-leg-split-squat.gif",
        listOf("leg press") to "glutes/sled-45-leg-press.gif",
        listOf("agachamento") to "glutes/barbell-full-squat.gif",
        listOf("flexora") to "hamstrings/lever-lying-leg-curl.gif",
        listOf("extensora") to "quads/lever-leg-extension.gif",
        listOf("stiff") to "hamstrings/barbell-straight-leg-deadlift.gif",
        listOf("panturrilha") to "calves/lever-standing-calf-raise.gif",
        listOf("desenvolvimento", "elevacao lateral", "elevacao", "arnold") to "delts/dumbbell-lateral-raise.gif",
        listOf("encolhimento") to "traps/barbell-shrug.gif",
        listOf("face pull") to "delts/cable-standing-rear-delt-row-with-rope.gif",
        listOf("abdominal", "prancha", "mountain", "russian", "bicicleta") to "abs/crunch-floor.gif",
        listOf("polichinelo") to "cardio/star-jump-male.gif",
        listOf("ponte de gluteos") to "glutes/low-glute-bridge-on-floor.gif",
        listOf("superman") to "spine/hyperextension.gif",
        listOf("isometria") to "glutes/march-sit-wall.gif",
        listOf("burpee") to "glutes/barbell-deadlift.gif",
        listOf("alongamento de peito") to "pectorals/chest-and-front-of-shoulder-stretch.gif",
        listOf("alongamento de dorsal") to "lats/kneeling-lat-stretch.gif",
        listOf("alongamento de posterior") to "hamstrings/hamstring-stretch.gif",
        listOf("flexor de quadril") to "quads/intermediate-hip-flexor-and-quad-stretch.gif",
        listOf("alongamento de gluteo") to "glutes/seated-glute-stretch.gif",
        listOf("alongamento de triceps") to "triceps/overhead-triceps-stretch.gif",
        listOf("alongamento de panturrilha") to "calves/calf-stretch-with-hands-against-wall.gif",
        listOf("alongamento de pescoco") to "levator-scapulae/neck-side-stretch.gif",
        listOf("alongamento de coluna") to "spine/spine-stretch.gif",
        listOf("alongamento de costas") to "upper-back/upper-back-stretch.gif",
        listOf("alongamento mundial") to "hamstrings/world-greatest-stretch.gif",
        listOf("inchworm") to "abs/inchworm.gif",
        listOf("tornozelo") to "calves/ankle-circles.gif",
        listOf("punho") to "forearms/wrist-circles.gif",
        listOf("terra") to "glutes/barbell-deadlift.gif",
    )
}

@Composable
fun ExerciseGifCard(exercise: WorkoutExercise, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val loader = remember { gifImageLoader(context) }
    var useBundled by remember(exercise.name) { mutableStateOf(false) }
    var loaded by remember(exercise.name, useBundled) { mutableStateOf(false) }
    val model = if (useBundled) {
        ExerciseGifCatalog.bundledUrl(exercise)
    } else {
        ExerciseGifCatalog.remoteUrl(exercise)
    }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(HealthFitColors.CardBackground)
            .padding(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.FitnessCenter, contentDescription = null, tint = HealthFitColors.Accent, modifier = Modifier.size(16.dp))
            Text(
                "Demonstração",
                color = HealthFitColors.Accent,
                fontWeight = FontWeight.SemiBold,
                fontSize = 13.sp,
                modifier = Modifier.padding(start = 8.dp),
            )
            Spacer(Modifier.weight(1f))
            if (loaded) {
                Icon(Icons.Filled.Circle, contentDescription = null, tint = HealthFitColors.Accent, modifier = Modifier.size(8.dp))
                Text(" Ao vivo", color = HealthFitColors.Accent, fontSize = 11.sp)
            }
        }
        Text(exercise.name, color = Color.White, fontWeight = FontWeight.Medium, fontSize = 14.sp, modifier = Modifier.padding(top = 6.dp))
        Spacer(Modifier.height(10.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(240.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(Color(0xFF141618)),
            contentAlignment = Alignment.Center,
        ) {
            AsyncImage(
                model = ImageRequest.Builder(context).data(model).crossfade(true).build(),
                imageLoader = loader,
                contentDescription = exercise.name,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Fit,
                onSuccess = { loaded = true },
                onError = {
                    loaded = false
                    if (!useBundled) useBundled = true
                },
            )
            if (!loaded) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    CircularProgressIndicator(color = HealthFitColors.Accent, modifier = Modifier.size(28.dp), strokeWidth = 2.dp)
                    Text(
                        "Carregando demonstração...",
                        color = Color.White.copy(alpha = 0.7f),
                        fontSize = 12.sp,
                        modifier = Modifier.padding(top = 8.dp),
                    )
                }
            }
        }
    }
}
