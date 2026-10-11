package com.healthfit.android.ui.assistant

import com.healthfit.android.ui.home.AthleteProfile
import com.healthfit.android.ui.home.BodyType
import com.healthfit.android.ui.home.DailyWellness
import com.healthfit.android.ui.home.SweetConsumptionLevel
import kotlin.math.roundToInt

/** Context mirror of iOS HealthAssistantContext for FAQ answers. */
data class AssistantAnswerContext(
    val name: String,
    val weightKg: Float,
    val heightCm: Float,
    val objective: String,
    val bodyType: BodyType,
    val waterMl: Int,
    val waterGoalMl: Int,
    val sleepHours: Float?,
    val weeklyWorkoutCount: Int,
    val hoursSinceLastWorkout: Double?,
    val routine: AssistantRoutineProfile,
    val basalMetabolicRate: Int,
    val estimatedTdee: Int,
    val dailyCalorieTarget: Int,
    val caloricDeficit: Int,
    val sweetConsumption: SweetConsumptionLevel = SweetConsumptionLevel.Moderate,
    val lactoseTolerant: Boolean? = null,
) {
    val sweetLabel: String get() = sweetConsumption.title
    val sweetDetail: String get() = sweetConsumption.detail
    val sweetWarning: String? get() = sweetConsumption.warning
    val lactoseLabel: String?
        get() = when (lactoseTolerant) {
            true -> "Sim, tolero"
            false -> "Intolerância"
            null -> null
        }
    val bmi: Float
        get() {
            val m = heightCm / 100f
            if (m <= 0f) return 0f
            return weightKg / (m * m)
        }

    val estimatedWeeklyWeightLoss: Float
        get() = if (caloricDeficit > 0) caloricDeficit * 7f / 7700f else 0f

    val isFatLoss: Boolean get() = objective.contains("Perda", ignoreCase = true) || objective.contains("gordura", ignoreCase = true)
    val isMuscleGain: Boolean get() = objective.contains("Massa", ignoreCase = true) || objective.contains("Ganho", ignoreCase = true)
    val isEndurance: Boolean get() = objective.contains("Resist", ignoreCase = true)

    companion object {
        fun build(
            name: String,
            wellness: DailyWellness,
            athlete: AthleteProfile,
            routine: AssistantRoutineProfile = AssistantRoutineProfile.Empty,
            weeklyWorkoutCount: Int = 0,
            hoursSinceLastWorkout: Double? = null,
        ): AssistantAnswerContext {
            val weight = wellness.weight
            val height = athlete.heightCm.toFloatOrNull()?.takeIf { it in 120f..230f } ?: 176f
            // Mifflin-St Jeor (male default, age 30) — same spirit as iOS estimates.
            val bmr = (10f * weight + 6.25f * height - 5f * 30f + 5f).roundToInt()
            var tdee = (bmr * 1.55f).roundToInt()
            tdee = when (athlete.bodyType) {
                BodyType.Ectomorph -> (tdee * 1.10f).roundToInt()
                BodyType.Endomorph -> (tdee * 0.90f).roundToInt()
                BodyType.Mesomorph -> tdee
            }
            val (target, deficit) = when {
                athlete.objective.contains("Perda", ignoreCase = true) ||
                    athlete.objective.contains("gordura", ignoreCase = true) ->
                    (tdee - 500).coerceAtLeast(1400) to 500
                athlete.objective.contains("Massa", ignoreCase = true) ||
                    athlete.objective.contains("Ganho", ignoreCase = true) ->
                    tdee + 300 to 0
                athlete.objective.contains("Resist", ignoreCase = true) ->
                    tdee to 0
                else -> tdee to 0
            }
            return AssistantAnswerContext(
                name = name,
                weightKg = weight,
                heightCm = height,
                objective = athlete.objective,
                bodyType = athlete.bodyType,
                waterMl = wellness.waterMl,
                waterGoalMl = wellness.goalMl,
                sleepHours = wellness.sleepHours,
                weeklyWorkoutCount = weeklyWorkoutCount,
                hoursSinceLastWorkout = hoursSinceLastWorkout,
                routine = routine,
                basalMetabolicRate = bmr,
                estimatedTdee = tdee,
                dailyCalorieTarget = target,
                caloricDeficit = deficit,
                sweetConsumption = athlete.sweetConsumption,
                lactoseTolerant = athlete.lactoseTolerant,
            )
        }
    }
}
