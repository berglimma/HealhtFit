package com.healthfit.android.ui.profile

import android.content.Intent
import android.net.Uri
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AddAPhoto
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
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
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import coil.compose.AsyncImage
import com.healthfit.android.ui.components.DarkCard
import com.healthfit.designsystem.HealthFitColors
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun BodyEvolutionScreen(
    athleteName: String,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var status by remember { mutableStateOf(BodyEvolutionStore.statusLabel(context)) }
    var phase by remember { mutableStateOf(BodyEvolutionStore.cyclePhase(context)) }
    var evaluations by remember { mutableStateOf(BodyEvolutionStore.loadEvaluations(context)) }
    var saving by remember { mutableStateOf(false) }
    var infoMessage by remember { mutableStateOf<String?>(null) }
    var result by remember { mutableStateOf<BodyEvolutionComparisonResult?>(null) }
    var pendingSlot by remember { mutableStateOf<BodyPhotoSlot?>(null) }
    var showSourceDialog by remember { mutableStateOf(false) }
    val draftPaths = remember { mutableStateMapOf<BodyPhotoSlot, String>() }

    fun refresh() {
        status = BodyEvolutionStore.statusLabel(context)
        phase = BodyEvolutionStore.cyclePhase(context)
        evaluations = BodyEvolutionStore.loadEvaluations(context)
    }

    LaunchedEffect(Unit) {
        BodyEvolutionStore.loadDraftPaths(context).forEach { (slot, path) ->
            draftPaths[slot] = path
        }
        refresh()
    }

    val galleryPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        val slot = pendingSlot ?: return@rememberLauncherForActivityResult
        pendingSlot = null
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            runCatching {
                withContext(Dispatchers.IO) {
                    BodyEvolutionStore.savePickedUri(
                        context,
                        uri,
                        slot,
                        BodyEvolutionStore.draftWorkingDir(context),
                    )
                }
            }.onSuccess { file ->
                draftPaths[slot] = file.absolutePath
            }.onFailure {
                infoMessage = it.message ?: "Não foi possível usar a foto."
            }
        }
    }

    val cameraUri = remember { mutableStateOf<Uri?>(null) }
    val cameraPicker = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { ok ->
        val slot = pendingSlot
        val uri = cameraUri.value
        pendingSlot = null
        if (!ok || slot == null || uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            runCatching {
                withContext(Dispatchers.IO) {
                    BodyEvolutionStore.savePickedUri(
                        context,
                        uri,
                        slot,
                        BodyEvolutionStore.draftWorkingDir(context),
                    )
                }
            }.onSuccess { file ->
                draftPaths[slot] = file.absolutePath
            }.onFailure {
                infoMessage = it.message ?: "Não foi possível usar a foto."
            }
        }
    }

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
    ) {
        Text(
            "Voltar",
            color = HealthFitColors.Accent,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.clickable(onClick = onBack),
        )
        Spacer(Modifier.height(12.dp))
        Text("Evolução Corporal", color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)

        Spacer(Modifier.height(16.dp))
        SectionLabel("Status")
        DarkCard {
            Text(status, color = Color(0xFFB7C0C8), fontSize = 14.sp)
            Text(
                "O relatório educativo usa as medidas do Perfil. As fotos abaixo são opcionais e reforçam o antes/depois.",
                color = Color(0xFF8E989F),
                fontSize = 12.sp,
                modifier = Modifier.padding(top = 8.dp),
            )
            Text(
                "${draftPaths.size}/6 fotos (opcional)",
                color = HealthFitColors.Accent,
                fontWeight = FontWeight.SemiBold,
                fontSize = 14.sp,
                modifier = Modifier.padding(top = 8.dp),
            )
        }

        Spacer(Modifier.height(16.dp))
        SectionLabel("Fotos (opcional e privado)")
        DarkCard {
            PhotoGrid(
                draftPaths = draftPaths,
                onAdd = { slot ->
                    pendingSlot = slot
                    showSourceDialog = true
                },
                onRemove = { slot -> draftPaths.remove(slot) },
            )
            Text(
                "Como adicionar: toque em cada ângulo (até 6). É opcional e privado — só você vê.\n" +
                    "Fluxo: salve o lote inicial → aguarde 30 dias → adicione um novo lote e compare.\n" +
                    "Depois da comparação, as fotos antigas são excluídas. Os PDFs das 4 últimas avaliações ficam neste aparelho.",
                color = Color(0xFF8E989F),
                fontSize = 12.sp,
                modifier = Modifier.padding(top = 10.dp),
            )
        }

        Spacer(Modifier.height(16.dp))
        SectionLabel("Ações")
        DarkCard {
            when (phase) {
                is BodyEvolutionCyclePhase.Empty, is BodyEvolutionCyclePhase.Waiting -> {
                    ActionButton(
                        title = if (phase is BodyEvolutionCyclePhase.Empty) {
                            "Iniciar acompanhamento"
                        } else {
                            "Atualizar lote (fotos opcionais)"
                        },
                        enabled = !saving,
                    ) {
                        saving = true
                        scope.launch {
                            runCatching {
                                withContext(Dispatchers.IO) {
                                    BodyEvolutionStore.saveBaseline(context, draftPaths.toMap())
                                }
                            }.onSuccess {
                                refresh()
                                infoMessage =
                                    "Acompanhamento iniciado. Fotos são opcionais e só você pode vê-las. Em 30 dias você poderá comparar a evolução."
                            }.onFailure {
                                infoMessage = it.message
                            }
                            saving = false
                        }
                    }
                }
                is BodyEvolutionCyclePhase.ReadyToCompare -> {
                    ActionButton(
                        title = "Comparar evolução",
                        enabled = !saving,
                    ) {
                        saving = true
                        scope.launch {
                            runCatching {
                                withContext(Dispatchers.IO) {
                                    BodyEvolutionStore.compare(
                                        context = context,
                                        athleteName = athleteName,
                                        draftPaths = draftPaths.toMap(),
                                    )
                                }
                            }.onSuccess { comparisonResult ->
                                draftPaths.clear()
                                comparisonResult.currentImages.forEach { (slot, path) ->
                                    draftPaths[slot] = path
                                }
                                result = comparisonResult
                                refresh()
                            }.onFailure {
                                infoMessage = it.message
                            }
                            saving = false
                        }
                    }
                    Text(
                        "Fotos novas são opcionais. A comparação usa as medidas do Perfil; se houver fotos, o antes/depois fica só para você.",
                        color = Color(0xFF8E989F),
                        fontSize = 12.sp,
                        modifier = Modifier.padding(top = 8.dp),
                    )
                }
            }
            if (saving) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.padding(top = 12.dp),
                ) {
                    CircularProgressIndicator(
                        color = HealthFitColors.Accent,
                        modifier = Modifier.size(18.dp),
                        strokeWidth = 2.dp,
                    )
                    Text(
                        "Salvando…",
                        color = Color(0xFFB7C0C8),
                        fontSize = 13.sp,
                        modifier = Modifier.padding(start = 8.dp),
                    )
                }
            }
        }

        if (evaluations.isNotEmpty()) {
            Spacer(Modifier.height(16.dp))
            SectionLabel("Últimas avaliações (PDF)")
            DarkCard {
                evaluations.forEach { evaluation ->
                    Column(Modifier.padding(vertical = 6.dp)) {
                        Text(
                            formatDate(evaluation.createdAtMillis),
                            color = Color.White,
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 14.sp,
                        )
                        Text(
                            evaluation.summaryText,
                            color = Color(0xFF8E989F),
                            fontSize = 12.sp,
                            maxLines = 3,
                            modifier = Modifier.padding(top = 4.dp),
                        )
                        Text(
                            "Salvar / compartilhar PDF",
                            color = HealthFitColors.Accent,
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 13.sp,
                            modifier = Modifier
                                .padding(top = 6.dp)
                                .clickable {
                                    val uri = BodyEvolutionStore.sharePdfUri(context, evaluation.id)
                                    if (uri == null) {
                                        Toast.makeText(context, "PDF ainda não disponível.", Toast.LENGTH_SHORT).show()
                                    } else {
                                        val intent = Intent(Intent.ACTION_SEND).apply {
                                            type = "application/pdf"
                                            putExtra(Intent.EXTRA_STREAM, uri)
                                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                        }
                                        context.startActivity(Intent.createChooser(intent, "Compartilhar PDF"))
                                    }
                                },
                        )
                    }
                }
            }
        }
        Spacer(Modifier.height(24.dp))
    }

    if (showSourceDialog) {
        AlertDialog(
            onDismissRequest = {
                showSourceDialog = false
                pendingSlot = null
            },
            title = { Text("Adicionar foto") },
            text = { Text("Escolha a origem da foto para ${pendingSlot?.title.orEmpty()}.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showSourceDialog = false
                        galleryPicker.launch(
                            PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly),
                        )
                    },
                ) { Text("Galeria") }
            },
            dismissButton = {
                TextButton(
                    onClick = {
                        showSourceDialog = false
                        val slot = pendingSlot ?: return@TextButton
                        val draft = File(BodyEvolutionStore.draftWorkingDir(context), "camera_${slot.key}.jpg")
                        draft.parentFile?.mkdirs()
                        if (!draft.exists()) draft.createNewFile()
                        val uri = androidx.core.content.FileProvider.getUriForFile(
                            context,
                            "${context.packageName}.fileprovider",
                            draft,
                        )
                        cameraUri.value = uri
                        cameraPicker.launch(uri)
                    },
                ) { Text("Câmera") }
            },
        )
    }

    infoMessage?.let { msg ->
        AlertDialog(
            onDismissRequest = { infoMessage = null },
            title = { Text("Aviso") },
            text = { Text(msg) },
            confirmButton = {
                TextButton(onClick = { infoMessage = null }) { Text("OK") }
            },
        )
    }

    result?.let { comparison ->
        BodyEvolutionResultDialog(
            result = comparison,
            onDismiss = { result = null },
        )
    }
}

