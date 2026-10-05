package com.healthfit.core.firebase

/**
 * Shared Firebase project with iOS (`healthfit-30d87`).
 *
 * SAFETY: Android clients MUST only use existing Auth/Firestore/Storage paths
 * already consumed by iOS. Do NOT deploy new security rules, indexes, or
 * Functions from this module without an explicit dual-platform review.
 */
object FirebaseProject {
    const val PROJECT_ID = "healthfit-30d87"
    const val STORAGE_BUCKET = "healthfit-30d87.firebasestorage.app"

    /** Mirror iOS `users/{uid}` document root — read/write only fields iOS already uses. */
    fun userDoc(uid: String) = "users/$uid"

    fun workoutSessions(uid: String) = "users/$uid/workoutSessions"
}
