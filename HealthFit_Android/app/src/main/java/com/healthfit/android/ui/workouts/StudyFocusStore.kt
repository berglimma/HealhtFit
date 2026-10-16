package com.healthfit.android.ui.workouts

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

enum class StudyPriorityLevel(val label: String) {
    High("Alta"),
    Medium("Média"),
    Low("Baixa"),
}

data class StudyPriorityItem(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val level: StudyPriorityLevel = StudyPriorityLevel.Medium,
)

data class StudyFocusCard(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val note: String = "",
    val priorities: List<StudyPriorityItem> = emptyList(),
    val notifyPriorities: Boolean = true,
    val updatedAtMillis: Long = System.currentTimeMillis(),
) {
    fun sessionPrompts(base: List<String>): List<String> {
        val ordered = priorities.sortedBy {
            when (it.level) {
                StudyPriorityLevel.High -> 0
                StudyPriorityLevel.Medium -> 1
                StudyPriorityLevel.Low -> 2
            }
        }.map { "Prioridade ${it.level.label}: ${it.title}" }
        return if (ordered.isEmpty()) base else ordered + base
    }
}

data class StudyFocusSessionRecord(
    val id: String = UUID.randomUUID().toString(),
    val cardName: String,
    val durationSeconds: Int,
    val endedAtMillis: Long = System.currentTimeMillis(),
    val prioritiesCount: Int = 0,
)

object StudyFocusStore {
    private const val Prefs = "study_focus.v1"
    private const val KeyCards = "cards"
    private const val KeySessions = "sessions"
    private const val KeyLastInsightDay = "last_insight_day"
    private const val KeyLastProgressDay = "last_progress_day"
    private const val KeyLastStudyAt = "last_study_at"
    private const val MaxSessions = 120

    fun loadCards(context: Context): List<StudyFocusCard> {
        val raw = prefs(context).getString(KeyCards, null) ?: return seedIfEmpty(context)
        val decoded = runCatching {
            val arr = JSONArray(raw)
            buildList {
                for (i in 0 until arr.length()) {
                    add(decodeCard(arr.getJSONObject(i)))
                }
            }.sortedByDescending { it.updatedAtMillis }
        }.getOrDefault(emptyList())
        return if (decoded.isEmpty()) seedIfEmpty(context) else decoded
    }

    fun saveCards(context: Context, cards: List<StudyFocusCard>) {
        val arr = JSONArray()
        cards.forEach { arr.put(encodeCard(it)) }
        prefs(context).edit().putString(KeyCards, arr.toString()).apply()
    }

    fun upsert(context: Context, card: StudyFocusCard): StudyFocusCard {
        val next = card.copy(updatedAtMillis = System.currentTimeMillis())
        val cards = loadCards(context).toMutableList()
        val idx = cards.indexOfFirst { it.id == next.id }
        if (idx >= 0) cards[idx] = next else cards.add(0, next)
        saveCards(context, cards.sortedByDescending { it.updatedAtMillis })
        return next
    }

    fun delete(context: Context, id: String) {
        saveCards(context, loadCards(context).filterNot { it.id == id })
    }

