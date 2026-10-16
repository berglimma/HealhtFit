package com.healthfit.android.ui.home

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.net.Uri
import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Bed
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Circle
import androidx.compose.material.icons.filled.Photo
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import com.healthfit.android.R
import com.healthfit.designsystem.HealthFitColors
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

@Composable
fun ConstancyCard(onOpen: () -> Unit) {
    val context = LocalContext.current
    val cal = remember { Calendar.getInstance() }
    val year = cal.get(Calendar.YEAR)
    val month = cal.get(Calendar.MONTH)
    val trained = remember(year, month) {
        ConstancyStore.trainedDayKeysInMonth(context, year, month).size
    }
    val restDays = remember(year, month) {
        countRestDaysInMonth(context, year, month)
    }
    val todayRest = ConstancyStore.isTodayRestDay(context)
    val recentPhotos = remember {
        ConstancyStore.loadSessions(context)
            .asReversed()
            .mapNotNull { it.photoPath }
            .distinct()
            .take(5)
            .mapNotNull { path ->
                val file = File(path)
                if (!file.exists()) return@mapNotNull null
                BitmapFactory.decodeFile(path)?.asImageBitmap()
            }
    }
    val summary = buildString {
        append("$trained dia${if (trained == 1) "" else "s"} este mês")
        append(" · ")
        append(if (restDays > 0) "$restDays descanso" else "fotos e descanso")
    }
    val footer = when {
        todayRest -> "Descanso hoje"
        recentPhotos.isEmpty() -> "Anexe fotos"
        else -> "${recentPhotos.size} com foto"
    }

    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .clickable(onClick = onOpen),
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .height(180.dp),
        ) {
            Image(
                painter = painterResource(R.drawable.constancycover),
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
            )
            Box(
                Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            listOf(Color.Black.copy(alpha = 0.08f), Color.Black.copy(alpha = 0.78f)),
                        ),
                    ),
            )
            Column(
                Modifier
                    .align(Alignment.BottomStart)
                    .padding(16.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.CalendarMonth, null, tint = HealthFitColors.Accent, modifier = Modifier.size(16.dp))
                    Text(
                        "CALENDÁRIO",
                        color = HealthFitColors.Accent,
                        fontWeight = FontWeight.Bold,
                        fontSize = 11.sp,
                        modifier = Modifier.padding(start = 6.dp),
                    )
                }
                Text(
                    "Constância",
                    color = Color.White,
                    fontWeight = FontWeight.Bold,
                    fontSize = 22.sp,
                    modifier = Modifier.padding(top = 6.dp),
                )
                Text(
                    "Calendário de treinos · $summary",
                    color = Color.White.copy(alpha = 0.88f),
                    fontSize = 12.sp,
                    modifier = Modifier.padding(top = 4.dp),
                )
                Text(
                    footer,
                    color = Color.White.copy(alpha = 0.9f),
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 11.sp,
                    modifier = Modifier.padding(top = 8.dp),
                )
            }
        }
        if (recentPhotos.isNotEmpty()) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .background(HealthFitColors.CardBackground)
                    .padding(horizontal = 12.dp, vertical = 10.dp),
            ) {
                recentPhotos.forEach { bmp ->
                    Image(
                        bitmap = bmp,
                        contentDescription = null,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier
                            .size(52.dp)
                            .clip(RoundedCornerShape(10.dp)),
                    )
                }
            }
        }
    }
}

