package com.healthfit.core.model

import java.util.UUID

enum class WorkoutKind { STRENGTH, CARDIO, MEDITATION }

data class WorkoutSheet(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val kind: WorkoutKind = WorkoutKind.STRENGTH,
    val exerciseCount: Int = 0,
)

data class WorkoutSessionSummary(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val kind: WorkoutKind,
    val durationSeconds: Int,
    val calories: Double? = null,
)
