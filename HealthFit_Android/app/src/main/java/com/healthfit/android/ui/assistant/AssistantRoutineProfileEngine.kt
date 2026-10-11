package com.healthfit.android.ui.assistant

import com.healthfit.android.ui.home.DailyWellness
import java.util.Calendar
import java.util.concurrent.TimeUnit

data class AssistantRoutineProfile(
    val preferredWorkoutHour: Int? = null,
    val preferredWeekdays: List<Int> = emptyList(),
    val usualSessionsPerWeek: Double = 0.0,
    val recentTiredRate: Double = 0.0,
    val recentPositiveRate: Double = 0.0,
    val usualWindowLabel: String? = null,
    val weekdayHabitLabel: String? = null,
    val summaryLine: String? = null,
    val hasEnoughData: Boolean = false,
) {
    companion object {
        val Empty = AssistantRoutineProfile()
    }
}

object AssistantRoutineProfileEngine {
    private const val MinSessionsForHabit = 4
    private const val LookbackDays = 45

    fun buildProfile(
        snapshot: AssistantRoutineSnapshot,
        nowMillis: Long = System.currentTimeMillis(),
    ): AssistantRoutineProfile {
        val cutoff = nowMillis - TimeUnit.DAYS.toMillis(LookbackDays.toLong())
        val completed = snapshot.sessions.filter { it.endedAtMillis >= cutoff }

        val hourBuckets = completed.groupBy { hourOf(it.endedAtMillis) }
        val preferredHour = hourBuckets.maxWithOrNull(
            compareBy({ it.value.size }, { it.key }),
        )?.key

        val weekdayBuckets = completed.groupBy { weekdayOf(it.endedAtMillis) }
        val topWeekdays = weekdayBuckets.entries
            .sortedByDescending { it.value.size }
            .take(3)
            .filter { it.value.size >= 2 }
            .map { it.key }

        val weeks = maxOf(1.0, LookbackDays / 7.0)
        val usualPerWeek = completed.size / weeks

        val recentMoods = snapshot.moodSamples.filter { it.recordedAtMillis >= cutoff }
        val tiredKeys = setOf("tired", "tiring", "stressed", "sore", "unmotivated", "difficult", "anxious")
        val positiveKeys = setOf("great", "good", "peaceful", "readyToSleep")
        val tiredCount = recentMoods.count { it.feeling in tiredKeys }
        val positiveCount = recentMoods.count { it.feeling in positiveKeys }
        val moodTotal = maxOf(1, recentMoods.size)
        val tiredRate = tiredCount.toDouble() / moodTotal
        val positiveRate = positiveCount.toDouble() / moodTotal

        val windowLabel = preferredHour?.takeIf { completed.size >= MinSessionsForHabit }?.let { hour ->
            val end = minOf(23, hour + 2)
            "entre ${hour}h e ${end}h"
        }

        val weekdayLabel = topWeekdays.takeIf { it.isNotEmpty() && completed.size >= MinSessionsForHabit }
            ?.joinToString(", ") { weekdayName(it) }

        val hasEnough = completed.size >= MinSessionsForHabit || recentMoods.size >= 5
        val summary = if (!hasEnough) {
            null
        } else {
            val parts = mutableListOf<String>()
            if (windowLabel != null) parts += "você costuma treinar $windowLabel"
            if (weekdayLabel != null) parts += "com mais frequência em $weekdayLabel"
            when {
                tiredRate >= 0.45 -> parts += "e tem relatado cansaço com frequência nos check-ins"
                positiveRate >= 0.55 -> parts += "e seus check-ins recentes estão majoritariamente positivos"
            }
            if (usualPerWeek >= 1) parts += "média de ${"%.1f".format(usualPerWeek)} treinos/semana"
            if (parts.isEmpty()) null else parts.joinToString("; ") + "."
        }

        return AssistantRoutineProfile(
            preferredWorkoutHour = preferredHour,
            preferredWeekdays = topWeekdays,
            usualSessionsPerWeek = usualPerWeek,
            recentTiredRate = tiredRate,
            recentPositiveRate = positiveRate,
            usualWindowLabel = windowLabel,
            weekdayHabitLabel = weekdayLabel,
            summaryLine = summary,
            hasEnoughData = hasEnough,
        )
    }

    fun welcomePersonalizationLines(profile: AssistantRoutineProfile): List<String> {
        if (!profile.hasEnoughData) return emptyList()
        val lines = mutableListOf("Estou aprendendo sua rotina para personalizar os avisos:")
        val summary = profile.summaryLine
        if (summary != null) {
            lines += "• $summary"
        } else {
            profile.usualWindowLabel?.let { lines += "• Horário habitual de treino: $it" }
            profile.weekdayHabitLabel?.let { lines += "• Dias mais frequentes: $it" }
        }
        return lines
    }

