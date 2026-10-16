package com.healthfit.core.coach

/**
 * Hard gates so Android cannot accidentally write Coach / profile / workout
 * documents that iOS production decodes.
 *
 * Remote flags in `appConfig/android` can only **disable** reads further;
 * they cannot enable writes while [WRITES_HARD_DISABLED] is true.
 */
object CoachCloudGates {
    /**
     * Absolute kill-switch for any Coach / mealPlan / nutritionCare / chat write.
     * Flip only after Codable parity + dual-platform review of firestore.rules.
     */
    const val WRITES_HARD_DISABLED: Boolean = true

    /** Defaults when `appConfig/android` is missing (Console not seeded yet). */
    const val DEFAULT_READ_ENABLED: Boolean = true
    const val DEFAULT_WRITE_FLAG: Boolean = false

    fun effectiveWriteEnabled(remoteWriteFlag: Boolean): Boolean =
        !WRITES_HARD_DISABLED && remoteWriteFlag
}
