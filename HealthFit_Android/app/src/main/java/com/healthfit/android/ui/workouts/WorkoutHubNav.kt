package com.healthfit.android.ui.workouts

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** Deep link Treinos → programa masculino/feminino ou aba Cardio. */
object WorkoutHubNav {
    private val _pendingProgramKey = MutableStateFlow<String?>(null)
    val pendingProgramKey: StateFlow<String?> = _pendingProgramKey.asStateFlow()

    private val _pendingCardioTab = MutableStateFlow(false)
    val pendingCardioTab: StateFlow<Boolean> = _pendingCardioTab.asStateFlow()

    fun openProgram(key: String) {
        _pendingProgramKey.value = key
    }

    fun openCardio() {
        _pendingCardioTab.value = true
    }

    fun consumePending(): String? {
        val value = _pendingProgramKey.value
        _pendingProgramKey.value = null
        return value
    }

    fun consumePendingCardio(): Boolean {
        val value = _pendingCardioTab.value
        _pendingCardioTab.value = false
        return value
    }
}
