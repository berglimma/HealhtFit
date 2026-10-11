package com.healthfit.android.ui.assistant

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.text.Normalizer
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.UUID

data class AssistantMoodSample(
    val id: String = UUID.randomUUID().toString(),
    val dateKey: String,
    val kind: String,
    val feeling: String,
    val recordedAtMillis: Long = System.currentTimeMillis(),
)

data class AssistantSessionSample(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val kind: String,
    val endedAtMillis: Long = System.currentTimeMillis(),
)

data class AssistantRoutineSnapshot(
    val moodSamples: List<AssistantMoodSample> = emptyList(),
    val sessions: List<AssistantSessionSample> = emptyList(),
    val lastInsightDayKey: String? = null,
    val lastAnalysisDayKey: String? = null,
) {
    companion object {
        val Empty = AssistantRoutineSnapshot()
    }
}

/**
 * Persistência leve da rotina aprendida pelo IAssistente (SharedPreferences por usuário).
 * Espelha o iOS `AssistantRoutineStore`.
 */
object AssistantRoutineStore {
    private const val Prefs = "assistant_routine.v1"
    private const val MaxMood = 90
    private const val MaxSessions = 120

    fun load(context: Context, userId: String?): AssistantRoutineSnapshot {
        if (userId.isNullOrBlank()) return AssistantRoutineSnapshot.Empty
        val raw = prefs(context).getString(key(userId), null) ?: return AssistantRoutineSnapshot.Empty
        return runCatching { decode(JSONObject(raw)) }.getOrElse { AssistantRoutineSnapshot.Empty }
    }

    fun save(context: Context, userId: String?, snapshot: AssistantRoutineSnapshot) {
        if (userId.isNullOrBlank()) return
        prefs(context).edit().putString(key(userId), encode(snapshot).toString()).apply()
    }

    fun recordMood(
        context: Context,
        userId: String?,
        kind: String,
        feeling: String,
        dateMillis: Long = System.currentTimeMillis(),
    ) {
        if (userId.isNullOrBlank()) return
        var snapshot = load(context, userId)
        val day = dayKey(dateMillis)
        val moods = snapshot.moodSamples
            .filterNot { it.dateKey == day && it.kind == kind }
            .toMutableList()
        moods += AssistantMoodSample(dateKey = day, kind = kind, feeling = feeling, recordedAtMillis = dateMillis)
        val trimmed = moods.sortedBy { it.recordedAtMillis }.takeLast(MaxMood)
        save(context, userId, snapshot.copy(moodSamples = trimmed))
    }

    fun recordSession(
        context: Context,
        userId: String?,
        title: String,
        kind: String,
        endedAtMillis: Long = System.currentTimeMillis(),
    ) {
        if (userId.isNullOrBlank()) return
        var snapshot = load(context, userId)
        val sessions = (snapshot.sessions + AssistantSessionSample(
            title = title,
            kind = kind,
            endedAtMillis = endedAtMillis,
        )).sortedBy { it.endedAtMillis }.takeLast(MaxSessions)
        save(context, userId, snapshot.copy(sessions = sessions))
        prefs(context).edit()
            .putLong(lastWorkoutKey(userId), endedAtMillis)
            .putLong(lastKindKey(userId, kind), endedAtMillis)
            .putLong(lastOpenKey(userId), System.currentTimeMillis())
            .apply()
    }

    fun markAppOpened(context: Context, userId: String?) {
        if (userId.isNullOrBlank()) return
        prefs(context).edit().putLong(lastOpenKey(userId), System.currentTimeMillis()).apply()
    }

    fun lastWorkoutMillis(context: Context, userId: String?): Long {
        if (userId.isNullOrBlank()) return 0L
        val fromPrefs = prefs(context).getLong(lastWorkoutKey(userId), 0L)
        if (fromPrefs > 0L) return fromPrefs
        return load(context, userId).sessions.maxOfOrNull { it.endedAtMillis } ?: 0L
    }

    fun lastKindMillis(context: Context, userId: String?, kind: String): Long {
        if (userId.isNullOrBlank()) return 0L
        return prefs(context).getLong(lastKindKey(userId, kind), 0L)
    }

    fun lastOpenMillis(context: Context, userId: String?): Long {
        if (userId.isNullOrBlank()) return 0L
        return prefs(context).getLong(lastOpenKey(userId), 0L)
    }

