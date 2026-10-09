package com.healthfit.android.ui.home

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Bluetooth
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Watch
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import android.content.Context
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.healthfit.android.ui.components.DarkCard
import com.healthfit.designsystem.HealthFitColors

@Composable
fun DashboardLowerSections(
    onOpenRecent: (FinishedWorkout) -> Unit = {},
    onOpenReport: (ReportKind) -> Unit = {},
    weeklySeen: Boolean = false,
) {
    Spacer(Modifier.height(12.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        ReportTile(
            "Relatório Semanal",
            "Veja seu progresso da semana",
            showNew = !weeklySeen,
            tint = HealthFitColors.Accent,
            icon = Icons.Filled.BarChart,
            modifier = Modifier.weight(1f),
            onClick = { onOpenReport(ReportKind.Weekly) },
        )
        ReportTile(
            "Relatório Mensal",
            "Próximo relatório em 2 dias",
            showNew = false,
            tint = HealthFitColors.AccentSecondary,
            icon = Icons.Filled.Watch,
            modifier = Modifier.weight(1f),
            onClick = { onOpenReport(ReportKind.Monthly) },
        )
    }
    Spacer(Modifier.height(12.dp))
    MotivationBanner()
    Spacer(Modifier.height(12.dp))
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var loaded by remember { mutableStateOf<LoadedShare?>(null) }
    var posting by remember { mutableStateOf(false) }
    val photoPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            val result = withContext(Dispatchers.Default) {
                runCatching { loadShare(context, uri, DemoSessions.strength) }
            }
            result.onSuccess { loaded = it }
                .onFailure { Toast.makeText(context, it.message ?: "Não foi possível abrir a mídia", Toast.LENGTH_LONG).show() }
        }
    }
    var expandedSlot by remember { mutableStateOf<String?>(null) }
    ExpandableShareSlot(
        title = "Último card individual",
        subtitle = "Militar Masculino E — Peito Ombros Tríceps (Cabo) · 08 out. 2026 · 19:58",
        icon = Icons.Filled.FitnessCenter,
        expanded = expandedSlot == "individual",
        onToggle = { expandedSlot = if (expandedSlot == "individual") null else "individual" },
    ) {
        WorkoutShareCard(DemoSessions.strength)
    }
    ShareCommandButtons(
        saveLabel = "Salvar card na Galeria",
        busy = posting,
        onWhatsApp = {
            postHomeCard(context, scope, DemoSessions.strength, SharePublisher.Target.WhatsAppStatus) { posting = it }
        },
        onInstagram = {
            postHomeCard(context, scope, DemoSessions.strength, SharePublisher.Target.InstagramStories) { posting = it }
        },
        onSave = {
            posting = true
            scope.launch {
                val message = withContext(Dispatchers.Default) {
                    runCatching {
                        val bitmap = ShareCardImage.render(context, DemoSessions.strength)
                        ShareCardImage.saveToGallery(context, bitmap, "HealthFit-Card")
                        bitmap.recycle()
                        "Card salvo na galeria"
                    }.getOrElse { it.message ?: "Não foi possível salvar o card" }
                }
                posting = false
                Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
            }
        },
    )
    Text(
        "Adicionar foto ou vídeo",
        color = HealthFitColors.Accent,
        fontWeight = FontWeight.SemiBold,
        fontSize = 14.sp,
        modifier = Modifier
            .padding(top = 8.dp)
            .clickable {
                photoPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageAndVideo))
            },
    )
    loaded?.let { media ->
        Spacer(Modifier.height(8.dp))
        LoadedSharePreview(media, DemoSessions.strength)
        Spacer(Modifier.height(8.dp))
        ShareCommandButtons(
            saveLabel = if (media is LoadedShare.Video) "Salvar vídeo na Galeria" else "Salvar foto na Galeria",
            busy = posting,
            onWhatsApp = {
                val (file, mime) = when (media) {
                    is LoadedShare.Photo -> media.file to "image/jpeg"
                    is LoadedShare.Video -> media.file to "video/mp4"
                }
                toastShare(context) { SharePublisher.post(context, file, mime, SharePublisher.Target.WhatsAppStatus) }
            },
            onInstagram = {
                val (file, mime) = when (media) {
                    is LoadedShare.Photo -> media.file to "image/jpeg"
                    is LoadedShare.Video -> media.file to "video/mp4"
                }
                toastShare(context) { SharePublisher.post(context, file, mime, SharePublisher.Target.InstagramStories) }
            },
            onSave = {
                posting = true
                scope.launch {
                    val message = withContext(Dispatchers.Default) {
                        runCatching {
                            when (media) {
                                is LoadedShare.Photo -> {
                                    ShareCardImage.saveToGallery(context, media.bitmap, "HealthFit-Foto-Treino")
                                    "Foto salva na galeria"
                                }
                                is LoadedShare.Video -> {
                                    SharePublisher.saveVideo(context, media.file, "HealthFit-Video-Treino")
                                    "Vídeo salvo na galeria"
                                }
                            }
                        }.getOrElse { it.message ?: "Não foi possível salvar" }
                    }
                    posting = false
                    Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
                }
            },
        )
    }
    Text(
        "A foto leva HealthFit e os dados da modalidade. Musculação mostra exercícios; corrida mostra km e ritmo.",
        color = Color(0xFF8E989F),
        fontSize = 12.sp,
        modifier = Modifier.padding(top = 4.dp, bottom = 4.dp),
    )
    Spacer(Modifier.height(12.dp))
    ExpandableShareSlot(
        title = "Último card em grupo",
        subtitle = "Nenhum card de grupo ainda. Ative o modo equipe e finalize um treino para postar.",
        icon = Icons.Filled.Groups,
        expanded = expandedSlot == "group",
        onToggle = { expandedSlot = if (expandedSlot == "group") null else "group" },
    ) {
        Text(
            "Ative o modo equipe e finalize um treino em conjunto para gerar este card.",
            color = Color(0xFFB7C0C8),
            fontSize = 13.sp,
            modifier = Modifier.padding(top = 12.dp),
        )
    }
    Spacer(Modifier.height(16.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        MetricTile(Icons.Filled.DirectionsWalk, "0", "Passos", HealthFitColors.Accent, Modifier.weight(1f))
        MetricTile(Icons.Filled.LocalFireDepartment, "0", "Calorias", Color(0xFFFF9A3C), Modifier.weight(1f))
        MetricTile(Icons.Filled.Favorite, "87", "BPM", Color(0xFFFF4D4D), Modifier.weight(1f))
    }
    Spacer(Modifier.height(14.dp))
    WeeklyChart()
    Spacer(Modifier.height(8.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        MetricTile(Icons.Filled.DirectionsWalk, "6142", "Média Passos", HealthFitColors.Accent, Modifier.weight(1f))
        MetricTile(Icons.Filled.LocalFireDepartment, "3860", "Total Calorias", Color(0xFFFF9A3C), Modifier.weight(1f))
        MetricTile(Icons.Filled.Favorite, "72", "FC Média", HealthFitColors.Accent, Modifier.weight(1f))
    }
    Spacer(Modifier.height(16.dp))
    SectionTitle("Desempenho Carga Treinos")
    Spacer(Modifier.height(8.dp))
    LoadChart()
    Spacer(Modifier.height(12.dp))
    DarkCard {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Watch, contentDescription = null, tint = HealthFitColors.Accent)
            Column(Modifier.weight(1f).padding(start = 10.dp)) {
                Text("Galaxy Watch7", color = Color.White, fontWeight = FontWeight.SemiBold)
                Text("Conectado · Toque para sincronizar", color = Color(0xFF8E989F), fontSize = 12.sp)
            }
            Box(Modifier.size(10.dp).clip(CircleShape).background(HealthFitColors.Accent))
        }
    }
    Spacer(Modifier.height(8.dp))
    DarkCard {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Bluetooth, contentDescription = null, tint = Color(0xFFFF9A3C))
            Column(Modifier.weight(1f).padding(start = 10.dp)) {
                Text("Sensor Bluetooth", color = Color.White, fontWeight = FontWeight.SemiBold)
                Text("Passos/kcal via Health Connect · toque para parear BPM", color = Color(0xFF8E989F), fontSize = 12.sp)
            }
            Icon(Icons.Filled.ChevronRight, contentDescription = null, tint = Color(0xFF8E989F))
        }
    }
    Spacer(Modifier.height(16.dp))
    SectionTitle("Treinos Recentes")
    Spacer(Modifier.height(8.dp))
    DemoSessions.all.forEach { session ->
        RecentRow(session, onClick = { onOpenRecent(session) })
    }
}