@Composable
fun ConstancyCalendarScreen(onBack: () -> Unit) {
    BackHandler(onBack = onBack)
    val context = LocalContext.current
    val locale = Locale("pt", "BR")
    var visible by remember { mutableStateOf(Calendar.getInstance().apply { set(Calendar.DAY_OF_MONTH, 1) }) }
    var selectedDay by remember { mutableStateOf<String?>(null) }
    var tick by remember { mutableStateOf(0) }

    val year = visible.get(Calendar.YEAR)
    val month = visible.get(Calendar.MONTH)
    val monthTitle = remember(year, month) {
        SimpleDateFormat("MMMM yyyy", locale).format(visible.time).replaceFirstChar { it.titlecase(locale) }
    }
    val trainedKeys = remember(year, month, tick) { ConstancyStore.trainedDayKeysInMonth(context, year, month) }
    val restCount = remember(year, month, tick) { countRestDaysInMonth(context, year, month) }
    val isCurrentOrFuture = remember(year, month) {
        val now = Calendar.getInstance()
        year > now.get(Calendar.YEAR) || (year == now.get(Calendar.YEAR) && month >= now.get(Calendar.MONTH))
    }

    Column(
        Modifier
            .fillMaxSize()
            .background(HealthFitColors.Background)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp, bottom = 12.dp)) {
            Icon(
                Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = "Voltar",
                tint = Color.White,
                modifier = Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .clickable(onClick = onBack)
                    .padding(8.dp),
            )
            Text("Calendário de treinos", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
        }

        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowLeft,
                null,
                tint = Color.White,
                modifier = Modifier
                    .size(36.dp)
                    .clickable {
                        visible = (visible.clone() as Calendar).apply { add(Calendar.MONTH, -1) }
                        selectedDay = null
                    },
            )
            Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                Text(monthTitle, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                Text(
                    "${trainedKeys.size} dia${if (trainedKeys.size == 1) "" else "s"} treinado${if (trainedKeys.size == 1) "" else "s"}" +
                        if (restCount > 0) " · $restCount descanso" else "",
                    color = HealthFitColors.TextSecondary,
                    fontSize = 12.sp,
                )
            }
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                null,
                tint = if (isCurrentOrFuture) HealthFitColors.TextSecondary.copy(alpha = 0.35f) else Color.White,
                modifier = Modifier
                    .size(36.dp)
                    .then(
                        if (isCurrentOrFuture) Modifier
                        else Modifier.clickable {
                            visible = (visible.clone() as Calendar).apply { add(Calendar.MONTH, 1) }
                            selectedDay = null
                        },
                    ),
            )
        }

        Spacer(Modifier.height(12.dp))
        WeekdayHeader()
        Spacer(Modifier.height(6.dp))
        MonthGrid(
            year = year,
            month = month,
            trainedKeys = trainedKeys,
            selectedDay = selectedDay,
            onSelect = { selectedDay = it },
            refreshKey = tick,
        )
        Spacer(Modifier.height(14.dp))
        LegendRow()
        Spacer(Modifier.height(14.dp))
        selectedDay?.let { day ->
            DayDetail(
                dayKey = day,
                refreshKey = tick,
                onRestToggle = {
                    ConstancyStore.setRestDay(context, day, it)
                    tick++
                },
                onPhotoChanged = { tick++ },
            )
        } ?: Text(
            "Toque em um dia com treino ou descanso para ver detalhes.",
            color = HealthFitColors.TextSecondary,
            fontSize = 12.sp,
        )
        Spacer(Modifier.height(28.dp))
    }
}

