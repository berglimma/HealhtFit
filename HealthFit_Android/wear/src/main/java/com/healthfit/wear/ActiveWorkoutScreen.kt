package com.healthfit.wear

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.pager.VerticalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.material.ChipDefaults
import androidx.wear.compose.material.CircularProgressIndicator
import androidx.wear.compose.material.Text
import kotlinx.coroutines.delay

private enum class ActivePage { Metrics, Water, SpotBuddy, Controls }

@Composable
fun ActiveWorkoutScreen() {
    val session by LocalWatchSession.state.collectAsState()
    val current = session ?: return
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        while (true) {
            now = System.currentTimeMillis()
            LocalWatchSession.tick(now)
            delay(1000)
        }
    }

    val pages = buildList {
        add(ActivePage.Metrics)
        if (current.isWaterSport) add(ActivePage.Water)
        if (current.isKitesurf) add(ActivePage.SpotBuddy)
        add(ActivePage.Controls)
    }
    val pagerState = rememberPagerState(pageCount = { pages.size })

    Box(modifier = Modifier.fillMaxSize().background(WearColors.Background)) {
        VerticalPager(state = pagerState, modifier = Modifier.fillMaxSize()) { index ->
            when (pages[index]) {
                ActivePage.Metrics -> MetricsPage(current, now)
                ActivePage.Water -> WaterPage(current)
                ActivePage.SpotBuddy -> SpotBuddyScreen()
                ActivePage.Controls -> ControlsPage(current)
            }
        }
        if (pages.size > 1) {
            Column(
                modifier = Modifier.align(Alignment.CenterEnd).padding(end = 3.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                pages.forEachIndexed { i, _ ->
                    Box(
                        modifier = Modifier
                            .size(if (i == pagerState.currentPage) 6.dp else 4.dp)
                            .background(
                                if (i == pagerState.currentPage) WearColors.Accent else WearColors.TextSecondary.copy(alpha = 0.5f),
                                CircleShape,
                            ),
                    )
                }
            }
        }
    }
}

// region Metrics

@Composable
private fun MetricsPage(s: ActiveSession, now: Long) {
    when (s.kind) {
        SessionKind.Meditation -> MeditationMetrics(s, now)
        SessionKind.Strength -> StrengthMetrics(s, now)
        SessionKind.Cardio -> CardioMetrics(s, now)
    }
}

@Composable
private fun PausedBadge() {
    Text(
        "PAUSADO",
        color = Color.Black,
        fontSize = 10.sp,
        fontWeight = FontWeight.Bold,
        modifier = Modifier
            .background(WearColors.Orange, RoundedCornerShape(50))
            .padding(horizontal = 8.dp, vertical = 2.dp),
    )
}

@Composable
private fun HrKcalRow(s: ActiveSession) {
    Row(horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
        Stat(if (s.heartRate > 0) "${s.heartRate}" else "--", "BPM", WearColors.Danger)
        Stat("${s.calories.toInt()}", "kcal", WearColors.Orange)
    }
}

@Composable
private fun Stat(value: String, label: String, color: Color = WearColors.TextPrimary) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, color = color, fontSize = 16.sp, fontWeight = FontWeight.Bold)
        Text(label, color = WearColors.TextSecondary, fontSize = 9.sp)
    }
}