@Composable
private fun ReportTile(
    title: String,
    subtitle: String,
    showNew: Boolean,
    tint: Color,
    icon: ImageVector,
    modifier: Modifier,
    onClick: () -> Unit,
) {
    Column(
        modifier = modifier
            .height(96.dp)
            .clip(RoundedCornerShape(18.dp))
            .background(HealthFitColors.CardBackground)
            .border(1.dp, Color.White.copy(alpha = 0.05f), RoundedCornerShape(18.dp))
            .clickable(onClick = onClick)
            .padding(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(32.dp).clip(CircleShape).background(tint.copy(alpha = 0.2f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(16.dp))
            }
            if (showNew) {
                Text(
                    " NOVO",
                    color = Color.White,
                    fontSize = 9.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier
                        .padding(start = 6.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(tint)
                        .padding(horizontal = 4.dp, vertical = 1.dp),
                )
            }
            Spacer(Modifier.weight(1f))
            Icon(Icons.Filled.ChevronRight, contentDescription = null, tint = Color(0xFF8E989F), modifier = Modifier.size(14.dp))
        }
        Text(title, color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 13.sp, modifier = Modifier.padding(top = 6.dp), maxLines = 1)
        Text(subtitle, color = Color(0xFF8E989F), fontSize = 11.sp, maxLines = 2)
    }
}

@Composable
private fun MotivationBanner() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .background(Brush.linearGradient(listOf(Color(0xFF143D24), Color(0xFF121A16))))
            .border(1.dp, HealthFitColors.Accent.copy(alpha = 0.22f), RoundedCornerShape(22.dp))
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Filled.BarChart, contentDescription = null, tint = HealthFitColors.Accent)
        Column(Modifier.weight(1f).padding(horizontal = 10.dp)) {
            Text("Força não é sorte. É repetição com intenção.", color = Color.White, fontWeight = FontWeight.Bold)
            Text("Cada repetição é um voto no seu objetivo.", color = Color(0xFFB7C0C8), fontSize = 13.sp)
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(Icons.Filled.Favorite, contentDescription = null, tint = HealthFitColors.Accent)
            Text("BORA!", color = HealthFitColors.Accent, fontWeight = FontWeight.Bold, fontSize = 11.sp)
        }
    }
}

