package com.healthfit.android.ui.home

import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.healthfit.android.ui.components.GradientButton
import com.healthfit.designsystem.HealthFitColors
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun WorkoutFinishedScreen(session: FinishedWorkout, onClose: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var flyover by remember { mutableStateOf(false) }
    var saving by remember { mutableStateOf(false) }
    var loaded by remember { mutableStateOf<LoadedShare?>(null) }
    val mediaPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            val result = withContext(Dispatchers.Default) {
                runCatching { loadShare(context, uri, session) }
            }
            result.onSuccess { loaded = it }
                .onFailure { Toast.makeText(context, it.message ?: "Não foi possível abrir a mídia", Toast.LENGTH_LONG).show() }
        }
    }
    fun postCard(target: SharePublisher.Target) {
        if (saving) return
        saving = true
        scope.launch {
            val file = withContext(Dispatchers.Default) {
                runCatching {
                    val bitmap = ShareCardImage.render(context, session)
                    val written = ShareCardImage.writeTemp(context, bitmap, "HealthFit-Card")
                    bitmap.recycle()
                    written
                }
            }
            saving = false
            file.onSuccess { toastShare(context) { SharePublisher.post(context, it, "image/jpeg", target) } }
                .onFailure { Toast.makeText(context, it.message ?: "Não foi possível preparar o card", Toast.LENGTH_LONG).show() }
        }
    }
    fun saveCard() {
        if (saving) return
        saving = true
        scope.launch {
            val message = withContext(Dispatchers.Default) {
                runCatching {
                    val bitmap = ShareCardImage.render(context, session)
                    ShareCardImage.saveToGallery(context, bitmap, "HealthFit-${session.title}")
                    bitmap.recycle()
                    "Card salvo na galeria"
                }.getOrElse { it.message ?: "Não foi possível salvar o card" }
            }
            saving = false
            Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
        }
    }
    fun postLoaded(media: LoadedShare, target: SharePublisher.Target) {
        val (file, mime) = when (media) {
            is LoadedShare.Photo -> media.file to "image/jpeg"
            is LoadedShare.Video -> media.file to "video/mp4"
        }
        toastShare(context) { SharePublisher.post(context, file, mime, target) }
    }
    fun postCover(media: LoadedShare.Video, target: SharePublisher.Target) {
        if (saving) return
        saving = true
        scope.launch {
            val file = withContext(Dispatchers.Default) {
                runCatching { ShareCardImage.writeTemp(context, media.cover, "HealthFit-Capa") }
            }
            saving = false
            file.onSuccess { toastShare(context) { SharePublisher.post(context, it, "image/jpeg", target) } }
                .onFailure { Toast.makeText(context, it.message ?: "Não foi possível preparar a capa", Toast.LENGTH_LONG).show() }
        }
    }
    fun saveLoaded(media: LoadedShare) {
        if (saving) return
        saving = true
        scope.launch {
            val message = withContext(Dispatchers.Default) {
                runCatching {
                    when (media) {
                        is LoadedShare.Photo -> {
                            ShareCardImage.saveToGallery(context, media.bitmap, "HealthFit-Foto-${session.title}")
                            "Foto salva na galeria"
                        }
                        is LoadedShare.Video -> {
                            SharePublisher.saveVideo(context, media.file, "HealthFit-Video-${session.title}")
                            "Vídeo salvo na galeria"
                        }
                    }
                }.getOrElse { it.message ?: "Não foi possível salvar" }
            }
            saving = false
            Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
        }
    }
    BackHandler(onBack = if (flyover) ({ flyover = false }) else onClose)
    var effort by remember { mutableIntStateOf(7) }
    if (flyover) {
        FlyoverScreen(session, onBack = { flyover = false })
        return
    }
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp)
            .padding(bottom = 24.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "Treino Concluído",
                color = Color.White,
                fontWeight = FontWeight.Bold,
                fontSize = 18.sp,
                modifier = Modifier.weight(1f),
                textAlign = TextAlign.Center,
            )
        }
        Column(
            modifier = Modifier
                .padding(top = 12.dp)
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(HealthFitColors.CardBackground)
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Icon(Icons.Filled.CheckCircle, contentDescription = null, tint = HealthFitColors.Accent, modifier = Modifier.height(56.dp))
            Text(session.title, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 20.sp, textAlign = TextAlign.Center, modifier = Modifier.padding(top = 8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(24.dp), modifier = Modifier.padding(top = 14.dp)) {
                SummaryStat(session.duration, "Duração total")
                if (session.isCardio) {
                    session.calories?.let { SummaryStat("$it", "kcal") }
                } else {
                    SummaryStat("${session.completed}/${session.total}", "Exercícios")
                }
            }
        }
        Text("Como foi a intensidade?", color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 18.dp))
        Text("Toque de 1 (muito fácil) a 10 (máximo)", color = HealthFitColors.TextSecondary, fontSize = 12.sp)
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.padding(top = 8.dp)) {
            (1..10).forEach { value ->
                val selected = effort == value
                Text(
                    "$value",
                    color = if (selected) Color.Black else Color.White,
                    fontWeight = FontWeight.Bold,
                    fontSize = 13.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(10.dp))
                        .background(if (selected) effortColor(value) else HealthFitColors.CardBackground)
                        .clickable { effort = value }
                        .padding(vertical = 10.dp),
                )
            }
        }
        if (!session.isCardio) {
            Text("Tempo por Exercício", color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 18.dp, bottom = 8.dp))
            session.exercises.forEach { exercise ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 8.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(HealthFitColors.CardBackground)
                        .padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Filled.CheckCircle, contentDescription = null, tint = HealthFitColors.Accent)
                    Column(Modifier.weight(1f).padding(start = 10.dp)) {
                        Text(exercise.name, color = Color.White, fontWeight = FontWeight.Medium)
                        Text("${exercise.sets} séries · descanso ${exercise.rest}", color = HealthFitColors.TextSecondary, fontSize = 12.sp)
                    }
                    Text(exercise.elapsed, color = HealthFitColors.Accent, fontWeight = FontWeight.SemiBold)
                }
            }
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(HealthFitColors.CardBackground)
                    .padding(14.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.FitnessCenter, contentDescription = null, tint = Color.White)
                    Text("Tempo nos exercícios", color = Color.White, modifier = Modifier.weight(1f).padding(start = 8.dp))
                    Text(session.exerciseSeconds, color = Color.White, fontWeight = FontWeight.SemiBold)
                }
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 10.dp)) {
                    Icon(Icons.Filled.Timer, contentDescription = null, tint = Color.White)
                    Text("Descanso total", color = Color.White, modifier = Modifier.weight(1f).padding(start = 8.dp))
                    Text(session.restSeconds, color = HealthFitColors.AccentSecondary, fontWeight = FontWeight.SemiBold)
                }
            }
        }
        Text("Compartilhar conquista", color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 18.dp))
        Text(
            "Card pronto para Stories e status — WhatsApp ou Instagram.",
            color = HealthFitColors.TextSecondary,
            fontSize = 12.sp,
            modifier = Modifier.padding(bottom = 10.dp),
        )
        WorkoutShareCard(session)
        Spacer(Modifier.height(12.dp))
        ShareCommandButtons(
            saveLabel = "Salvar card na Galeria",
            busy = saving,
            onWhatsApp = { postCard(SharePublisher.Target.WhatsAppStatus) },
            onInstagram = { postCard(SharePublisher.Target.InstagramStories) },
            onSave = { saveCard() },
        )
        Spacer(Modifier.height(16.dp))
        Text("Foto ou vídeo do treino", color = Color.White, fontWeight = FontWeight.SemiBold)
        Text(
            "A mídia abre aqui no app, com os dados desta modalidade, para publicar ou salvar na galeria.",
            color = HealthFitColors.TextSecondary,
            fontSize = 12.sp,
            modifier = Modifier.padding(top = 4.dp, bottom = 10.dp),
        )
        loaded?.let { media ->
            LoadedSharePreview(media, session)
            Spacer(Modifier.height(10.dp))
            ShareCommandButtons(
                saveLabel = if (media is LoadedShare.Video) "Salvar vídeo na Galeria" else "Salvar foto na Galeria",
                busy = saving,
                onWhatsApp = { postLoaded(media, SharePublisher.Target.WhatsAppStatus) },
                onInstagram = { postLoaded(media, SharePublisher.Target.InstagramStories) },
                onSave = { saveLoaded(media) },
            )
            if (media is LoadedShare.Video) {
                Spacer(Modifier.height(8.dp))
                GradientButton("Postar capa com dados", onClick = { postCover(media, SharePublisher.Target.WhatsAppStatus) })
            }
            Spacer(Modifier.height(10.dp))
        }
        GradientButton(
            "Adicionar foto ou vídeo",
            onClick = {
                mediaPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageAndVideo))
            },
        )
        if (supportsFlyover(session)) {
            Spacer(Modifier.height(10.dp))
            GradientButton("Flyover 3D do percurso", onClick = { flyover = true })
        }
        Spacer(Modifier.height(16.dp))
        GradientButton("Fechar", onClick = onClose)
    }
}

