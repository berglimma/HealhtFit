package com.healthfit.wear

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material.PositionIndicator
import androidx.wear.compose.material.Scaffold
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.TimeText

@Composable
fun HomeScreen(
    onStrength: () -> Unit,
    onCardio: () -> Unit,
    onMeditation: () -> Unit,
) {
    val phoneReachable by LocalWatchSession.phoneReachable.collectAsState()
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
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text("HealthFit", color = WearColors.Accent, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                    Text("Escolha o que fazer", color = WearColors.TextSecondary, fontSize = 11.sp)
                }
            }
            item { SectionLabel("Iniciar") }
            item { HFChip("Treinos", onClick = onStrength, secondary = "${WatchCatalog.strengthPrograms.size} programas") }
            item { HFChip("Cardio", onClick = onCardio, secondary = "Água, corrida, bike, escalada…") }
            item { HFChip("Meditação", onClick = onMeditation, secondary = "${WatchCatalog.meditationTopics.size} temas") }
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 8.dp, vertical = 6.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        if (phoneReachable) "Celular conectado" else "Modo solo no relógio",
                        color = if (phoneReachable) WearColors.Accent else WearColors.TextSecondary,
                        fontSize = 11.sp,
                        textAlign = TextAlign.Center,
                    )
                    Text(
                        "Você pode iniciar treinos mesmo sem o celular. BPM e kcal usam o relógio.",
                        color = WearColors.TextSecondary,
                        fontSize = 10.sp,
                        textAlign = TextAlign.Center,
                    )
                }
            }
        }
    }
}

@Composable
fun SectionLabel(text: String) {
    Box(modifier = Modifier.fillMaxWidth().padding(top = 4.dp), contentAlignment = Alignment.Center) {
        Text(text, color = WearColors.Accent, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
    }
}
