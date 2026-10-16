package com.healthfit.android.ui.nutrition

import android.content.Context
import org.json.JSONObject

data class NutritionAnamnesis(
    val chiefComplaint: String = "",
    val medicalHistory: String = "",
    val medications: String = "",
    val allergies: String = "",
    val surgeries: String = "",
    val familyHistory: String = "",
    val digestiveIssues: String = "",
    val waterIntakeLiters: Double = 2.0,
    val alcoholUse: String = "",
    val smoking: String = "Não",
    val physicalActivity: String = "",
    val stressLevel: Int = 5,
    val sleepHours: Double = 7.0,
    val bowelFunction: String = "",
    val menstrualNotes: String = "",
    val foodAversions: String = "",
    val eatingOutFrequency: String = "",
    val supplementsInUse: String = "",
    val previousDiets: String = "",
    val notes: String = "",
    val updatedAtMillis: Long = 0L,
) {
    val completionPercent: Int
        get() {
            val fields = listOf(
                chiefComplaint, medicalHistory, medications, allergies, surgeries,
                familyHistory, digestiveIssues, alcoholUse, smoking, physicalActivity,
                bowelFunction, foodAversions, eatingOutFrequency, previousDiets,
            )
            val filled = fields.count { it.trim().isNotEmpty() }
            return ((filled.toDouble() / fields.size) * 100).toInt()
        }
}

/**
 * Local nutrition care store (anamnese). Mirrors iOS NutritionCareStore for student + coach view.
 * Cloud sync can plug in later via Coach Firestore like iOS.
 */
object NutritionCareStore {
    private const val Prefs = "nutrition_care.v1"
    private const val KeyAnamnesis = "anamnesis"

    fun loadAnamnesis(context: Context): NutritionAnamnesis {
        val raw = prefs(context).getString(KeyAnamnesis, null) ?: return NutritionAnamnesis()
        return runCatching { decode(JSONObject(raw)) }.getOrDefault(NutritionAnamnesis())
    }

    fun saveAnamnesis(context: Context, anamnesis: NutritionAnamnesis) {
        val withStamp = anamnesis.copy(updatedAtMillis = System.currentTimeMillis())
        prefs(context).edit().putString(KeyAnamnesis, encode(withStamp).toString()).apply()
    }

    private fun encode(a: NutritionAnamnesis) = JSONObject()
        .put("chiefComplaint", a.chiefComplaint)
        .put("medicalHistory", a.medicalHistory)
        .put("medications", a.medications)
        .put("allergies", a.allergies)
        .put("surgeries", a.surgeries)
        .put("familyHistory", a.familyHistory)
        .put("digestiveIssues", a.digestiveIssues)
        .put("waterIntakeLiters", a.waterIntakeLiters)
        .put("alcoholUse", a.alcoholUse)
        .put("smoking", a.smoking)
        .put("physicalActivity", a.physicalActivity)
        .put("stressLevel", a.stressLevel)
        .put("sleepHours", a.sleepHours)
        .put("bowelFunction", a.bowelFunction)
        .put("menstrualNotes", a.menstrualNotes)
        .put("foodAversions", a.foodAversions)
        .put("eatingOutFrequency", a.eatingOutFrequency)
        .put("supplementsInUse", a.supplementsInUse)
        .put("previousDiets", a.previousDiets)
        .put("notes", a.notes)
        .put("updatedAtMillis", a.updatedAtMillis)

    private fun decode(o: JSONObject) = NutritionAnamnesis(
        chiefComplaint = o.optString("chiefComplaint"),
        medicalHistory = o.optString("medicalHistory"),
        medications = o.optString("medications"),
        allergies = o.optString("allergies"),
        surgeries = o.optString("surgeries"),
        familyHistory = o.optString("familyHistory"),
        digestiveIssues = o.optString("digestiveIssues"),
        waterIntakeLiters = o.optDouble("waterIntakeLiters", 2.0),
        alcoholUse = o.optString("alcoholUse"),
        smoking = o.optString("smoking").ifBlank { "Não" },
        physicalActivity = o.optString("physicalActivity"),
        stressLevel = o.optInt("stressLevel", 5),
        sleepHours = o.optDouble("sleepHours", 7.0),
        bowelFunction = o.optString("bowelFunction"),
        menstrualNotes = o.optString("menstrualNotes"),
        foodAversions = o.optString("foodAversions"),
        eatingOutFrequency = o.optString("eatingOutFrequency"),
        supplementsInUse = o.optString("supplementsInUse"),
        previousDiets = o.optString("previousDiets"),
        notes = o.optString("notes"),
        updatedAtMillis = o.optLong("updatedAtMillis"),
    )

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(Prefs, Context.MODE_PRIVATE)
}
