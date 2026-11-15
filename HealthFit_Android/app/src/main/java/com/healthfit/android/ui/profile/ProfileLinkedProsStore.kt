package com.healthfit.android.ui.profile

import android.content.Context
import com.google.firebase.auth.FirebaseAuth

/**
 * Personal / nutricionista informados no Perfil — lidos pelo card Treino do dia.
 */
object ProfileLinkedProsStore {
    private const val Prefs = "healthfit_linked_pros"
    private const val KeyHasTrainer = "has_trainer"
    private const val KeyTrainerName = "trainer_name"
    private const val KeyTrainerEmail = "trainer_email"
    private const val KeyHasNutri = "has_nutri"
    private const val KeyNutriName = "nutri_name"
    private const val KeyNutriEmail = "nutri_email"
    private const val KeyRestWeekdays = "rest_weekdays"

    data class Snapshot(
        val hasTrainer: Boolean = false,
        val trainerName: String = "",
        val trainerEmail: String = "",
        val hasNutri: Boolean = false,
        val nutriName: String = "",
        val nutriEmail: String = "",
        /** Calendar.DAY_OF_WEEK: 1=domingo … 7=sábado */
        val restWeekdays: List<Int> = emptyList(),
    )

    fun userId(): String =
        runCatching { FirebaseAuth.getInstance().currentUser?.uid }.getOrNull().orEmpty()
            .ifBlank { "local" }

    fun load(context: Context): Snapshot {
        val p = prefs(context)
        val uid = userId()
        val restRaw = p.getString(scoped(KeyRestWeekdays, uid), "").orEmpty()
        val restWeekdays = restRaw.split(',')
            .mapNotNull { it.trim().toIntOrNull() }
            .filter { it in 1..7 }
            .distinct()
            .sorted()
        return Snapshot(
            hasTrainer = p.getBoolean(scoped(KeyHasTrainer, uid), false),
            trainerName = p.getString(scoped(KeyTrainerName, uid), "").orEmpty(),
            trainerEmail = p.getString(scoped(KeyTrainerEmail, uid), "").orEmpty(),
            hasNutri = p.getBoolean(scoped(KeyHasNutri, uid), false),
            nutriName = p.getString(scoped(KeyNutriName, uid), "").orEmpty(),
            nutriEmail = p.getString(scoped(KeyNutriEmail, uid), "").orEmpty(),
            restWeekdays = restWeekdays,
        )
    }

    fun saveRestWeekdays(context: Context, weekdays: List<Int>) {
        val uid = userId()
        val normalized = weekdays.filter { it in 1..7 }.distinct().sorted()
        prefs(context).edit()
            .putString(scoped(KeyRestWeekdays, uid), normalized.joinToString(","))
            .apply()
    }

    fun saveTrainer(
        context: Context,
        hasTrainer: Boolean,
        name: String,
        email: String,
    ) {
        val uid = userId()
        prefs(context).edit()
            .putBoolean(scoped(KeyHasTrainer, uid), hasTrainer)
            .putString(scoped(KeyTrainerName, uid), name.trim())
            .putString(scoped(KeyTrainerEmail, uid), email.trim())
            .apply()
    }

    fun saveNutri(
        context: Context,
        hasNutri: Boolean,
        name: String,
        email: String,
    ) {
        val uid = userId()
        prefs(context).edit()
            .putBoolean(scoped(KeyHasNutri, uid), hasNutri)
            .putString(scoped(KeyNutriName, uid), name.trim())
            .putString(scoped(KeyNutriEmail, uid), email.trim())
            .apply()
    }

    fun hasPersonalTrainer(context: Context): Boolean {
        val snap = load(context)
        if (!snap.hasTrainer) return false
        return snap.trainerName.isNotBlank() || snap.trainerEmail.isNotBlank() || snap.hasTrainer
    }

    fun trainerDisplayName(context: Context): String? {
        val name = load(context).trainerName.trim()
        return name.takeIf { it.isNotEmpty() }
    }

    private fun scoped(key: String, uid: String) = "$uid::$key"

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(Prefs, Context.MODE_PRIVATE)
}