@Composable
private fun WeekdayHeader() {
    val symbols = listOf("D", "S", "T", "Q", "Q", "S", "S")
    Row(Modifier.fillMaxWidth()) {
        symbols.forEach {
            Text(
                it,
                color = HealthFitColors.TextSecondary,
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                textAlign = TextAlign.Center,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun MonthGrid(
    year: Int,
    month: Int,
    trainedKeys: Set<String>,
    selectedDay: String?,
    onSelect: (String) -> Unit,
    refreshKey: Int,
) {
    val context = LocalContext.current
    val cells = remember(year, month) { monthCells(year, month) }
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        cells.chunked(7).forEach { week ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                week.forEach { cell ->
                    Box(Modifier.weight(1f).aspectRatio(1f)) {
                        if (cell != null) {
                            val key = cell
                            val trained = trainedKeys.contains(key)
                            val rest = ConstancyStore.isRestDay(context, key) // refreshKey used to invalidate
                            @Suppress("UNUSED_EXPRESSION")
                            refreshKey
                            val photo = ConstancyStore.photoPathOnDay(context, key)
                            val today = key == ConstancyStore.dayKey()
                            val selected = key == selectedDay
                            DayCell(
                                dayNumber = key.takeLast(2).toIntOrNull() ?: 1,
                                trained = trained,
                                rest = rest,
                                photoPath = photo,
                                today = today,
                                selected = selected,
                                onClick = { onSelect(key) },
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DayCell(
    dayNumber: Int,
    trained: Boolean,
    rest: Boolean,
    photoPath: String?,
    today: Boolean,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val bitmap = remember(photoPath) {
        photoPath?.let { runCatching { BitmapFactory.decodeFile(it) }.getOrNull() }
    }
    Box(
        Modifier
            .fillMaxSize()
            .clip(RoundedCornerShape(10.dp))
            .background(
                when {
                    bitmap != null -> Color.Transparent
                    trained -> HealthFitColors.Accent.copy(alpha = 0.22f)
                    rest -> HealthFitColors.AccentSecondary.copy(alpha = 0.18f)
                    else -> HealthFitColors.CardBackground.copy(alpha = 0.55f)
                },
            )
            .border(
                width = when {
                    selected -> 2.dp
                    today -> 1.dp
                    else -> 0.dp
                },
                color = when {
                    selected -> HealthFitColors.Accent
                    today -> HealthFitColors.Accent.copy(alpha = 0.7f)
                    else -> Color.Transparent
                },
                shape = RoundedCornerShape(10.dp),
            )
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        if (bitmap != null) {
            Image(
                bitmap = bitmap.asImageBitmap(),
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
            )
            Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.25f)))
        }
        Text(
            "$dayNumber",
            color = Color.White,
            fontWeight = FontWeight.SemiBold,
            fontSize = 13.sp,
            modifier = Modifier.align(if (bitmap != null) Alignment.BottomStart else Alignment.Center)
                .padding(if (bitmap != null) 4.dp else 0.dp),
        )
        if (rest && bitmap == null && !trained) {
            Icon(
                Icons.Filled.Bed,
                null,
                tint = HealthFitColors.AccentSecondary,
                modifier = Modifier.size(14.dp).align(Alignment.TopEnd).padding(4.dp),
            )
        } else if (rest) {
            Icon(
                Icons.Filled.Bed,
                null,
                tint = HealthFitColors.AccentSecondary,
                modifier = Modifier.size(12.dp).align(Alignment.TopEnd).padding(3.dp),
            )
        } else if (trained && bitmap == null) {
            Box(
                Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 4.dp)
                    .size(5.dp)
                    .clip(CircleShape)
                    .background(HealthFitColors.Accent),
            )
        }
    }
}

@Composable
private fun LegendRow() {
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        LegendItem(Icons.Filled.Photo, "Com foto")
        LegendItem(Icons.Filled.Circle, "Treino")
        LegendItem(Icons.Filled.Bed, "Descanso")
    }
}

@Composable
private fun LegendItem(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, tint = HealthFitColors.TextSecondary, modifier = Modifier.size(12.dp))
        Text(label, color = HealthFitColors.TextSecondary, fontSize = 11.sp, modifier = Modifier.padding(start = 4.dp))
    }
}

@Composable
private fun DayDetail(
    dayKey: String,
    refreshKey: Int,
    onRestToggle: (Boolean) -> Unit,
    onPhotoChanged: () -> Unit,
) {
    val context = LocalContext.current
    @Suppress("UNUSED_EXPRESSION")
    refreshKey
    val sessions = ConstancyStore.sessionsOnDay(context, dayKey)
    val rest = ConstancyStore.isRestDay(context, dayKey)
    var pickForSessionId by remember { mutableStateOf<String?>(null) }
    var showSourceDialog by remember { mutableStateOf(false) }
    var pendingCameraUri by remember { mutableStateOf<Uri?>(null) }

    fun applyPhoto(uri: Uri) {
        val path = ConstancyStore.saveAndAttachPhoto(
            context = context,
            source = uri,
            sessionId = pickForSessionId,
            dayKey = dayKey,
        )
        if (path == null) {
            Toast.makeText(context, "Não foi possível salvar a foto", Toast.LENGTH_SHORT).show()
        } else {
            Toast.makeText(context, "Foto adicionada ao calendário", Toast.LENGTH_SHORT).show()
            onPhotoChanged()
        }
        pickForSessionId = null
        showSourceDialog = false
    }

    val gallery = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) applyPhoto(uri)
    }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { ok ->
        val uri = pendingCameraUri
        pendingCameraUri = null
        if (ok && uri != null) applyPhoto(uri)
    }
    val cameraPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (!granted) {
            Toast.makeText(context, "Permita a câmera para tirar a foto", Toast.LENGTH_SHORT).show()
            return@rememberLauncherForActivityResult
        }
        launchCheckInCamera(context) { uri ->
            pendingCameraUri = uri
            camera.launch(uri)
        }
    }

    fun openCamera() {
        val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
        if (granted) {
            launchCheckInCamera(context) { uri ->
                pendingCameraUri = uri
                camera.launch(uri)
            }
        } else {
            cameraPermission.launch(Manifest.permission.CAMERA)
        }
    }

    if (showSourceDialog) {
        AlertDialog(
            onDismissRequest = { showSourceDialog = false; pickForSessionId = null },
            title = { Text("Foto do treino") },
            text = { Text("A foto aparece no dia do treino no calendário.") },
            confirmButton = {
                TextButton(onClick = {
                    showSourceDialog = false
                    gallery.launch("image/*")
                }) { Text("Galeria") }
            },
            dismissButton = {
                Row {
                    TextButton(onClick = {
                        showSourceDialog = false
                        openCamera()
                    }) { Text("Câmera") }
                    TextButton(onClick = { showSourceDialog = false; pickForSessionId = null }) {
                        Text("Cancelar")
                    }
                }
            },
        )
    }

    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(HealthFitColors.CardBackground)
            .padding(14.dp),
    ) {
        Text(dayKey, color = Color.White, fontWeight = FontWeight.Bold)
        if (rest) {
            Text("Dia de descanso", color = HealthFitColors.AccentSecondary, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 6.dp))
            Text(
                "Nenhum treino — recuperação conta na constância.",
                color = HealthFitColors.TextSecondary,
                fontSize = 12.sp,
                modifier = Modifier.padding(top = 4.dp),
            )
        } else if (sessions.isEmpty()) {
            Text("Nenhum treino neste dia.", color = HealthFitColors.TextSecondary, fontSize = 12.sp, modifier = Modifier.padding(top = 6.dp))
        } else {
            sessions.forEach { s ->
                SessionPhotoRow(
                    session = s,
                    onAddPhoto = {
                        pickForSessionId = s.id
                        showSourceDialog = true
                    },
                )
            }
        }
        Spacer(Modifier.height(10.dp))
        Text(
            "Adicionar foto do dia",
            color = HealthFitColors.Accent,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier
                .clip(RoundedCornerShape(10.dp))
                .clickable {
                    pickForSessionId = sessions.firstOrNull()?.id
                    showSourceDialog = true
                }
                .padding(vertical = 8.dp),
        )
        Text(
            if (rest) "Remover descanso" else "Marcar como descanso",
            color = HealthFitColors.Accent,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier
                .clip(RoundedCornerShape(10.dp))
                .clickable { onRestToggle(!rest) }
                .padding(vertical = 8.dp),
        )
    }
}