    fun markInsightDelivered(context: Context, userId: String?, dayKey: String) {
        val snapshot = load(context, userId)
        save(context, userId, snapshot.copy(lastInsightDayKey = dayKey))
    }

    fun markAnalysisDelivered(context: Context, userId: String?, dayKey: String) {
        val snapshot = load(context, userId)
        save(context, userId, snapshot.copy(lastAnalysisDayKey = dayKey))
    }

    fun dayKey(millis: Long = System.currentTimeMillis()): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        formatter.calendar = Calendar.getInstance()
        return formatter.format(Date(millis))
    }

    fun classifyFeeling(text: String): String {
        val stripped = Normalizer.normalize(text, Normalizer.Form.NFD).replace("\\p{Mn}+".toRegex(), "")
        val value = stripped.lowercase(Locale.getDefault())
        return when {
            listOf("otimo", "incrivel", "excelente", "top", "energia").any { value.contains(it) } -> "great"
            listOf("estress", "ansied", "agitado", "nervoso").any { value.contains(it) } -> "stressed"
            listOf("motivacao", "desanim", "preguica", "sem vontade").any { value.contains(it) } -> "unmotivated"
            listOf("cansado", "exausto", "sem energia", "pesado", "fadiga", "mais ou menos").any { value.contains(it) } -> "tired"
            listOf("bem", "boa", "tranquilo").any { value.contains(it) } -> "good"
            listOf("dor", "tontura", "mal-estar", "mal estar").any { value.contains(it) } -> "sore"
            else -> "neutral"
        }
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(Prefs, Context.MODE_PRIVATE)

    private fun key(userId: String) = "snapshot_$userId"
    private fun lastWorkoutKey(userId: String) = "last_workout_$userId"
    private fun lastKindKey(userId: String, kind: String) = "last_${kind}_$userId"
    private fun lastOpenKey(userId: String) = "last_open_$userId"

    private fun encode(snapshot: AssistantRoutineSnapshot): JSONObject {
        val moods = JSONArray()
        snapshot.moodSamples.forEach { sample ->
            moods.put(
                JSONObject()
                    .put("id", sample.id)
                    .put("dateKey", sample.dateKey)
                    .put("kind", sample.kind)
                    .put("feeling", sample.feeling)
                    .put("recordedAtMillis", sample.recordedAtMillis),
            )
        }
        val sessions = JSONArray()
        snapshot.sessions.forEach { sample ->
            sessions.put(
                JSONObject()
                    .put("id", sample.id)
                    .put("title", sample.title)
                    .put("kind", sample.kind)
                    .put("endedAtMillis", sample.endedAtMillis),
            )
        }
        return JSONObject()
            .put("moodSamples", moods)
            .put("sessions", sessions)
            .put("lastInsightDayKey", snapshot.lastInsightDayKey)
            .put("lastAnalysisDayKey", snapshot.lastAnalysisDayKey)
    }

    private fun decode(json: JSONObject): AssistantRoutineSnapshot {
        val moods = buildList {
            val array = json.optJSONArray("moodSamples") ?: JSONArray()
            for (i in 0 until array.length()) {
                val item = array.getJSONObject(i)
                add(
                    AssistantMoodSample(
                        id = item.optString("id", UUID.randomUUID().toString()),
                        dateKey = item.getString("dateKey"),
                        kind = item.getString("kind"),
                        feeling = item.getString("feeling"),
                        recordedAtMillis = item.optLong("recordedAtMillis", System.currentTimeMillis()),
                    ),
                )
            }
        }
        val sessions = buildList {
            val array = json.optJSONArray("sessions") ?: JSONArray()
            for (i in 0 until array.length()) {
                val item = array.getJSONObject(i)
                add(
                    AssistantSessionSample(
                        id = item.optString("id", UUID.randomUUID().toString()),
                        title = item.optString("title", "Treino"),
                        kind = item.optString("kind", "strength"),
                        endedAtMillis = item.optLong("endedAtMillis", System.currentTimeMillis()),
                    ),
                )
            }
        }
        return AssistantRoutineSnapshot(
            moodSamples = moods,
            sessions = sessions,
            lastInsightDayKey = json.optString("lastInsightDayKey").ifBlank { null },
            lastAnalysisDayKey = json.optString("lastAnalysisDayKey").ifBlank { null },
        )
    }
}
