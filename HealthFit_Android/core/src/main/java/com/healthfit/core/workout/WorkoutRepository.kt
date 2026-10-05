package com.healthfit.core.workout

import com.healthfit.core.model.WorkoutKind
import com.healthfit.core.model.WorkoutSessionSummary
import com.healthfit.core.model.WorkoutSheet
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Phase 1: local catalog + in-memory sessions.
 *
 * SAFETY: Firestore writes are intentionally disabled until Android session
 * documents are field-compatible with iOS `WorkoutSession` readers.
 * Never invent collections; when enabling sync, reuse `users/{uid}/workoutSessions`
 * only after a dual-platform schema review.
 */
interface WorkoutRepository {
    val sheets: Flow<List<WorkoutSheet>>
    val recentSessions: Flow<List<WorkoutSessionSummary>>
    suspend fun seedDemoCatalogIfEmpty()
    suspend fun recordLocalSession(summary: WorkoutSessionSummary)
}

class DefaultWorkoutRepository : WorkoutRepository {

    private val sheetsState = MutableStateFlow<List<WorkoutSheet>>(emptyList())
    private val sessionsState = MutableStateFlow<List<WorkoutSessionSummary>>(emptyList())

    override val sheets = sheetsState.asStateFlow()
    override val recentSessions = sessionsState.asStateFlow()

    override suspend fun seedDemoCatalogIfEmpty() {
        if (sheetsState.value.isNotEmpty()) return
        sheetsState.value = listOf(
            WorkoutSheet(title = "Full Body A", kind = WorkoutKind.STRENGTH, exerciseCount = 8),
            WorkoutSheet(title = "Push Hypertrophy", kind = WorkoutKind.STRENGTH, exerciseCount = 7),
            WorkoutSheet(title = "Corrida fácil", kind = WorkoutKind.CARDIO, exerciseCount = 0),
            WorkoutSheet(title = "Meditação 10 min", kind = WorkoutKind.MEDITATION, exerciseCount = 0),
        )
    }

    override suspend fun recordLocalSession(summary: WorkoutSessionSummary) {
        sessionsState.value = listOf(summary) + sessionsState.value
    }
}