@Composable
private fun BodyEvolutionResultDialog(
    result: BodyEvolutionComparisonResult,
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current
    val hasPhotos = result.previousImages.isNotEmpty() || result.currentImages.isNotEmpty()

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false),
    ) {
        Column(
            Modifier
                .fillMaxSize()
                .background(HealthFitColors.Background)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    "Resultado",
                    color = Color.White,
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f),
                )
                Text(
                    "Fechar",
                    color = HealthFitColors.Accent,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.clickable(onClick = onDismiss),
                )
            }
            Spacer(Modifier.height(12.dp))
            DarkCard {
                Text(result.deletionNotice, color = HealthFitColors.Accent, fontSize = 13.sp)
            }
            Spacer(Modifier.height(12.dp))
            Text("Resumo", color = Color.White, fontWeight = FontWeight.Bold)
            Text(
                result.evaluation.summaryText,
                color = Color(0xFFB7C0C8),
                fontSize = 14.sp,
                modifier = Modifier.padding(top = 6.dp),
            )

            val comparison = result.measurementComparison
            if (comparison != null && comparison.changes.isNotEmpty()) {
                Spacer(Modifier.height(16.dp))
                Text("Medidas que variaram", color = Color.White, fontWeight = FontWeight.Bold)
                comparison.changes.forEach { change ->
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .padding(top = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(Modifier.weight(1f)) {
                            Text(change.label, color = Color.White, fontWeight = FontWeight.SemiBold)
                            Text(
                                "${BodyMeasurements.formatCm(change.previous)} → ${BodyMeasurements.formatCm(change.current)}",
                                color = Color(0xFF8E989F),
                                fontSize = 12.sp,
                            )
                        }
                        Text(
                            BodyMeasurements.formatDelta(change.delta),
                            color = if (change.delta < 0) HealthFitColors.Accent else Color(0xFFFF9F0A),
                            fontWeight = FontWeight.Bold,
                        )
                    }
                }
            }

            if (hasPhotos) {
                Spacer(Modifier.height(16.dp))
                Text("Antes × Depois", color = Color.White, fontWeight = FontWeight.Bold)
                BodyPhotoSlot.entries.forEach { slot ->
                    val before = result.previousImages[slot]
                    val after = result.currentImages[slot]
                    if (before != null || after != null) {
                        Text(
                            slot.title,
                            color = Color.White,
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 13.sp,
                            modifier = Modifier.padding(top = 10.dp, bottom = 6.dp),
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            ResultThumb(before, "Antes", Modifier.weight(1f))
                            ResultThumb(after, "Depois", Modifier.weight(1f))
                        }
                    }
                }
            }

            Spacer(Modifier.height(16.dp))
            ActionButton(
                title = if (hasPhotos) "Compartilhar PDF" else "Salvar / compartilhar PDF",
                enabled = true,
            ) {
                val uri = BodyEvolutionStore.sharePdfUri(context, result.evaluation.id)
                if (uri == null) {
                    Toast.makeText(context, "PDF ainda não disponível.", Toast.LENGTH_SHORT).show()
                } else {
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "application/pdf"
                        putExtra(Intent.EXTRA_STREAM, uri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    context.startActivity(Intent.createChooser(intent, "Compartilhar PDF"))
                }
            }
            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun ResultThumb(path: String?, caption: String, modifier: Modifier = Modifier) {
    Column(modifier) {
        Box(
            Modifier
                .fillMaxWidth()
                .aspectRatio(3f / 4f)
                .clip(RoundedCornerShape(10.dp))
                .background(Color(0xFF1C2228)),
            contentAlignment = Alignment.Center,
        ) {
            if (path != null) {
                AsyncImage(
                    model = File(path),
                    contentDescription = caption,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize(),
                )
            } else {
                Text("—", color = Color(0xFF8E989F))
            }
        }
        Text(caption, color = Color(0xFF8E989F), fontSize = 11.sp, modifier = Modifier.padding(top = 4.dp))
    }
}

@Composable
private fun PhotoGrid(
    draftPaths: Map<BodyPhotoSlot, String>,
    onAdd: (BodyPhotoSlot) -> Unit,
    onRemove: (BodyPhotoSlot) -> Unit,
) {
    val rows = BodyPhotoSlot.entries.chunked(3)
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        rows.forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
                row.forEach { slot ->
                    PhotoCell(
                        slot = slot,
                        path = draftPaths[slot],
                        onAdd = { onAdd(slot) },
                        onRemove = { onRemove(slot) },
                        modifier = Modifier.weight(1f),
                    )
                }
                repeat(3 - row.size) {
                    Spacer(Modifier.weight(1f))
                }
            }
        }
    }
}

