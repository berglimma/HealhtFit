package com.healthfit.core.coach

/**
 * Read-only mirrors of iOS Coach Firestore documents.
 * Field names match Swift Codable / CoachFirestoreService — do not invent aliases.
 */
data class CoachLinkSnapshot(
    val id: String,
    val coachUid: String,
    val coachName: String,
    val coachPhotoURL: String? = null,
    val studentUid: String,
    val studentName: String,
    val studentPhotoURL: String? = null,
    val profession: String,
    val status: String,
    val memberUids: List<String> = emptyList(),
) {
    val isActiveLike: Boolean
        get() = status == "active" || status == "blockedPlan"

    val isPersonal: Boolean get() = profession == "personal"
    val isNutritionist: Boolean get() = profession == "nutritionist"

    val statusLabel: String
        get() = when (status) {
            "pending" -> "Pendente"
            "active" -> "Ativo"
            "ended" -> "Encerrado"
            "blockedPlan" -> "Aguardando plano Fit+"
            else -> status
        }

    val professionLabel: String
        get() = when (profession) {
            "personal" -> "Personal"
            "nutritionist" -> "Nutrição"
            else -> profession
        }
}

data class CoachAssignedWorkoutSnapshot(
    val id: String,
    val linkId: String,
    val coachUid: String,
    val coachName: String,
    val studentUid: String,
    val sheetTitle: String,
    val isActive: Boolean,
)

data class CoachMealPlanSnapshot(
    val linkId: String,
    val coachUid: String?,
    val coachName: String?,
    val hasWeeklyPlan: Boolean,
)

data class CoachCloudState(
    val firebaseReady: Boolean = false,
    val readEnabled: Boolean = false,
    /** Always false until dual-platform write review — never enable lightly. */
    val writeEnabled: Boolean = false,
    val uid: String? = null,
    val links: List<CoachLinkSnapshot> = emptyList(),
    val assignedByLink: Map<String, List<CoachAssignedWorkoutSnapshot>> = emptyMap(),
    val mealPlanByLink: Map<String, CoachMealPlanSnapshot> = emptyMap(),
    val statusMessage: String? = null,
) {
    val activePersonal: CoachLinkSnapshot?
        get() = links.firstOrNull { it.isPersonal && it.isActiveLike }

    val activeNutrition: CoachLinkSnapshot?
        get() = links.firstOrNull { it.isNutritionist && it.isActiveLike }

    fun assignedFor(linkId: String): List<CoachAssignedWorkoutSnapshot> =
        assignedByLink[linkId].orEmpty()

    fun mealPlanFor(linkId: String): CoachMealPlanSnapshot? = mealPlanByLink[linkId]
}