@Composable
private fun StrengthMetrics(s: ActiveSession, now: Long) {
    ScalingLazyColumn(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(3.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (s.isPaused) item { PausedBadge() }
        item {
            Text(
                s.title,
                color = WearColors.TextSecondary,
                fontSize = 10.sp,
                textAlign = TextAlign.Center,
                maxLines = 2,
            )
        }
        if (s.isResting) {
            val remaining = s.restRemainingSeconds(now)
            item { Text("Descanso", color = WearColors.Cyan, fontSize = 12.sp, fontWeight = FontWeight.SemiBold) }
            item {
                Text(
                    formatDuration(remaining),
                    color = if (remaining == 0) WearColors.Accent else WearColors.Cyan,
                    fontSize = 34.sp,
                    fontWeight = FontWeight.Bold,
                )
            }
            if (remaining == 0 && !s.isPaused) {
                item { Text("Hora de voltar!", color = WearColors.Accent, fontSize = 12.sp, fontWeight = FontWeight.Bold) }
            }
        } else {
            item { Text("Exercício", color = WearColors.Accent, fontSize = 11.sp) }
            item {
                Text(
                    s.exerciseName,
                    color = WearColors.TextPrimary,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    textAlign = TextAlign.Center,
                    maxLines = 2,
                )
            }
            item {
                Text(
                    formatDuration(if (s.fromPhone) s.exerciseElapsedSeconds(now) else s.elapsedSeconds(now)),
                    color = WearColors.TextPrimary,
                    fontSize = 32.sp,
                    fontWeight = FontWeight.Bold,
                )
            }
        }
        if (s.phoneSets.isNotBlank()) {
            item { Text(s.phoneSets, color = WearColors.TextSecondary, fontSize = 11.sp) }
        }
        if (!s.fromPhone) item { HrKcalRow(s) }
        if (s.fromPhone) {
            item { SmallNote("Treino do celular · controle no celular", WearColors.TextSecondary) }
        }
        item { SmallNote("← Música  ·  ↑ Pausar / Encerrar", WearColors.TextSecondary) }
    }
}

@Composable
private fun MeditationMetrics(s: ActiveSession, now: Long) {
    val color = meditationColor(s.meditationColorName)
    Box(modifier = Modifier.fillMaxSize().padding(4.dp), contentAlignment = Alignment.Center) {
        if (s.targetSeconds > 0) {
            CircularProgressIndicator(
                progress = s.progress(now),
                modifier = Modifier.fillMaxSize(),
                startAngle = 270f,
                endAngle = 269.5f,
                indicatorColor = color,
                trackColor = color.copy(alpha = 0.2f),
                strokeWidth = 5.dp,
            )
        }
        Column(
            modifier = Modifier.padding(horizontal = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            if (s.isPaused) PausedBadge()
            Text(s.meditationTopicName, color = color, fontSize = 10.sp, textAlign = TextAlign.Center, maxLines = 1)
            Text(
                formatDuration(if (s.targetSeconds > 0) s.remainingSeconds(now) else s.elapsedSeconds(now)),
                color = WearColors.TextPrimary,
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
            )
            Text("restante", color = WearColors.TextSecondary, fontSize = 9.sp)
            Text(
                "Etapa ${s.meditationPromptIndex + 1}/${s.meditationTotalPrompts}",
                color = color,
                fontSize = 10.sp,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                s.currentPrompt,
                color = WearColors.TextPrimary,
                fontSize = 10.sp,
                textAlign = TextAlign.Center,
                maxLines = 3,
            )
        }
    }
}

@Composable
private fun CardioMetrics(s: ActiveSession, now: Long) {
    if (s.usesSegmentedChronometer) {
        SegmentedCardio(s, now)
        return
    }
    ScalingLazyColumn(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(3.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (s.isPaused) item { PausedBadge() }
        item { Text(s.title, color = if (s.isWaterSport) WearColors.Cyan else WearColors.Accent, fontSize = 12.sp, fontWeight = FontWeight.SemiBold) }
        item {
            Text(
                formatDuration(s.elapsedSeconds(now)),
                color = WearColors.TextPrimary,
                fontSize = 32.sp,
                fontWeight = FontWeight.Bold,
            )
        }
        if (s.targetSeconds > 0) {
            item { Text("Meta: ${formatDuration(s.targetSeconds)}", color = WearColors.TextSecondary, fontSize = 10.sp) }
        }
        if (s.isWaterSport) {
            if (s.waterSetupMode.isNotEmpty()) {
                item {
                    Text(
                        if (s.isKitesurf) "Modo: ${s.waterSetupMode}" else "Prancha: ${s.waterSetupMode}",
                        color = WearColors.TextPrimary,
                        fontSize = 11.sp,
                    )
                }
            }
            if (s.waterSetupBoard.isNotEmpty()) {
                item { Text("Prancha: ${s.waterSetupBoard}", color = WearColors.TextSecondary, fontSize = 10.sp) }
            }
            item {
                Text(
                    "${s.jumpCount} saltos · %.1f m".format(s.maxJumpM),
                    color = WearColors.Cyan,
                    fontSize = 11.sp,
                )
            }
            item {
                if (s.gpsPointCount > 0) {
                    Text("GPS Watch · ${s.gpsPointCount} pts", color = WearColors.Accent, fontSize = 10.sp, fontWeight = FontWeight.SemiBold)
                } else {
                    Text("GPS Watch traçando rota no mar…", color = WearColors.TextSecondary, fontSize = 10.sp, textAlign = TextAlign.Center)
                }
            }
            if (s.isKitesurf) {
                item { Text("Deslize ↑ para Spot Buddy", color = WearColors.Cyan, fontSize = 9.sp, fontWeight = FontWeight.SemiBold) }
            }
        }
        item { HrKcalRow(s) }
        if (s.isSwimming) {
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Stat("${s.swimLaps}", "voltas")
                    Stat("${s.distanceMeters.toInt()}", "m")
                    Stat("${s.poolLengthM}", "m/volta")
                }
            }
            item { SmallNote("Voltas automáticas do relógio", WearColors.TextSecondary) }
        }
        if (s.cardioTargetCalories > 0) {
            item { Text("de ${s.cardioTargetCalories} kcal", color = WearColors.TextSecondary, fontSize = 10.sp) }
        }
        item { SmallNote("← Música  ·  ↑ Pausar / Encerrar", WearColors.TextSecondary) }
    }
}

@Composable
private fun SegmentedCardio(s: ActiveSession, now: Long) {
    Box(modifier = Modifier.fillMaxSize().padding(4.dp), contentAlignment = Alignment.Center) {
        CircularProgressIndicator(
            progress = s.progress(now),
            modifier = Modifier.fillMaxSize(),
            startAngle = 270f,
            endAngle = 269.5f,
            indicatorColor = WearColors.Accent,
            trackColor = WearColors.Accent.copy(alpha = 0.2f),
            strokeWidth = 5.dp,
        )
        Column(
            modifier = Modifier.padding(horizontal = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            if (s.isPaused) PausedBadge()
            Text(s.title, color = WearColors.Accent, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
            Text(
                formatDuration(s.elapsedSeconds(now)),
                color = WearColors.TextPrimary,
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
            )
            if (s.targetSeconds > 0) {
                Text("Meta: ${formatDuration(s.targetSeconds)}", color = WearColors.TextSecondary, fontSize = 9.sp)
            }
            HrKcalRow(s)
            if (s.cardioTargetCalories > 0) {
                Text("de ${s.cardioTargetCalories} kcal", color = WearColors.TextSecondary, fontSize = 9.sp)
            }
            if (s.gpsPointCount > 0) {
                Text(
                    "%.2f km · %s".format(s.distanceMeters / 1000.0, s.paceOrSpeedLabel),
                    color = WearColors.TextSecondary,
                    fontSize = 9.sp,
                )
            }
            if (s.syncStatus.startsWith("Meta")) {
                Text(s.syncStatus, color = WearColors.Accent, fontSize = 9.sp, textAlign = TextAlign.Center)
            }
        }
    }
}

// endregion

// region Water page

@Composable
private fun WaterPage(s: ActiveSession) {
    val ejecting by LocalWatchSession.isEjecting.collectAsState()
    ScalingLazyColumn(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(3.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        item { Text(s.title, color = WearColors.Cyan, fontSize = 12.sp, fontWeight = FontWeight.SemiBold) }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Stat("${s.jumpCount}", "saltos")
                Stat("%.1f".format(s.maxJumpM), "m max")
                Stat("%.1f".format(s.lastJumpM), "último")
            }
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Stat("%.1f".format(s.liveAccelG), "g")
                Stat("%+.1f".format(s.relativeAltM), "alt m")
                Stat(if (s.heartRate > 0) "${s.heartRate}" else "--", "BPM")
            }
        }
        item {
            SmallNote(
                if (s.isKitesurf) "Saltos: giroscópio + acelerômetro (como no Surf)"
                else "Sensores ativos · saltos automáticos e manuais",
                WearColors.TextSecondary,
            )
        }
        if (s.waterSensorStatus.isNotEmpty()) item { SmallNote(s.waterSensorStatus, WearColors.TextSecondary) }
        item {
            HFChip(
                label = "Marcar salto",
                enabled = !s.isPaused,
                onClick = { LocalWatchSession.markJump() },
                colors = ChipDefaults.chipColors(backgroundColor = WearColors.Orange, contentColor = Color.Black),
            )
        }
        item {
            HFChip(
                label = if (ejecting) "Ejetando água…" else "Retirar água",
                enabled = !ejecting,
                onClick = { LocalWatchSession.ejectWater() },
                colors = ChipDefaults.chipColors(backgroundColor = WearColors.Card, contentColor = WearColors.Cyan),
            )
        }
        item {
            HFChip(
                label = if (s.phoneReachable) "Sincronizar celular" else "Enviar p/ celular",
                onClick = { LocalWatchSession.requestPhoneSync() },
            )
        }
        if (s.ejectionStatus.isNotEmpty()) item { SmallNote(s.ejectionStatus, WearColors.Cyan) }
        if (s.syncStatus.isNotEmpty()) item { SmallNote(s.syncStatus, WearColors.TextSecondary) }
    }
}

// endregion

// region Controls

@Composable
private fun ControlsPage(s: ActiveSession) {
    ScalingLazyColumn(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (s.fromPhone) {
            item { SmallNote("Treino do celular — sync ativo", WearColors.Accent) }
        }
        item {
            HFChip(
                label = if (s.isPaused) "Retomar" else "Pausar",
                onClick = { LocalWatchSession.togglePause() },
                colors = ChipDefaults.chipColors(
                    backgroundColor = if (s.isPaused) WearColors.Accent else WearColors.Card,
                    contentColor = if (s.isPaused) Color.Black else WearColors.TextPrimary,
                ),
            )
        }
        if (!s.fromPhone && s.kind == SessionKind.Strength) {
            item {
                HFChip(
                    label = if (s.isResting) "Fim do descanso" else "Descanso (90s)",
                    enabled = !s.isPaused,
                    onClick = { if (s.isResting) LocalWatchSession.endRest() else LocalWatchSession.startRest(90) },
                )
            }
        }
        if (!s.fromPhone && s.isSwimming) {
            item { HFChip("+ Volta", enabled = !s.isPaused, onClick = { LocalWatchSession.addSwimLap() }) }
        }
        item {
            HFChip(
                label = "Encerrar",
                onClick = { LocalWatchSession.stop() },
                colors = ChipDefaults.chipColors(backgroundColor = WearColors.Danger, contentColor = Color.White),
            )
        }
        item { SmallNote("← Música  ·  ↑ Pausar / Encerrar", WearColors.TextSecondary) }
        if (s.syncStatus.isNotEmpty()) item { SmallNote(s.syncStatus, WearColors.TextSecondary) }
    }
}

// endregion