private fun supportsFlyover(session: FinishedWorkout): Boolean {
    if (!session.isCardio) return false
    val title = session.title
    if (title.contains("ergométr", ignoreCase = true)) return false
    return listOf("Corrida", "Caminhada", "bike", "Bicicleta pedal", "Surf", "Kite", "Remo")
        .any { title.contains(it, ignoreCase = true) }
}

@Composable
private fun FlyoverScreen(session: FinishedWorkout, onBack: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var rendering by remember { mutableStateOf(false) }
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp)
            .padding(bottom = 24.dp),
    ) {
        Text(
            "Voltar",
            color = HealthFitColors.Accent,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(top = 8.dp).clickable(onClick = onBack),
        )
        Text("Flyover 3D do percurso", color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 8.dp))
        Text(
            "Sobrevoo com a marca HealthFit, distância e tempo da sessão. O vídeo pode ir para a galeria e para Stories ou WhatsApp.",
            color = HealthFitColors.TextSecondary,
            modifier = Modifier.padding(top = 6.dp, bottom = 12.dp),
        )
        WorkoutShareCard(session)
        Spacer(Modifier.height(16.dp))
        GradientButton(
            text = if (rendering) "Gerando vídeo…" else "Gerar vídeo",
            onClick = {
                if (rendering) return@GradientButton
                rendering = true
                scope.launch {
                    val result = withContext(Dispatchers.Default) {
                        runCatching {
                            val file = FlyoverVideo.render(
                                context,
                                session.title,
                                "Berg Limma",
                                session.durationMinutes,
                            )
                            FlyoverVideo.saveToGallery(context, file)
                            file
                        }
                    }
                    rendering = false
                    result.onSuccess { file ->
                        Toast.makeText(context, "Vídeo salvo em Filmes/HealthFit", Toast.LENGTH_SHORT).show()
                        runCatching { FlyoverVideo.share(context, file) }
                    }.onFailure {
                        Toast.makeText(context, it.message ?: "Não foi possível gerar o vídeo", Toast.LENGTH_LONG).show()
                    }
                }
            },
        )
    }
}

@Composable
private fun SummaryStat(value: String, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Text(label, color = HealthFitColors.TextSecondary, fontSize = 12.sp)
    }
}

private fun effortColor(value: Int): Color = when {
    value <= 3 -> Color(0xFF3DDC3A)
    value <= 6 -> Color(0xFFFFD60A)
    value <= 8 -> Color(0xFFFF8C33)
    else -> Color(0xFFFF453A)
}
