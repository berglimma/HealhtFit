package com.healthfit.android.ui.home

import android.content.Context
import android.net.Uri
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.UUID

data class ConstancySession(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val kind: String,
    val endedAtMillis: Long = System.currentTimeMillis(),
    val photoPath: String? = null,
)

/**
 * Constância calendar feed — device-wide (works offline / without login).
 * Mirrors iOS WorkoutStore.sessionHistory + wellness rest days for the photo calendar.
 */
object ConstancyStore {
    private const val Prefs = "constancy.v1"
    private const val KeySessions = "sessions"
    private const val KeyRestDays = "rest_days"
    private val dayFmt = SimpleDateFormat("yyyy-MM-dd", Locale.US)

    fun dayKey(millis: Long = System.currentTimeMillis()): String = dayFmt.format(Date(millis))

    fun recordSession(
        context: Context,
        title: String,
        kind: String,
        endedAtMillis: Long = System.currentTimeMillis(),
        photoPath: String? = null,
    ) {
        val sessions = loadSessions(context).toMutableList()
        sessions += ConstancySession(title = title, kind = kind, endedAtMillis = endedAtMillis, photoPath = photoPath)
        saveSessions(context, sessions.sortedBy { it.endedAtMillis }.takeLast(200))
    }

    fun attachPhoto(context: Context, sessionId: String, photoPath: String) {
        val updated = loadSessions(context).map {
            if (it.id == sessionId) it.copy(photoPath = photoPath) else it
        }
        saveSessions(context, updated)
    }

    /** Copy gallery/camera URI into app files and attach to a session (or create one for the day). */
    fun saveAndAttachPhoto(
        context: Context,
        source: Uri,
        sessionId: String? = null,
        dayKey: String = dayKey(),
        title: String = "Check-in",
        kind: String = "workout",
    ): String? {
        val dir = File(context.filesDir, "WorkoutCheckInPhotos").apply { mkdirs() }
        val dest = File(dir, "checkin_${System.currentTimeMillis()}.jpg")
        val ok = runCatching {
            context.contentResolver.openInputStream(source)?.use { input ->
                dest.outputStream().use { output -> input.copyTo(output) }
            } != null && dest.exists() && dest.length() > 0L
        }.getOrDefault(false)
        if (!ok) return null
        val targetId = sessionId ?: sessionsOnDay(context, dayKey).firstOrNull()?.id
        if (targetId != null) {
            attachPhoto(context, targetId, dest.absolutePath)
        } else {
            // Create a day session so the calendar can show the photo (iOS attaches to session).
            val ended = runCatching {
                dayFmt.parse(dayKey)?.time
            }.getOrNull() ?: System.currentTimeMillis()
            recordSession(context, title = title, kind = kind, endedAtMillis = ended, photoPath = dest.absolutePath)
        }
        return dest.absolutePath
    }

    fun loadSessions(context: Context): List<ConstancySession> {
        val raw = prefs(context).getString(KeySessions, null) ?: return emptyList()
        return runCatching {
            val arr = JSONArray(raw)
            buildList {
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    add(
                        ConstancySession(
                            id = o.optString("id", UUID.randomUUID().toString()),
                            title = o.optString("title"),
                            kind = o.optString("kind"),
                            endedAtMillis = o.optLong("endedAtMillis"),
                            photoPath = o.optString("photoPath").ifBlank { null },
                        ),
                    )
                }
            }
        }.getOrDefault(emptyList())
    }

    fun isRestDay(context: Context, dayKey: String): Boolean =
        loadRestDays(context).contains(dayKey)

    fun isTodayRestDay(context: Context): Boolean = isRestDay(context, dayKey())

    fun setRestDay(context: Context, dayKey: String, rest: Boolean) {
        val set = loadRestDays(context).toMutableSet()
        if (rest) set += dayKey else set -= dayKey
        prefs(context).edit().putStringSet(KeyRestDays, set).apply()
    }

    fun setTodayRestDay(context: Context, rest: Boolean) = setRestDay(context, dayKey(), rest)

    fun loadRestDays(context: Context): Set<String> =
        prefs(context).getStringSet(KeyRestDays, emptySet())?.toSet() ?: emptySet()

    fun trainedDayKeysInMonth(context: Context, year: Int, month: Int): Set<String> {
        val cal = Calendar.getInstance()
        return loadSessions(context).mapNotNull { s ->
            cal.timeInMillis = s.endedAtMillis
            if (cal.get(Calendar.YEAR) == year && cal.get(Calendar.MONTH) == month) {
                dayKey(s.endedAtMillis)
            } else null
        }.toSet()
    }

    fun sessionsOnDay(context: Context, dayKey: String): List<ConstancySession> =
        loadSessions(context).filter { dayKey(it.endedAtMillis) == dayKey }

    fun photoPathOnDay(context: Context, dayKey: String): String? =
        sessionsOnDay(context, dayKey).firstOrNull { !it.photoPath.isNullOrBlank() }?.photoPath

    private fun saveSessions(context: Context, sessions: List<ConstancySession>) {
        val arr = JSONArray()
        sessions.forEach { s ->
            arr.put(
                JSONObject()
                    .put("id", s.id)
                    .put("title", s.title)
                    .put("kind", s.kind)
                    .put("endedAtMillis", s.endedAtMillis)
                    .put("photoPath", s.photoPath ?: ""),
            )
        }
        prefs(context).edit().putString(KeySessions, arr.toString()).apply()
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(Prefs, Context.MODE_PRIVATE)
}
