package com.healthfit.wear

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.ScalingLazyListScope
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material.ChipDefaults
import androidx.wear.compose.material.PositionIndicator
import androidx.wear.compose.material.Scaffold
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.TimeText
import androidx.wear.compose.material.ToggleChip
import androidx.wear.compose.material.Switch

/** Lista padrão do relógio: título + itens em ScalingLazyColumn. */
@Composable
fun WearList(title: String, content: ScalingLazyListScope.() -> Unit) {
    val listState = rememberScalingLazyListState()
    Scaffold(
        modifier = Modifier.background(WearColors.Background),
        timeText = { TimeText() },
        positionIndicator = { PositionIndicator(scalingLazyListState = listState) },
    ) {
        ScalingLazyColumn(
            modifier = Modifier.fillMaxSize(),
            state = listState,
            verticalArrangement = Arrangement.spacedBy(4.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            item {
                Text(
                    title,
                    color = WearColors.Accent,
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().padding(bottom = 2.dp),
                )
            }
            content()
        }
    }
}

@Composable
fun StrengthListScreen(onStart: (WatchCatalog.StrengthProgram) -> Unit) {
    WearList("Treinos") {
        items(WatchCatalog.strengthPrograms.size) { index ->
            val program = WatchCatalog.strengthPrograms[index]
            HFChip(
                label = program.title,
                secondary = program.firstExercise,
                onClick = { onStart(program) },
                maxLines = 3,
            )
        }
    }
}

@Composable
fun CardioListScreen(
    onWater: (WatchCatalog.CardioActivity) -> Unit,
    onCardio: (WatchCatalog.CardioActivity) -> Unit,
) {
    val climbingEnabled by LocalWatchSession.climbingAutoDetect.collectAsState()
    val climbingStatus by LocalWatchSession.climbingStatus.collectAsState()
    val ejecting by LocalWatchSession.isEjecting.collectAsState()
    val ejectionStatus by LocalWatchSession.ejectionStatus.collectAsState()

    WearList("Cardio") {
        item { SectionLabel("Água · Surf / Kitesurf") }
        val water = WatchCatalog.cardioActivities.filter { it.isWaterSport }
        items(water.size) { i ->
            HFChip(label = water[i].name, onClick = { onWater(water[i]) })
        }
        item {
            HFChip(
                label = if (ejecting) "Ejetando água…" else "Retirar água",
                enabled = !ejecting,
                onClick = { LocalWatchSession.ejectWater() },
                colors = ChipDefaults.chipColors(
                    backgroundColor = WearColors.Card,
                    contentColor = WearColors.Cyan,
                ),
            )
        }
        if (ejectionStatus.isNotEmpty()) {
            item { SmallNote(ejectionStatus, WearColors.Cyan) }
        }

        item { SectionLabel("Cardio") }
        val others = WatchCatalog.cardioActivities.filter { !it.isWaterSport }
        items(others.size) { i ->
            HFChip(label = others[i].name, onClick = { onCardio(others[i]) })
        }

        item { SectionLabel("Escalada") }
        item {
            ToggleChip(
                checked = climbingEnabled,
                onCheckedChange = { LocalWatchSession.setClimbingAutoDetect(it) },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("Detectar automático", fontSize = 13.sp) },
                toggleControl = { Switch(checked = climbingEnabled) },
            )
        }
        if (climbingStatus.isNotEmpty()) {
            item { SmallNote(climbingStatus, WearColors.TextSecondary) }
        }
    }
}

@Composable
fun MeditationListScreen(onTopic: (WatchCatalog.MeditationTopic) -> Unit) {
    WearList("Meditação") {
        items(WatchCatalog.meditationTopics.size) { i ->
            val topic = WatchCatalog.meditationTopics[i]
            HFChip(
                label = topic.name,
                onClick = { onTopic(topic) },
                colors = ChipDefaults.chipColors(
                    backgroundColor = WearColors.Card,
                    contentColor = meditationColor(topic.colorName),
                ),
            )
        }
    }
}

@Composable
fun SmallNote(text: String, color: androidx.compose.ui.graphics.Color) {
    Text(
        text,
        color = color,
        fontSize = 10.sp,
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp),
    )
}
