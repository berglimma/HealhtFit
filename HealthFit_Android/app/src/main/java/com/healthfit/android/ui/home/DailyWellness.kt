package com.healthfit.android.ui.home

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlin.math.roundToInt

/** Sono e água do dia, compartilhados entre o início e o perfil. */
class DailyWellness {
    var sleepHours by mutableFloatStateOf(7f)
    var waterMl by mutableIntStateOf(1250)
    var weightKg by mutableStateOf("94.7")

    val weight: Float
        get() = weightKg.toFloatOrNull()?.takeIf { it in 30f..250f } ?: 94.7f

    val goalMl: Int
        get() = (weight * 35f).roundToInt().coerceAtLeast(500)

    fun addWater(amount: Int) {
        waterMl = (waterMl + amount).coerceAtLeast(0)
    }
}
