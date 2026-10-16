package com.healthfit.core.firebase

/**
 * Shared Firebase project with iOS (`healthfit-30d87`).
 *
 * SAFETY: Android clients MUST only use existing Auth/Firestore/Storage paths
 * already consumed by iOS. Do NOT deploy new security rules, indexes, or
 * Functions from this module without an explicit dual-platform review.
 *
 * Coach writes stay disabled in code until Codable parity + dual-platform review.
 * See [com.healthfit.core.coach.CoachCloudGates].
 */
object FirebaseProject {
    const val PROJECT_ID = "healthfit-30d87"
    const val STORAGE_BUCKET = "healthfit-30d87.firebasestorage.app"

    /** Mirror iOS `users/{uid}` document root — read/write only fields iOS already uses. */
    fun userDoc(uid: String) = "users/$uid"

    fun workoutSessions(uid: String) = "users/$uid/workoutSessions"

    fun coachMemberships(uid: String) = "users/$uid/coachMemberships"

    fun coachLink(linkId: String) = "coachLinks/$linkId"

    fun assignedWorkouts(linkId: String) = "coachLinks/$linkId/assignedWorkouts"

    fun mealPlanCurrent(linkId: String) = "coachLinks/$linkId/mealPlan/current"

    fun nutritionCareCurrent(linkId: String) = "coachLinks/$linkId/nutritionCare/current"

    fun coachProfile(uid: String) = "coachProfiles/$uid"

    /** Remote kill-switches — Console write only (`firestore.rules`: client write false). */
    const val APP_CONFIG_ANDROID = "appConfig/android"
    const val APP_CONFIG_IOS = "appConfig/ios"
}