@Composable
private fun SessionPhotoRow(session: ConstancySession, onAddPhoto: () -> Unit) {
    val bitmap = remember(session.photoPath) {
        session.photoPath?.let { runCatching { BitmapFactory.decodeFile(it) }.getOrNull() }
    }
    Row(
        Modifier
            .fillMaxWidth()
            .padding(top = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .size(56.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(HealthFitColors.Accent.copy(alpha = 0.18f)),
            contentAlignment = Alignment.Center,
        ) {
            if (bitmap != null) {
                Image(
                    bitmap = bitmap.asImageBitmap(),
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize(),
                )
            } else {
                Icon(Icons.Filled.Photo, null, tint = HealthFitColors.Accent)
            }
        }
        Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
            Text(session.title, color = Color.White, fontWeight = FontWeight.SemiBold, maxLines = 2)
            Text(session.kind, color = HealthFitColors.TextSecondary, fontSize = 12.sp)
        }
        Icon(
            Icons.Filled.CameraAlt,
            contentDescription = if (bitmap == null) "Adicionar foto" else "Trocar foto",
            tint = HealthFitColors.Accent,
            modifier = Modifier
                .size(36.dp)
                .clip(CircleShape)
                .background(HealthFitColors.Accent.copy(alpha = 0.14f))
                .clickable(onClick = onAddPhoto)
                .padding(8.dp),
        )
    }
}

private fun launchCheckInCamera(context: android.content.Context, onReady: (Uri) -> Unit) {
    val dir = File(context.cacheDir, "checkin_camera").apply { mkdirs() }
    val file = File(dir, "cam_${System.currentTimeMillis()}.jpg")
    val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
    onReady(uri)
}

private fun monthCells(year: Int, month: Int): List<String?> {
    val cal = Calendar.getInstance().apply {
        set(Calendar.YEAR, year)
        set(Calendar.MONTH, month)
        set(Calendar.DAY_OF_MONTH, 1)
    }
    val firstDow = cal.get(Calendar.DAY_OF_WEEK) // 1=Sun
    val offset = firstDow - Calendar.SUNDAY
    val daysInMonth = cal.getActualMaximum(Calendar.DAY_OF_MONTH)
    val cells = MutableList<String?>(offset) { null }
    for (d in 1..daysInMonth) {
        cells += "%04d-%02d-%02d".format(year, month + 1, d)
    }
    while (cells.size % 7 != 0) cells += null
    return cells
}

private fun countRestDaysInMonth(context: android.content.Context, year: Int, month: Int): Int {
    val cal = Calendar.getInstance().apply {
        set(Calendar.YEAR, year)
        set(Calendar.MONTH, month)
        set(Calendar.DAY_OF_MONTH, 1)
    }
    val days = cal.getActualMaximum(Calendar.DAY_OF_MONTH)
    var count = 0
    for (d in 1..days) {
        val key = "%04d-%02d-%02d".format(year, month + 1, d)
        if (ConstancyStore.isRestDay(context, key)) count++
    }
    return count
}
