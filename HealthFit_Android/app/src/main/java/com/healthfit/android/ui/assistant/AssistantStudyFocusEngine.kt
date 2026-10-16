package com.healthfit.android.ui.assistant

import com.healthfit.android.ui.workouts.StudyFocusSessionRecord
import java.util.Calendar
import java.util.concurrent.TimeUnit

data class StudyFocusRoutineProfile(
    val preferredHour: Int? = null,
    val preferredWeekdays: List<Int> = emptyList(),
    val usualSessionsPerWeek: Double = 0.0,
    val usualMinutesPerWeek: Double = 0.0,
    val usualWindowLabel: String? = null,
    val weekdayHabitLabel: String? = null,
    val streakDays: Int = 0,
    val hasEnoughData: Boolean = false,
    val summaryLine: String? = null,
)

/** IAssistente: aprende rotina de Foco em Estudo e gera avisos de progresso. */
object AssistantStudyFocusEngine {
    private const val MinSessions = 3
    private const val LookbackDays = 45
    const val InactivityMs: Long = 48L * 60L * 60L * 1000L

    fun buildProfile(
        sessions: List<StudyFocusSessionRecord>,
        nowMillis: Long = System.currentTimeMillis(),
    ): StudyFocusRoutineProfile {
        val cutoff = nowMillis - TimeUnit.DAYS.toMillis(LookbackDays.toLong())
        val completed = sessions.filter { it.endedAtMillis >= cutoff }
        val hourBuckets = completed.groupBy { hourOf(it.endedAtMillis) }
        val preferredHour = hourBuckets.maxWithOrNull(compareBy({ it.value.size }, { it.key }))?.key
        val weekdayBuckets = completed.groupBy { weekdayOf(it.endedAtMillis) }
        val topWeekdays = weekdayBuckets.entries
            .sortedByDescending { it.value.size }
            .take(3)
            .filter { it.value.size >= 2 }
            .map { it.key }
        val weeks = maxOf(1.0, LookbackDays / 7.0)
        val usualPerWeek = completed.size / weeks
        val usualMinutes = completed.sumOf { it.durationSeconds / 60.0 } / weeks
        val window = preferredHour?.takeIf { completed.size >= MinSessions }?.let {
            "entre ${it}h e ${minOf(23, it + 2)}h"
        }
        val weekdays = topWeekdays.takeIf { it.isNotEmpty() && completed.size >= MinSessions }
            ?.joinToString(", ") { weekdayName(it) }
        val streak = consecutiveDays(completed, nowMillis)
        val hasEnough = completed.size >= MinSessions
        val summary = if (!hasEnough) {
            null
        } else {
            val parts = mutableListOf<String>()
            if (window != null) parts += "você costuma estudar $window"
            if (weekdays != null) parts += "mais em $weekdays"
            if (usualPerWeek >= 1) {
                parts += "média de ${"%.1f".format(usualPerWeek)} sessões/semana (${"%.0f".format(usualMinutes)} min)"
            }
            if (streak >= 2) parts += "sequência atual de $streak dias"
            if (parts.isEmpty()) null else parts.joinToString("; ") + "."
        }
        return StudyFocusRoutineProfile(
            preferredHour = preferredHour,
            preferredWeekdays = topWeekdays,
            usualSessionsPerWeek = usualPerWeek,
            usualMinutesPerWeek = usualMinutes,
            usualWindowLabel = window,
            weekdayHabitLabel = weekdays,
            streakDays = streak,
            hasEnoughData = hasEnough,
            summaryLine = summary,
        )
    }

    fun missedStudyWindowMessage(
        athleteName: String,
        profile: StudyFocusRoutineProfile,
        sessions: List<StudyFocusSessionRecord>,
        lastInsightDay: String?,
        nowMillis: Long = System.currentTimeMillis(),
    ): String? {
        if (!profile.hasEnoughData) return null
        val hour = profile.preferredHour ?: return null
        val window = profile.usualWindowLabel ?: return null
        val day = AssistantRoutineStore.dayKey(nowMillis)
        if (lastInsightDay == day) return null
        if (hourOf(nowMillis) < hour + 1) return null
        if (profile.preferredWeekdays.isNotEmpty() && weekdayOf(nowMillis) !in profile.preferredWeekdays) return null
        val todayStart = startOfDay(nowMillis)
        if (sessions.any { it.endedAtMillis >= todayStart }) return null
        val name = athleteName.ifBlank { "Atleta" }
        val lines = mutableListOf(
            "$name, aprendi sua rotina de Foco em Estudo: $window costuma ser seu horário.",
            "",
            "Hoje ainda não vi sessão de estudo nessa janela. Mesmo 10–15 minutos mantêm o hábito.",
            "",
            "Abra Treinos → Meditação → Foco em Estudo e retome suas prioridades.",
        )
        profile.weekdayHabitLabel?.let {
            lines += ""
            lines += "Seus dias mais fortes de estudo: $it."
        }
        return lines.joinToString("\n")
    }

