package com.healthfit.android.ui.assistant

import android.content.Context
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/** Mensagens de incentivo do IAssistente para o HealthFit Pulse (máx. 2×/dia). */
object AssistantPulseNudgeEngine {
    private const val PREFS = "assistant_pulse_nudge.v1"

    enum class Slot(val key: String) {
        Morning("morning"),
        Evening("evening");

        companion object {
            fun current(now: Calendar = Calendar.getInstance()): Slot {
                val hour = now.get(Calendar.HOUR_OF_DAY)
                return if (hour < 15) Morning else Evening
            }
        }
    }

    fun shouldDeliver(context: Context, now: Calendar = Calendar.getInstance()): Boolean {
        val day = dayStamp(now.time)
        val slot = Slot.current(now)
        val key = "slot.$day.${slot.key}"
        return !prefs(context).getBoolean(key, false)
    }

    fun markDelivered(context: Context, now: Calendar = Calendar.getInstance()) {
        val day = dayStamp(now.time)
        val slot = Slot.current(now)
        prefs(context).edit()
            .putBoolean("slot.$day.${slot.key}", true)
            .putString("lastDay", day)
            .apply()
    }

    fun message(athleteName: String, slot: Slot = Slot.current()): String {
        val name = athleteName.trim().ifBlank { "Atleta" }
        return when (slot) {
            Slot.Morning -> """
                Bom dia, $name! 💚

                Que tal começar o dia no HealthFit Pulse? Veja o que a comunidade treinou, compartilhe sua evolução e inspire (e se inspire).

                Abra o card Pulse no Dashboard — 1 minuto já muda o ritmo do dia. 🔥
            """.trimIndent()
            Slot.Evening -> """
                Ei, $name! 🌙

                Antes de encerrar o dia, passe no HealthFit Pulse: curta treinos, poste o seu e mantenha a constância com a galera.

                Toque em Pulse no Dashboard e deixe o feed trabalhar a favor da sua rotina. 💪
            """.trimIndent()
        }
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun dayStamp(date: Date): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        return formatter.format(date)
    }
}
