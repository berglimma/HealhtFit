package com.healthfit.core.coach

import com.google.firebase.FirebaseApp
import com.google.firebase.firestore.FirebaseFirestore
import com.healthfit.core.firebase.FirebaseProject
import kotlinx.coroutines.tasks.await

/**
 * Read-only remote flags for Android (`appConfig/android`).
 * Clients cannot write this doc (firestore.rules: write false).
 *
 * Seed in Firebase Console (does not affect iOS):
 * ```
 * appConfig/android
 *   coachCloudReadEnabled: true
 *   coachCloudWriteEnabled: false
 * ```
 */
data class AndroidAppConfig(
    val coachCloudReadEnabled: Boolean = CoachCloudGates.DEFAULT_READ_ENABLED,
    val coachCloudWriteEnabled: Boolean = CoachCloudGates.DEFAULT_WRITE_FLAG,
)

object AppConfigAndroid {
    fun isFirebaseReady(): Boolean = runCatching {
        FirebaseApp.getInstance()
        true
    }.getOrDefault(false)

    suspend fun fetch(): AndroidAppConfig {
        if (!isFirebaseReady()) return AndroidAppConfig()
        return runCatching {
            val snap = FirebaseFirestore.getInstance()
                .document(FirebaseProject.APP_CONFIG_ANDROID)
                .get()
                .await()
            if (!snap.exists()) return AndroidAppConfig()
            val data = snap.data.orEmpty()
            AndroidAppConfig(
                coachCloudReadEnabled = data["coachCloudReadEnabled"] as? Boolean
                    ?: CoachCloudGates.DEFAULT_READ_ENABLED,
                coachCloudWriteEnabled = data["coachCloudWriteEnabled"] as? Boolean
                    ?: CoachCloudGates.DEFAULT_WRITE_FLAG,
            )
        }.getOrElse { AndroidAppConfig() }
    }
}