@Composable
private fun ExpandableShareSlot(
    title: String,
    subtitle: String,
    icon: ImageVector,
    expanded: Boolean,
    onToggle: () -> Unit,
    content: @Composable () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(HealthFitColors.CardBackground)
            .border(1.dp, Color.White.copy(alpha = 0.05f), RoundedCornerShape(20.dp))
            .clickable(onClick = onToggle)
            .padding(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(44.dp).clip(CircleShape).background(HealthFitColors.Accent.copy(alpha = 0.2f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(icon, contentDescription = null, tint = HealthFitColors.Accent)
            }
            Column(Modifier.weight(1f).padding(horizontal = 10.dp)) {
                Text(title, color = Color.White, fontWeight = FontWeight.SemiBold)
                Text(subtitle, color = Color(0xFFB7C0C8), fontSize = 12.sp)
            }
            Icon(
                if (expanded) Icons.Filled.KeyboardArrowUp else Icons.Filled.KeyboardArrowDown,
                contentDescription = if (expanded) "Recolher" else "Expandir",
                tint = Color(0xFF8E989F),
            )
        }
        AnimatedVisibility(
            visible = expanded,
            enter = expandVertically() + fadeIn(),
            exit = shrinkVertically() + fadeOut(),
        ) {
            Column(Modifier.fillMaxWidth()) {
                content()
            }
        }
    }
}

@Composable
private fun MetricTile(icon: ImageVector, value: String, label: String, tint: Color, modifier: Modifier) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(16.dp))
            .background(HealthFitColors.CardBackground)
            .padding(vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            Modifier.size(32.dp).clip(CircleShape).background(tint.copy(alpha = 0.16f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(16.dp))
        }
        Text(value, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp, modifier = Modifier.padding(top = 6.dp))
        Text(label, color = Color(0xFF8E989F), fontSize = 11.sp)
    }
}

