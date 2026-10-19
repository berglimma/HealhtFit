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
import androidx.compose.material.icons.filled.ImageNotSupported
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
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
import coil.decode.GifDecoder
import coil.decode.ImageDecoderDecoder
import coil.request.ImageRequest
import coil.request.SuccessResult
import com.healthfit.designsystem.HealthFitColors
import java.io.File
import java.text.Normalizer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Host primário: raw.githubusercontent (jsDelivr responde 403 em vários arquivos).
 * UI mostra o GIF local **na hora** e só troca para o remoto se carregar rápido.
 */
private const val GifCdnPrimary = "https://raw.githubusercontent.com/JahelCuadrado/ExerciseGymGifsDB/main/"
private const val GifCdnMirror = "https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/"

fun gifImageLoader(context: Context): ImageLoader =
    ImageLoader.Builder(context.applicationContext)
        .components {
            add(ImageDecoderDecoder.Factory())
            add(GifDecoder.Factory())
        }
        .build()

object ExerciseGifCatalog {
    fun remoteUrl(exercise: WorkoutExercise, mirror: Boolean = false): String {
        val base = if (mirror) GifCdnMirror else GifCdnPrimary
        return base + filePath(exercise)
    }

    fun bundledFile(context: Context, exercise: WorkoutExercise): File {
        val name = bundledName(exercise)
        val out = File(context.cacheDir, "exercise_gifs/$name.gif")
        if (!out.exists() || out.length() == 0L) {
            out.parentFile?.mkdirs()
            context.assets.open("gifs/$name.gif").use { input ->
                out.outputStream().use { output -> input.copyTo(output) }
            }
        }
        return out
    }

