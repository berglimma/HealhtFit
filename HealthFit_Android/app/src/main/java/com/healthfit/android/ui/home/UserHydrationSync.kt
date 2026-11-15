package com.healthfit.android.ui.home

import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.healthfit.core.firebase.FirebaseProject
import org.json.JSONObject

/**
 * Reads the student's water goal from the same iOS `users/{uid}` document
 * (`customDailyWaterML` + `profilePayload`). Read-only.
 */
object UserHydrationSync {
    fun listen(
        uid: String,
        onUpdate: (customMl: Int?, weightKg: Double?) -> Unit,
    ): ListenerRegistration? {
        if (uid.isBlank()) return null
        return runCatching {
            FirebaseFirestore.getInstance()
                .document(FirebaseProject.userDoc(uid))
                .addSnapshotListener { snapshot, error ->
                    if (error != null || snapshot == null || !snapshot.exists()) return@addSnapshotListener
                    val data = snapshot.data ?: return@addSnapshotListener
                    onUpdate(parseCustomDailyWaterML(data), parseWeightKg(data))
                }
        }.getOrNull()
    }

    private fun parseCustomDailyWaterML(data: Map<String, Any>): Int? {
        (data["customDailyWaterML"] as? Number)?.toInt()?.takeIf { it >= 500 }?.let { return it }
        val json = data["profilePayload"] as? String ?: return null
        return runCatching {
            JSONObject(json).optInt("customDailyWaterML", -1).takeIf { it >= 500 }
        }.getOrNull()
    }

    private fun parseWeightKg(data: Map<String, Any>): Double? {
        (data["weight"] as? Number)?.toDouble()?.takeIf { it in 30.0..250.0 }?.let { return it }
        val json = data["profilePayload"] as? String ?: return null
        return runCatching {
            JSONObject(json).optDouble("weight", Double.NaN).takeIf { it in 30.0..250.0 }
        }.getOrNull()
    }
}