    fun missedWindowMessageIfNeeded(
        athleteName: String,
        profile: AssistantRoutineProfile,
        snapshot: AssistantRoutineSnapshot,
        wellness: DailyWellness,
        nowMillis: Long = System.currentTimeMillis(),
    ): String? {
        if (!profile.hasEnoughData) return null
        val hour = profile.preferredWorkoutHour ?: return null
        val window = profile.usualWindowLabel ?: return null
        val day = AssistantRoutineStore.dayKey(nowMillis)
        if (snapshot.lastInsightDayKey == day) return null

        val currentHour = hourOf(nowMillis)
        if (currentHour < hour + 1) return null

        if (profile.preferredWeekdays.isNotEmpty()) {
            val weekday = weekdayOf(nowMillis)
            if (weekday !in profile.preferredWeekdays) return null
        }

        val todayStart = startOfDay(nowMillis)
        val trainedToday = snapshot.sessions.any { it.endedAtMillis >= todayStart }
        if (trainedToday) return null

        val last = snapshot.sessions.maxOfOrNull { it.endedAtMillis }
        if (last != null && nowMillis - last < TimeUnit.HOURS.toMillis(20)) return null

        val name = athleteName.ifBlank { "Atleta" }
        val lines = mutableListOf(
            "$name, aprendi sua rotina: $window costuma ser seu horário de treino.",
            "",
            "Hoje ainda não vi treino registrado nessa janela. Se puder, encaixe mesmo que seja mais curto — consistência vence intensidade isolada.",
        )
        if (profile.recentTiredRate >= 0.45 || wellness.sleepHours < 7f) {
            lines += ""
            lines += "Como você tem reportado mais cansaço, prefira um treino leve, mobilidade ou caminhada em vez de forçar carga alta."
        }
        profile.weekdayHabitLabel?.let {
            lines += ""
            lines += "Seus dias mais fortes costumam ser: $it."
        }
        return lines.joinToString("\n")
    }

    fun personalizedAnalysisMessageIfNeeded(
        athleteName: String,
        profile: AssistantRoutineProfile,
        snapshot: AssistantRoutineSnapshot,
        wellness: DailyWellness,
        weeklyWorkoutCount: Int,
        nowMillis: Long = System.currentTimeMillis(),
    ): String? {
        val day = AssistantRoutineStore.dayKey(nowMillis)
        if (snapshot.lastAnalysisDayKey == day) return null
        val hour = hourOf(nowMillis)
        if (hour !in 12 until 20) return null

        val name = athleteName.ifBlank { "Atleta" }
        val bullets = mutableListOf<String>()

        when {
            weeklyWorkoutCount == 0 ->
                bullets += "Semana ainda sem treinos registrados — retomar hoje muda o ritmo."
            profile.usualSessionsPerWeek >= 2 && weeklyWorkoutCount + 0.5 < profile.usualSessionsPerWeek ->
                bullets += "Você está abaixo da sua média (${"%.1f".format(profile.usualSessionsPerWeek)} treinos/semana). Já foram $weeklyWorkoutCount nesta semana."
            weeklyWorkoutCount > 0 ->
                bullets += "Treinos na semana: $weeklyWorkoutCount — bom sinal de constância."
        }

        when {
            wellness.sleepHours < 7f ->
                bullets += "Sono de hoje: ${"%.1f".format(wellness.sleepHours)}h — abaixo do ideal (7–9h)."
            wellness.sleepHours > 9f ->
                bullets += "Sono de hoje: ${"%.1f".format(wellness.sleepHours)}h — acima do recomendado; avalie fadiga acumulada."
        }

        if (wellness.goalMl > 0) {
            val pct = (wellness.waterMl * 100 / wellness.goalMl).coerceAtLeast(0)
            if (pct < 60) {
                bullets += "Hidratação em $pct% da meta (${wellness.waterMl} ml de ${wellness.goalMl} ml)."
            }
        }

        when {
            profile.recentTiredRate >= 0.4 ->
                bullets += "Seus check-ins recentes apontam cansaço recorrente — priorize recuperação e carga inteligente."
            profile.recentPositiveRate >= 0.55 ->
                bullets += "Humor e disposição nos check-ins estão positivos — ótimo momento para evoluir com consistência."
        }

        profile.usualWindowLabel?.let { bullets += "Janela habitual de treino aprendida: $it." }

        if (bullets.size < 2) return null

        val sections = mutableListOf(
            "$name, fiz uma leitura personalizada da sua rotina e dos dados de hoje:",
            "",
        )
        bullets.take(5).forEach { sections += "• $it" }
        sections += ""
        profile.summaryLine?.let {
            sections += "O que aprendi sobre você: $it"
            sections += ""
        }
        sections += "Pode me perguntar “o que preciso melhorar?” para um plano mais detalhado."
        return sections.joinToString("\n")
    }

    fun weeklyWorkoutCount(snapshot: AssistantRoutineSnapshot, nowMillis: Long = System.currentTimeMillis()): Int {
        val cal = Calendar.getInstance().apply { timeInMillis = nowMillis }
        cal.set(Calendar.DAY_OF_WEEK, cal.firstDayOfWeek)
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val weekStart = cal.timeInMillis
        return snapshot.sessions.count { it.endedAtMillis >= weekStart }
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