    fun loadSessions(context: Context): List<StudyFocusSessionRecord> {
        val raw = prefs(context).getString(KeySessions, null) ?: return emptyList()
        return runCatching {
            val arr = JSONArray(raw)
            buildList {
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    add(
                        StudyFocusSessionRecord(
                            id = o.optString("id", UUID.randomUUID().toString()),
                            cardName = o.optString("cardName"),
                            durationSeconds = o.optInt("durationSeconds"),
                            endedAtMillis = o.optLong("endedAtMillis"),
                            prioritiesCount = o.optInt("prioritiesCount"),
                        ),
                    )
                }
            }.sortedByDescending { it.endedAtMillis }
        }.getOrDefault(emptyList())
    }

    fun recordCompletedSession(
        context: Context,
        cardName: String,
        durationSeconds: Int,
        prioritiesCount: Int = 0,
        endedAtMillis: Long = System.currentTimeMillis(),
    ) {
        val next = (
            listOf(
                StudyFocusSessionRecord(
                    cardName = cardName,
                    durationSeconds = durationSeconds.coerceAtLeast(0),
                    endedAtMillis = endedAtMillis,
                    prioritiesCount = prioritiesCount,
                ),
            ) + loadSessions(context)
            ).sortedByDescending { it.endedAtMillis }.take(MaxSessions)
        val arr = JSONArray()
        next.forEach { s ->
            arr.put(
                JSONObject()
                    .put("id", s.id)
                    .put("cardName", s.cardName)
                    .put("durationSeconds", s.durationSeconds)
                    .put("endedAtMillis", s.endedAtMillis)
                    .put("prioritiesCount", s.prioritiesCount),
            )
        }
        prefs(context).edit()
            .putString(KeySessions, arr.toString())
            .putLong(KeyLastStudyAt, endedAtMillis)
            .apply()
    }

    fun lastStudyAt(context: Context): Long = prefs(context).getLong(KeyLastStudyAt, 0L)

    fun lastInsightDay(context: Context): String? = prefs(context).getString(KeyLastInsightDay, null)
    fun setLastInsightDay(context: Context, day: String) {
        prefs(context).edit().putString(KeyLastInsightDay, day).apply()
    }

    fun lastProgressDay(context: Context): String? = prefs(context).getString(KeyLastProgressDay, null)
    fun setLastProgressDay(context: Context, day: String) {
        prefs(context).edit().putString(KeyLastProgressDay, day).apply()
    }

    private fun seedIfEmpty(context: Context): List<StudyFocusCard> {
        val seed = listOf(
            StudyFocusCard(
                name = "Sessão de estudo",
                note = "Card padrão — edite, exclua ou crie outros com o nome que quiser.",
                priorities = listOf(
                    StudyPriorityItem(title = "Revisar o conteúdo principal", level = StudyPriorityLevel.High),
                    StudyPriorityItem(title = "Resolver exercícios", level = StudyPriorityLevel.Medium),
                    StudyPriorityItem(title = "Resumo final", level = StudyPriorityLevel.Low),
                ),
            ),
        )
        saveCards(context, seed)
        return seed
    }

    private fun encodeCard(card: StudyFocusCard): JSONObject {
        val priorities = JSONArray()
        card.priorities.forEach { p ->
            priorities.put(
                JSONObject()
                    .put("id", p.id)
                    .put("title", p.title)
                    .put("level", p.level.name),
            )
        }
        return JSONObject()
            .put("id", card.id)
            .put("name", card.name)
            .put("note", card.note)
            .put("notifyPriorities", card.notifyPriorities)
            .put("updatedAtMillis", card.updatedAtMillis)
            .put("priorities", priorities)
    }

    private fun decodeCard(o: JSONObject): StudyFocusCard {
        val arr = o.optJSONArray("priorities") ?: JSONArray()
        val priorities = buildList {
            for (i in 0 until arr.length()) {
                val p = arr.getJSONObject(i)
                add(
                    StudyPriorityItem(
                        id = p.optString("id", UUID.randomUUID().toString()),
                        title = p.optString("title"),
                        level = runCatching {
                            StudyPriorityLevel.valueOf(p.optString("level", "Medium"))
                        }.getOrDefault(StudyPriorityLevel.Medium),
                    ),
                )
            }
        }
        return StudyFocusCard(
            id = o.optString("id", UUID.randomUUID().toString()),
            name = o.optString("name", "Meu estudo"),
            note = o.optString("note"),
            priorities = priorities,
            notifyPriorities = o.optBoolean("notifyPriorities", true),
            updatedAtMillis = o.optLong("updatedAtMillis", System.currentTimeMillis()),
        )
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(Prefs, Context.MODE_PRIVATE)
}
