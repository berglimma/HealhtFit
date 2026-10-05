package com.healthfit.android.ui.workouts

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.healthfit.core.model.WorkoutSheet
import com.healthfit.core.workout.WorkoutRepository
import com.healthfit.designsystem.HealthFitCard
import com.healthfit.designsystem.HealthFitColors

@Composable
fun WorkoutsScreen(workoutRepository: WorkoutRepository) {
    LaunchedEffect(Unit) { workoutRepository.seedDemoCatalogIfEmpty() }
    val sheets by workoutRepository.sheets.collectAsState()

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Text(
                "Treinos",
                color = HealthFitColors.TextPrimary,
                style = MaterialTheme.typography.headlineMedium,
            )
            Text(
                "Catálogo local (Fase 1). Sessões ativas, OCR e Watch sync entram nas próximas fases.",
                color = HealthFitColors.TextSecondary,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.padding(top = 6.dp, bottom = 4.dp),
            )
        }
        items(sheets, key = { it.id }) { sheet ->
            WorkoutSheetCard(sheet)
        }
    }
}

@Composable
private fun WorkoutSheetCard(sheet: WorkoutSheet) {
    HealthFitCard {
        Text(sheet.title, color = HealthFitColors.TextPrimary, style = MaterialTheme.typography.titleMedium)
        Text(
            text = "${sheet.kind.name.lowercase().replaceFirstChar { it.titlecase() }}" +
                if (sheet.exerciseCount > 0) " · ${sheet.exerciseCount} exercícios" else "",
            color = HealthFitColors.TextSecondary,
            style = MaterialTheme.typography.bodyMedium,
            modifier = Modifier.padding(top = 6.dp),
        )
    }
}