@Composable
private fun PhotoCell(
    slot: BodyPhotoSlot,
    path: String?,
    onAdd: () -> Unit,
    onRemove: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            Modifier
                .fillMaxWidth()
                .aspectRatio(3f / 4f)
                .clip(RoundedCornerShape(10.dp))
                .background(Color(0xFF1C2228))
                .clickable(onClick = onAdd),
            contentAlignment = Alignment.Center,
        ) {
            if (path != null) {
                AsyncImage(
                    model = File(path),
                    contentDescription = slot.title,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize(),
                )
                Icon(
                    Icons.Filled.Close,
                    contentDescription = "Remover",
                    tint = Color.White,
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(4.dp)
                        .size(22.dp)
                        .clip(RoundedCornerShape(11.dp))
                        .background(Color.Black.copy(alpha = 0.55f))
                        .clickable(onClick = onRemove)
                        .padding(3.dp),
                )
            } else {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Filled.AddAPhoto, contentDescription = null, tint = Color(0xFF8E989F))
                    Text("Adicionar", color = Color(0xFF8E989F), fontSize = 10.sp)
                }
            }
        }
        Text(
            slot.title,
            color = Color.White,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            modifier = Modifier.padding(top = 4.dp),
        )
    }
}

@Composable
private fun SectionLabel(text: String) {
    Text(
        text.uppercase(Locale.getDefault()),
        color = Color(0xFF8E989F),
        fontSize = 12.sp,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier.padding(bottom = 8.dp),
    )
}

@Composable
private fun ActionButton(title: String, enabled: Boolean, onClick: () -> Unit) {
    Text(
        title,
        color = Color.White,
        fontWeight = FontWeight.Bold,
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(if (enabled) HealthFitColors.Accent else Color(0xFF3A4148))
            .clickable(enabled = enabled, onClick = onClick)
            .padding(vertical = 12.dp)
            .padding(horizontal = 8.dp),
        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
    )
}

private fun formatDate(millis: Long): String {
    val df = SimpleDateFormat("dd MMM yyyy HH:mm", Locale("pt", "BR"))
    return df.format(Date(millis))
}
