package com.healthfit.android.ui.home

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import org.json.JSONObject
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import kotlin.math.roundToInt

data class WellnessDayEntry(
    val sleepHours: Float? = null,
    val waterMl: Int = 0,
) {
    val hasSleep: Boolean get() = sleepHours != null
    val hasWater: Boolean get() = waterMl > 0
    val isFilled: Boolean get() = hasSleep || hasWater
    val isComplete: Boolean get() = hasSleep && hasWater
}

/** Sono e água do dia, compartilhados entre o início e o perfil. */
class DailyWellness {
    var sleepHours by mutableFloatStateOf(7f)
    var waterMl by mutableIntStateOf(1250)
    var weightKg by mutableStateOf("94.7")

    /** Dia focado na faixa da semana. */
    var selectedDayKey by mutableStateOf(dayKeyToday())
        private set

    var revision by mutableIntStateOf(0)
        private set

    private var appContext: Context? = null
    private val cache = linkedMapOf<String, WellnessDayEntry>()
    private var sleepLoggedForSelected = true
    private var suppressPersist = false

    val weight: Float
        get() = weightKg.toFloatOrNull()?.takeIf { it in 30f..250f } ?: 94.7f

    val goalMl: Int
        get() = (weight * 35f).roundToInt().coerceAtLeast(500)

    fun bind(context: Context) {
        if (appContext != null) return
        appContext = context.applicationContext
        loadAll()
        val today = dayKeyToday()
        val existing = cache[today]
        suppressPersist = true
        if (existing != null && existing.isFilled) {
            sleepHours = existing.sleepHours ?: 7f
            waterMl = existing.waterMl
            sleepLoggedForSelected = existing.hasSleep
        } else {
            // Primeiro uso: grava o estado atual como hoje (sono + água).
            sleepLoggedForSelected = true
            cache[today] = WellnessDayEntry(sleepHours = sleepHours, waterMl = waterMl)
            persist()
        }
        selectedDayKey = today
        suppressPersist = false
        revision++
    }

    fun entry(dayKey: String): WellnessDayEntry = cache[dayKey] ?: WellnessDayEntry()

    fun selectDay(dayKey: String) {
        saveSelected()
        selectedDayKey = dayKey
        val e = entry(dayKey)
        suppressPersist = true
        sleepLoggedForSelected = e.hasSleep
        sleepHours = e.sleepHours ?: 7f
        waterMl = e.waterMl
        suppressPersist = false
        revision++
    }

    fun addWater(amount: Int) {
        waterMl = (waterMl + amount).coerceAtLeast(0)
        saveSelected()
    }

    fun updateSleep(hours: Float) {
        sleepHours = hours
        sleepLoggedForSelected = true
        saveSelected()
    }

    private fun saveSelected() {
        if (suppressPersist) return
        cache[selectedDayKey] = WellnessDayEntry(
            sleepHours = if (sleepLoggedForSelected) sleepHours else null,
            waterMl = waterMl,
        )
        persist()
        revision++
    }

    private fun loadAll() {
        val raw = prefs()?.getString(KeyEntries, null) ?: return
        runCatching {
            val root = JSONObject(raw)
            root.keys().forEach { key ->
                val o = root.optJSONObject(key) ?: return@forEach
                val sleep = if (o.isNull("sleepHours")) null else o.optDouble("sleepHours").toFloat()
                cache[key] = WellnessDayEntry(sleepHours = sleep, waterMl = o.optInt("waterMl", 0))
            }
        }
    }

    private fun persist() {
        val root = JSONObject()
        cache.forEach { (key, entry) ->
            root.put(
                key,
                JSONObject().apply {
                    if (entry.sleepHours != null) put("sleepHours", entry.sleepHours.toDouble())
                    else put("sleepHours", JSONObject.NULL)
                    put("waterMl", entry.waterMl)
                },
            )
        }
        prefs()?.edit()?.putString(KeyEntries, root.toString())?.apply()
    }

    private fun prefs() =
        appContext?.getSharedPreferences(Prefs, Context.MODE_PRIVATE)

    companion object {
        private const val Prefs = "daily_wellness.v1"
        private const val KeyEntries = "entries"
        private val fmt = DateTimeFormatter.ISO_LOCAL_DATE

        fun dayKeyToday(): String = LocalDate.now().format(fmt)

        fun dayKey(date: LocalDate): String = date.format(fmt)
    }
}