    fun filePath(exercise: WorkoutExercise): String {
        exactPaths[exercise.name]?.let { return it }
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
            name.contains("burpee") || name.contains("mountain") || name.contains("polichinelo") ||
                name.contains("thruster") || name.contains("kettlebell") -> "corpo_inteiro"
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

    private val exactPaths = mapOf(
        "Agachamento Livre" to "glutes/barbell-full-squat.gif",
        "Flexão de Braços" to "pectorals/push-up.gif",
        "Afundo" to "glutes/dumbbell-lunge.gif",
        "Afundo Búlgaro" to "quads/dumbbell-single-leg-split-squat.gif",
        "Mergulho no Banco" to "triceps/bench-dip-knees-bent.gif",
        "Prancha" to "abs/front-plank-with-twist.gif",
        "Prancha Lateral" to "abs/bodyweight-incline-side-plank.gif",
        "Mountain Climber" to "cardio/mountain-climber.gif",
        "Burpee" to "cardio/burpee.gif",
        "Polichinelo" to "cardio/star-jump-male.gif",
        "Ponte de Glúteos" to "glutes/low-glute-bridge-on-floor.gif",
        "Superman" to "spine/hyperextension.gif",
        "Isometria na Parede" to "glutes/march-sit-wall.gif",
        "Flexão Diamante" to "triceps/diamond-push-up.gif",
        "Flexão Inclinada" to "pectorals/incline-push-up.gif",
        "Abdominal Bicicleta" to "abs/air-bike.gif",
        "Abdominal Crunch" to "abs/band-bicycle-crunch.gif",
        "Russian Twist" to "abs/russian-twist.gif",
        "Elevação de Pernas" to "abs/hanging-leg-raise.gif",
        "Inchworm" to "abs/inchworm.gif",
        "Alongamento Mundial" to "hamstrings/world-greatest-stretch.gif",
        "Agachamento Sumô" to "glutes/smith-sumo-squat.gif",
        "Panturrilha Corporal" to "calves/bodyweight-standing-calf-raise.gif",
        "Círculos de Braços" to "delts/weighted-round-arm.gif",
        "Círculos de Tornozelo" to "calves/ankle-circles.gif",
        "Círculos de Punho" to "forearms/wrist-circles.gif",
        "Supino Reto" to "pectorals/barbell-bench-press.gif",
        "Supino Inclinado" to "pectorals/barbell-incline-bench-press.gif",
        "Remada Curvada" to "upper-back/barbell-bent-over-row.gif",
        "Puxada Frontal" to "lats/cable-pulldown.gif",
        "Leg Press 45°" to "glutes/sled-45-leg-press.gif",
        "Desenvolvimento com Halteres" to "delts/dumbbell-seated-shoulder-press.gif",
        "Elevação Lateral" to "delts/dumbbell-lateral-raise.gif",
        "Rosca Direta" to "biceps/barbell-curl.gif",
        "Tríceps Pulley" to "triceps/cable-pushdown.gif",
        "Elevação Pélvica (Hip Thrust)" to "glutes/resistance-band-hip-thrusts-on-knees-female.gif",
        "Stiff" to "glutes/barbell-romanian-deadlift.gif",
        "Cadeira Abdutora" to "abductors/lever-seated-hip-abduction.gif",
        "Cadeira Adutora" to "adductors/lever-seated-hip-adduction.gif",
        "Remada Unilateral" to "upper-back/dumbbell-bent-over-row.gif",
        "Abdominal Oblíquo" to "abs/russian-twist.gif",
        "Bicicleta no Ar" to "abs/air-bike.gif",
        "Kettlebell Swing" to "glutes/barbell-deadlift.gif",
    )

    private val keywordPaths = listOf(
        listOf("supino reto") to "pectorals/barbell-bench-press.gif",
        listOf("supino inclinado") to "pectorals/barbell-incline-bench-press.gif",
        listOf("flexao diamante") to "triceps/diamond-push-up.gif",
        listOf("flexao") to "pectorals/push-up.gif",
        listOf("mergulho") to "triceps/bench-dip-knees-bent.gif",
        listOf("rosca") to "biceps/barbell-curl.gif",
        listOf("remada") to "upper-back/barbell-bent-over-row.gif",
        listOf("puxada", "pulldown") to "lats/cable-pulldown.gif",
        listOf("hip thrust", "elevacao pelvica") to "glutes/resistance-band-hip-thrusts-on-knees-female.gif",
        listOf("agachamento sumo", "sumo") to "glutes/smith-sumo-squat.gif",
        listOf("afundo bulgaro") to "quads/dumbbell-single-leg-split-squat.gif",
        listOf("afundo") to "glutes/dumbbell-lunge.gif",
        listOf("leg press") to "glutes/sled-45-leg-press.gif",
        listOf("agachamento") to "glutes/barbell-full-squat.gif",
        listOf("mountain climber", "mountain") to "cardio/mountain-climber.gif",
        listOf("burpee") to "cardio/burpee.gif",
        listOf("polichinelo") to "cardio/star-jump-male.gif",
        listOf("prancha") to "abs/front-plank-with-twist.gif",
        listOf("abdominal", "crunch", "russian", "bicicleta") to "abs/crunch-floor.gif",
        listOf("desenvolvimento", "elevacao lateral") to "delts/dumbbell-lateral-raise.gif",
        listOf("triceps") to "triceps/cable-pushdown.gif",
        listOf("stiff") to "glutes/barbell-romanian-deadlift.gif",
        listOf("terra", "kettlebell") to "glutes/barbell-deadlift.gif",
    )
}

@Composable
fun ExerciseGifCard(exercise: WorkoutExercise, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val loader = remember { gifImageLoader(context) }
    val bundled = remember(exercise.name) { ExerciseGifCatalog.bundledFile(context, exercise) }
    // Começa no local → aparece na hora; remoto só substitui se carregar.
    var model by remember(exercise.name) { mutableStateOf<Any>(bundled) }
    var loaded by remember(exercise.name) { mutableStateOf(false) }
    var failed by remember(exercise.name) { mutableStateOf(false) }

    LaunchedEffect(exercise.name) {
        loaded = false
        failed = false
        model = bundled
        val upgraded = withContext(Dispatchers.IO) {
            val urls = listOf(
                ExerciseGifCatalog.remoteUrl(exercise, mirror = false),
                ExerciseGifCatalog.remoteUrl(exercise, mirror = true),
            )
            for (url in urls) {
                val ok = runCatching {
                    val req = ImageRequest.Builder(context)
                        .data(url)
                        .allowHardware(false)
                        .build()
                    loader.execute(req) is SuccessResult
                }.getOrDefault(false)
                if (ok) return@withContext url
            }
            null
        }
        if (upgraded != null) {
            model = upgraded
        }
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
                model = ImageRequest.Builder(context)
                    .data(model)
                    .crossfade(false)
                    .allowHardware(false)
                    .build(),
                imageLoader = loader,
                contentDescription = exercise.name,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Fit,
                onSuccess = {
                    loaded = true
                    failed = false
                },
                onError = {
                    if (model != bundled) {
                        model = bundled
                    } else {
                        failed = true
                        loaded = false
                    }
                },
            )
            when {
                failed -> {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(
                            Icons.Filled.ImageNotSupported,
                            null,
                            tint = Color.White.copy(alpha = 0.55f),
                            modifier = Modifier.size(28.dp),
                        )
                        Text(
                            "Demonstração indisponível",
                            color = Color.White.copy(alpha = 0.7f),
                            fontSize = 12.sp,
                            modifier = Modifier.padding(top = 8.dp),
                        )
                    }
                }
                !loaded -> {
                    CircularProgressIndicator(
                        color = HealthFitColors.Accent,
                        modifier = Modifier.size(28.dp),
                        strokeWidth = 2.dp,
                    )
                }
            }
        }
    }
}