    fun progressMessage(
        athleteName: String,
        profile: StudyFocusRoutineProfile,
        sessions: List<StudyFocusSessionRecord>,
        lastProgressDay: String?,
        nowMillis: Long = System.currentTimeMillis(),
    ): String? {
        val day = AssistantRoutineStore.dayKey(nowMillis)
        if (lastProgressDay == day) return null
        val hour = hourOf(nowMillis)
        if (hour !in 11 until 21) return null
        val weekStart = startOfWeek(nowMillis)
        val week = sessions.filter { it.endedAtMillis >= weekStart }
        val weekMinutes = week.sumOf { it.durationSeconds / 60 }
        val weekCount = week.size
        if (weekCount == 0 && !profile.hasEnoughData) return null
        val name = athleteName.ifBlank { "Atleta" }
        val bullets = mutableListOf(
            "Esta semana: $weekCount sessão${if (weekCount == 1) "" else "ões"} · $weekMinutes min de foco.",
        )
        if (profile.hasEnoughData && profile.usualSessionsPerWeek >= 1) {
            if (weekCount + 0.4 < profile.usualSessionsPerWeek) {
                bullets += "Você está um pouco abaixo da sua média (${"%.1f".format(profile.usualSessionsPerWeek)} sessões/semana)."
            } else if (weekCount > 0) {
                bullets += "Ritmo alinhado (ou acima) da sua média de estudo — ótimo progresso."
            }
        }
        if (profile.streakDays >= 2) bullets += "Sequência: ${profile.streakDays} dias com Foco em Estudo."
        profile.usualWindowLabel?.let { bullets += "Horário aprendido: $it." }
        if (bullets.size < 2) return null
        val lines = mutableListOf(
            "$name, atualização de progresso no Foco em Estudo:",
            "",
        )
        bullets.take(5).forEach { lines += "• $it" }
        lines += ""
        lines += "Continue em Treinos → Meditação → Foco em Estudo. Estou acompanhando sua rotina."
        return lines.joinToString("\n")
    }

    fun inactivityMessage(athleteName: String): String {
        val name = athleteName.ifBlank { "Atleta" }
        return """
            Ei, $name! Faz cerca de 48 horas sem Foco em Estudo.

            Manter a rotina de concentração fortalece memória, disciplina e progresso nas suas prioridades.

            Estímulo: 15–20 minutos bastam. Abra o card de estudo, marque a prioridade #1 e inicie.

            Treinos → Meditação → Foco em Estudo
        """.trimIndent()
    }

    fun notificationProgressBody(profile: StudyFocusRoutineProfile, weekMinutes: Int, weekCount: Int): String =
        when {
            profile.streakDays >= 2 ->
                "$weekCount sessões · $weekMinutes min esta semana · sequência de ${profile.streakDays} dias. Continue o Foco em Estudo!"
            weekCount > 0 ->
                "Progresso: $weekCount sessão${if (weekCount == 1) "" else "ões"} e $weekMinutes min de estudo esta semana."
            profile.usualWindowLabel != null ->
                "Sua rotina de estudo costuma ser ${profile.usualWindowLabel}. Que tal encaixar uma sessão hoje?"
            else ->
                "Registre uma sessão de Foco em Estudo para eu aprender sua rotina e acompanhar o progresso."
        }

    fun evaluateInactivity(
        sessions: List<StudyFocusSessionRecord>,
        lastStudyMillis: Long,
        nowMillis: Long = System.currentTimeMillis(),
    ): Long? {
        val reference = sessions.maxOfOrNull { it.endedAtMillis }?.takeIf { it > 0 } ?: lastStudyMillis
        if (reference <= 0L) return null
        return if (nowMillis - reference >= InactivityMs) reference else null
    }

    private fun consecutiveDays(sessions: List<StudyFocusSessionRecord>, nowMillis: Long): Int {
        val keys = sessions.map { AssistantRoutineStore.dayKey(it.endedAtMillis) }.toSet()
        if (keys.isEmpty()) return 0
        var streak = 0
        var cursor = nowMillis
        while (AssistantRoutineStore.dayKey(cursor) in keys) {
            streak++
            cursor -= TimeUnit.DAYS.toMillis(1)
        }
        return streak
    }

    private fun hourOf(millis: Long): Int =
        Calendar.getInstance().apply { timeInMillis = millis }.get(Calendar.HOUR_OF_DAY)

    private fun weekdayOf(millis: Long): Int =
        Calendar.getInstance().apply { timeInMillis = millis }.get(Calendar.DAY_OF_WEEK)

    private fun startOfDay(millis: Long): Long =
        Calendar.getInstance().apply {
            timeInMillis = millis
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

    private fun startOfWeek(millis: Long): Long =
        Calendar.getInstance().apply {
            timeInMillis = millis
            firstDayOfWeek = Calendar.MONDAY
            set(Calendar.DAY_OF_WEEK, firstDayOfWeek)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

    private fun weekdayName(weekday: Int): String = when (weekday) {
        Calendar.SUNDAY -> "domingo"
        Calendar.MONDAY -> "segunda"
        Calendar.TUESDAY -> "terça"
        Calendar.WEDNESDAY -> "quarta"
        Calendar.THURSDAY -> "quinta"
        Calendar.FRIDAY -> "sexta"
        Calendar.SATURDAY -> "sábado"
        else -> "dia $weekday"
    }
}