@Composable
private fun WeeklyChart() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(HealthFitColors.CardBackground)
            .padding(14.dp),
    ) {
        Row {
            Text("Desempenho Semanal", color = Color.White, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
            Text("Treino (min)", color = HealthFitColors.Accent, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
        }
        val values = listOf(0f, 0f, 0.72f, 0.84f, 0.18f, 1f, 0f)
        val labels = listOf("sáb.", "dom.", "seg.", "ter.", "qua.", "qui.", "sex.")
        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(140.dp)
                .padding(top = 12.dp),
        ) {
            val gap = 10.dp.toPx()
            val barW = (size.width - gap * (values.size - 1)) / values.size
            values.forEachIndexed { index, value ->
                val x = index * (barW + gap)
                drawRoundRect(
                    color = Color.White.copy(alpha = 0.06f),
                    topLeft = Offset(x, 0f),
                    size = Size(barW, size.height),
                    cornerRadius = CornerRadius(10f, 10f),
                )
                val h = (size.height * value).coerceAtLeast(if (value > 0f) 8f else 0f)
                if (h > 0f) {
                    drawRoundRect(
                        brush = Brush.verticalGradient(
                            listOf(Color(0xFF8CFF86), Color(0xFF1FAE3A)),
                            startY = size.height - h,
                            endY = size.height,
                        ),
                        topLeft = Offset(x, size.height - h),
                        size = Size(barW, h),
                        cornerRadius = CornerRadius(10f, 10f),
                    )
                }
            }
        }
        Row(Modifier.fillMaxWidth()) {
            labels.forEach { label ->
                Text(label, color = Color(0xFF8E989F), fontSize = 10.sp, modifier = Modifier.weight(1f), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
            }
        }
    }
}

@Composable
private fun LoadChart() {
    val stacks = listOf(
        listOf(0.35f to Color(0xFF3DDC3A)),
        listOf(0.45f to Color(0xFFE8E8E8), 0.18f to Color(0xFFFF9A3C), 0.22f to Color(0xFF3DDC3A)),
        listOf(0.55f to Color(0xFF3DDC3A), 0.2f to Color(0xFFFF9A3C)),
        listOf(0.28f to Color(0xFF3DDC3A), 0.42f to Color(0xFFFF9A3C)),
    )
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(HealthFitColors.CardBackground)
            .padding(14.dp),
    ) {
        Canvas(Modifier.fillMaxWidth().height(120.dp)) {
            val gap = 18.dp.toPx()
            val barW = (size.width - gap * (stacks.size - 1)) / stacks.size
            stacks.forEachIndexed { index, parts ->
                var y = size.height
                parts.forEach { (fraction, color) ->
                    val h = size.height * fraction
                    y -= h
                    drawRoundRect(
                        color = color,
                        topLeft = Offset(index * (barW + gap), y),
                        size = Size(barW, h),
                        cornerRadius = CornerRadius(4f, 4f),
                    )
                }
            }
        }
        Text("27 de set.", color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 8.dp))
        Text("Pernas    11.690 kg", color = Color(0xFFFF9A3C), fontSize = 13.sp)
        Text("Costas    2.640 kg", color = HealthFitColors.Accent, fontSize = 13.sp)
    }
}

@Composable
private fun SectionTitle(text: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            Modifier
                .width(3.dp)
                .height(16.dp)
                .clip(RoundedCornerShape(2.dp))
                .background(HealthFitColors.Accent),
        )
        Text(
            text,
            color = Color.White,
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(start = 8.dp),
        )
    }
}

@Composable
private fun RecentRow(session: FinishedWorkout, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 8.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(HealthFitColors.CardBackground)
            .clickable(onClick = onClick)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Image(
            painter = painterResource(session.coverRes),
            contentDescription = null,
            modifier = Modifier
                .size(52.dp)
                .clip(RoundedCornerShape(12.dp)),
            contentScale = ContentScale.Crop,
        )
        Column(Modifier.weight(1f).padding(start = 10.dp)) {
            Text(session.title, color = Color.White, fontWeight = FontWeight.SemiBold)
            Text(session.whenLabel, color = Color(0xFF8E989F), fontSize = 12.sp)
        }
        Column(horizontalAlignment = Alignment.End) {
            Text(session.durationMinutes, color = HealthFitColors.Accent, fontWeight = FontWeight.Bold)
            session.calories?.let { Text("$it kcal", color = Color(0xFF8E989F), fontSize = 12.sp) }
        }
        Icon(Icons.Filled.ChevronRight, contentDescription = null, tint = Color(0xFF8E989F))
    }
}

private fun postHomeCard(
    context: Context,
    scope: CoroutineScope,
    session: FinishedWorkout,
    target: SharePublisher.Target,
    posting: (Boolean) -> Unit,
) {
    posting(true)
    scope.launch {
        val file = withContext(Dispatchers.Default) {
            runCatching {
                val bitmap = ShareCardImage.render(context, session)
                val written = ShareCardImage.writeTemp(context, bitmap, "HealthFit-Card")
                bitmap.recycle()
                written
            }
        }
        posting(false)
        file.onSuccess { toastShare(context) { SharePublisher.post(context, it, "image/jpeg", target) } }
            .onFailure { Toast.makeText(context, it.message ?: "Não foi possível preparar o card", Toast.LENGTH_LONG).show() }
    }
}
