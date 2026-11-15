package com.healthfit.android.ui.home

import com.healthfit.android.ui.workouts.FemaleProgram
import com.healthfit.android.ui.workouts.MaleProgram
import com.healthfit.android.ui.workouts.Muscle
import com.healthfit.android.ui.workouts.WorkoutCatalog
import com.healthfit.android.ui.workouts.WorkoutSheet
import java.util.Calendar
import java.util.concurrent.TimeUnit

enum class WorkoutSuggestionSource {
    CoachRoutine,
    UserHistory,
}

data class WorkoutOfTheDaySuggestion(
    val sheet: WorkoutSheet,
    val avoidedMuscles: List<Muscle>,
    val focusMuscles: List<Muscle>,
    val reason: String,
    val source: WorkoutSuggestionSource = WorkoutSuggestionSource.UserHistory,
) {
    val isFromCoach: Boolean get() = source == WorkoutSuggestionSource.CoachRoutine
}

data class MuscleGroupStat(
    val group: Muscle,
    val sessionHits: Int,
    val exerciseHits: Int,
)

data class CardioTypeStat(
    val name: String,
    val count: Int,
)

data class MuscleGroupPeriodReport(
    val periodLabel: String,
    val stats: List<MuscleGroupStat>,
    val suggestions: List<String>,
    val totalStrengthSessions: Int,
    val totalCardioSessions: Int = 0,
    val cardioByType: List<CardioTypeStat> = emptyList(),
)

object WorkoutDaySuggestionAnalyzer {
    private val tracked = listOf(
        Muscle.chest, Muscle.back, Muscle.legs, Muscle.shoulders, Muscle.arms, Muscle.core,
    )

    fun muscleLabel(muscle: Muscle): String = when (muscle) {
        Muscle.chest -> "Peito"
        Muscle.back -> "Costas"
        Muscle.legs -> "Pernas"
        Muscle.shoulders -> "Ombros"
        Muscle.arms -> "Braços"
        Muscle.core -> "Abdômen"
        Muscle.fullBody -> "Corpo inteiro"
    }

    /**
     * Com personal + fichas prescritas, verifica cumprimento da rotina do coach.
     * Sem personal (ou sem fichas), mantém a análise pelos treinos feitos pelo usuário.
     */
    fun suggestWorkoutOfTheDay(
        sessions: List<ConstancySession>,
        female: Boolean = false,
        hasPersonalTrainer: Boolean = false,
        personalName: String? = null,
        nowMillis: Long = System.currentTimeMillis(),
    ): WorkoutOfTheDaySuggestion? {
        val coachSheets = coachPrescribedSheets(female)
            .filter { it.exercises.isNotEmpty() }
            .distinctBy { it.title }

        if (hasPersonalTrainer && coachSheets.isNotEmpty()) {
            return suggestCoachRoutine(
                sessions = sessions,
                coachSheets = coachSheets,
                personalName = personalName,
                nowMillis = nowMillis,
            )
        }

        return suggestFromUserHistory(
            sessions = sessions,
            female = female,
            nowMillis = nowMillis,
        )
    }

    private fun suggestCoachRoutine(
        sessions: List<ConstancySession>,
        coachSheets: List<WorkoutSheet>,
        personalName: String?,
        nowMillis: Long,
    ): WorkoutOfTheDaySuggestion? {
        val since2d = nowMillis - TimeUnit.DAYS.toMillis(2)
        val since7d = nowMillis - TimeUnit.DAYS.toMillis(7)
        val recent2d = strengthSessions(sessions, since2d, nowMillis)
        val avoided = musclesTrained(recent2d).toMutableSet().also { it.remove(Muscle.fullBody) }
        val coachKeys = coachSheets.map { normalize(it.title) }.toSet()
        val recentCoach = strengthSessions(sessions, since7d, nowMillis)
            .filter { normalize(it.title) in coachKeys }
        val daysSinceCoach = recentCoach.maxOfOrNull { it.endedAtMillis }?.let { last ->
            TimeUnit.MILLISECONDS.toDays(nowMillis - last).toInt().coerceAtLeast(0)
        }
        val isBehind = recentCoach.isEmpty()

        val lastDone = mutableMapOf<String, Long>()
        for (session in strengthSessions(sessions, 0L, nowMillis)) {
            val key = normalize(session.title)
            if (key !in coachKeys) continue
            val prev = lastDone[key] ?: 0L
            if (session.endedAtMillis >= prev) lastDone[key] = session.endedAtMillis
        }
        val recent2dTitles = recent2d.map { normalize(it.title) }.toSet()

        data class Scored(val sheet: WorkoutSheet, val focus: List<Muscle>, val score: Int)

        val scored = coachSheets.map { sheet ->
            val focus = primaryMuscles(sheet)
            var score = 200
            val key = normalize(sheet.title)
            val overlap = focus.toSet().intersect(avoided)
            score -= overlap.size * 30
            if (key in recent2dTitles) score -= 50
            val done = lastDone[key]
            if (done != null) {
                val days = TimeUnit.MILLISECONDS.toDays(nowMillis - done).toInt()
                score += days.coerceAtMost(21) * 4
            } else {
                score += 80
            }
            if (avoided.isNotEmpty()) {
                score += focus.toSet().subtract(avoided).size * 12
            }
            Scored(sheet, focus, score)
        }.sortedWith(compareByDescending<Scored> { it.score }.thenBy { it.sheet.title })

        val best = scored.firstOrNull() ?: return null
        val avoidedList = avoided.sortedBy { muscleLabel(it) }
        val coachLabel = personalName?.trim().orEmpty().ifBlank { "seu personal" }
        val reason = when {
            isBehind ->
                "Você tem rotina de $coachLabel e está há 7+ dias sem cumprir as fichas prescritas. Priorize “${best.sheet.title}” para voltar ao plano."
            daysSinceCoach != null && daysSinceCoach >= 3 ->
                "Rotina de $coachLabel: faz $daysSinceCoach dia(s) desde o último treino prescrito. Hoje a sugestão é “${best.sheet.title}”."
            avoidedList.isEmpty() ->
                "Seguindo a rotina de $coachLabel — próxima ficha sugerida: “${best.sheet.title}”."
            else -> {
                val names = avoidedList.joinToString(", ") { muscleLabel(it) }
                "Rotina de $coachLabel: você treinou $names recentemente. “${best.sheet.title}” encaixa melhor no plano e na recuperação."
            }
        }
        return WorkoutOfTheDaySuggestion(
            sheet = best.sheet,
            avoidedMuscles = avoidedList,
            focusMuscles = best.focus,
            reason = reason,
            source = WorkoutSuggestionSource.CoachRoutine,
        )
    }

    private fun suggestFromUserHistory(
        sessions: List<ConstancySession>,
        female: Boolean,
        nowMillis: Long,
    ): WorkoutOfTheDaySuggestion? {
        val catalog = if (female) WorkoutCatalog.female else WorkoutCatalog.male
        val home = WorkoutCatalog.home
        val candidates = (catalog + home)
            .distinctBy { it.title }
            .filter { it.exercises.isNotEmpty() }
        if (candidates.isEmpty()) return null

        val since = nowMillis - TimeUnit.DAYS.toMillis(2)
        val recent = strengthSessions(sessions, since, nowMillis)
        val avoided = musclesTrained(recent).toMutableSet().also { it.remove(Muscle.fullBody) }
        val recentTitles = recent.map { normalize(it.title) }.toSet()

        data class Scored(val sheet: WorkoutSheet, val focus: List<Muscle>, val score: Int)

        val scored = candidates.map { sheet ->
            val focus = primaryMuscles(sheet)
            var score = 100
            val overlap = focus.toSet().intersect(avoided)
            score -= overlap.size * 35
            if (normalize(sheet.title) in recentTitles) score -= 40
            if (avoided.isNotEmpty()) {
                score += focus.toSet().subtract(avoided).size * 18
            }
            val title = sheet.title.lowercase()
            if (listOf("push", "pull", "legs", "peito", "costas", "pernas", "atleta").any { title.contains(it) }) {
                score += 6
            }
            Scored(sheet, focus, score)
        }.sortedWith(compareByDescending<Scored> { it.score }.thenBy { it.sheet.title })

        val best = scored.firstOrNull() ?: return null
        val avoidedList = avoided.sortedBy { muscleLabel(it) }
        val reason = if (avoidedList.isEmpty()) {
            "Sem treino de musculação nos últimos 2 dias — boa hora para retomar."
        } else {
            val names = avoidedList.joinToString(", ") { muscleLabel(it) }
            "Você treinou $names nos últimos 2 dias. Hoje o foco evita repetir esses grupos."
        }
        return WorkoutOfTheDaySuggestion(
            sheet = best.sheet,
            avoidedMuscles = avoidedList,
            focusMuscles = best.focus,
            reason = reason,
            source = WorkoutSuggestionSource.UserHistory,
        )
    }

    private fun coachPrescribedSheets(female: Boolean): List<WorkoutSheet> {
        val personal = if (female) FemaleProgram.personal else MaleProgram.personal
        return listOf(personal).filter { isCoachPrescribed(it) || it.exercises.isNotEmpty() }
    }

    private fun isCoachPrescribed(sheet: WorkoutSheet): Boolean {
        val blob = "${sheet.title} ${sheet.description}".lowercase()
        return blob.contains("ficha do personal") ||
            blob.contains("prescrita") ||
            blob.contains("prescrito") ||
            blob.contains("do personal")
    }

    fun report(
        sessions: List<ConstancySession>,
        days: Int,
        periodLabel: String,
        nowMillis: Long = System.currentTimeMillis(),
    ): MuscleGroupPeriodReport {
        val since = nowMillis - TimeUnit.DAYS.toMillis(days.toLong())
        val window = strengthSessions(sessions, since, nowMillis)
        val sessionHits = mutableMapOf<Muscle, Int>()
        val exerciseHits = mutableMapOf<Muscle, Int>()

        for (session in window) {
            val groups = musclesForSession(session)
            for (group in groups) {
                if (group == Muscle.fullBody) {
                    listOf(Muscle.chest, Muscle.back, Muscle.legs, Muscle.shoulders, Muscle.arms).forEach {
                        sessionHits[it] = (sessionHits[it] ?: 0) + 1
                        exerciseHits[it] = (exerciseHits[it] ?: 0) + 1
                    }
                } else {
                    sessionHits[group] = (sessionHits[group] ?: 0) + 1
                    exerciseHits[group] = (exerciseHits[group] ?: 0) + 1
                }
            }
        }

        val stats = tracked.map { group ->
            MuscleGroupStat(
                group = group,
                sessionHits = sessionHits[group] ?: 0,
                exerciseHits = exerciseHits[group] ?: 0,
            )
        }.sortedWith(
            compareByDescending<MuscleGroupStat> { it.sessionHits }
                .thenByDescending { it.exerciseHits }
                .thenBy { muscleLabel(it.group) },
        )

        val cardioWindow = cardioSessions(sessions, since, nowMillis)
        val cardioCounts = linkedMapOf<String, Int>()
        for (session in cardioWindow) {
            val name = cardioDisplayName(session)
            cardioCounts[name] = (cardioCounts[name] ?: 0) + 1
        }
        val cardioByType = cardioCounts.entries
            .map { CardioTypeStat(it.key, it.value) }
            .sortedWith(compareByDescending<CardioTypeStat> { it.count }.thenBy { it.name })

        return MuscleGroupPeriodReport(
            periodLabel = periodLabel,
            stats = stats,
            suggestions = buildSuggestions(stats, window.size, cardioWindow.size),
            totalStrengthSessions = window.size,
            totalCardioSessions = cardioWindow.size,
            cardioByType = cardioByType,
        )
    }

    fun strengthSessionsThisWeek(
        sessions: List<ConstancySession>,
        nowMillis: Long = System.currentTimeMillis(),
    ): Int {
        val cal = Calendar.getInstance().apply { timeInMillis = nowMillis }
        cal.set(Calendar.DAY_OF_WEEK, cal.firstDayOfWeek)
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return strengthSessions(sessions, cal.timeInMillis, nowMillis).size
    }

    private fun strengthSessions(
        sessions: List<ConstancySession>,
        fromMillis: Long,
        toMillis: Long,
    ): List<ConstancySession> = sessions.filter { session ->
        session.endedAtMillis in fromMillis..toMillis &&
            !isCardioOrMeditation(session)
    }

    private fun cardioSessions(
        sessions: List<ConstancySession>,
        fromMillis: Long,
        toMillis: Long,
    ): List<ConstancySession> = sessions.filter { session ->
        session.endedAtMillis in fromMillis..toMillis && isCardioSession(session)
    }

    private fun isCardioSession(session: ConstancySession): Boolean {
        val kind = session.kind.lowercase()
        val title = session.title.lowercase()
        if (kind.contains("meditation") || kind.contains("medita") || title.contains("medita")) return false
        if (kind.contains("cardio")) return true
        return listOf(
            "caminhada", "corrida", "bike", "bicicleta", "natação", "natacao", "remo",
            "surf", "kite", "esteira", "elíptico", "eliptico", "escada", "cardio",
        ).any { title.contains(it) }
    }

    private fun cardioDisplayName(session: ConstancySession): String {
        val raw = session.title.trim()
        val lower = raw.lowercase()
        var rest = raw
        for (prefix in listOf("Cardio — ", "Cardio - ", "Cardio – ", "Cardio: ", "Cardio ")) {
            if (lower.startsWith(prefix.lowercase())) {
                rest = raw.drop(prefix.length).trim()
                break
            }
        }
        rest = rest.substringBefore("·").substringBefore("|").trim()
        val known = listOf(
            "Kitesurf", "Surf", "Natação", "Bicicleta", "Caminhada", "Corrida",
            "Remo", "Esteira", "Elíptico", "Escada", "Mountain Bike", "Tênis",
        )
        known.firstOrNull { rest.contains(it, ignoreCase = true) }?.let { return it }
        return rest.ifBlank { "Cardio" }
    }

    private fun isCardioOrMeditation(session: ConstancySession): Boolean {
        val kind = session.kind.lowercase()
        val title = session.title.lowercase()
        if (kind.contains("cardio") || kind.contains("meditation") || kind.contains("medita")) return true
        return listOf("caminhada", "corrida", "bike", "natação", "nata", "medita", "remo", "surf", "kite")
            .any { title.contains(it) }
    }

    private fun musclesTrained(sessions: List<ConstancySession>): Set<Muscle> =
        sessions.flatMap { musclesForSession(it) }.toSet()

    private fun musclesForSession(session: ConstancySession): Set<Muscle> {
        findSheet(session.title)?.let { return primaryMuscles(it).toSet() }
        return inferMusclesFromTitle(session.title)
    }

    private fun findSheet(title: String): WorkoutSheet? {
        val key = normalize(title)
        val all = WorkoutCatalog.male + WorkoutCatalog.female + WorkoutCatalog.home +
            WorkoutCatalog.mobility + listOf(MaleProgram.personal, FemaleProgram.personal)
        return all.firstOrNull { normalize(it.title) == key }
            ?: all.firstOrNull { key.contains(normalize(it.title)) || normalize(it.title).contains(key) }
    }

    private fun primaryMuscles(sheet: WorkoutSheet): List<Muscle> {
        val counts = linkedMapOf<Muscle, Int>()
        for (exercise in sheet.exercises) {
            val group = if (exercise.muscle == Muscle.fullBody) Muscle.legs else exercise.muscle
            counts[group] = (counts[group] ?: 0) + 1
        }
        return counts.entries
            .sortedWith(compareByDescending<Map.Entry<Muscle, Int>> { it.value }.thenBy { muscleLabel(it.key) })
            .take(3)
            .map { it.key }
    }

    private fun inferMusclesFromTitle(title: String): Set<Muscle> {
        val t = title.lowercase()
        val result = linkedSetOf<Muscle>()
        if (t.contains("peito") || t.contains("chest") || t.contains("push")) result += Muscle.chest
        if (t.contains("costas") || t.contains("back") || t.contains("pull")) result += Muscle.back
        if (t.contains("perna") || t.contains("legs") || t.contains("inferior") || t.contains("glúteo") || t.contains("gluteo")) {
            result += Muscle.legs
        }
        if (t.contains("ombro") || t.contains("shoulder") || t.contains("deltoid")) result += Muscle.shoulders
        if (t.contains("braço") || t.contains("braco") || t.contains("bíceps") || t.contains("biceps") ||
            t.contains("tríceps") || t.contains("triceps")
        ) {
            result += Muscle.arms
        }
        if (t.contains("abdômen") || t.contains("abdomen") || t.contains("core")) result += Muscle.core
        if (result.isEmpty() && (t.contains("full") || t.contains("corpo") || t.contains("full body"))) {
            result += setOf(Muscle.chest, Muscle.back, Muscle.legs, Muscle.shoulders, Muscle.arms)
        }
        return result
    }

    private fun buildSuggestions(
        stats: List<MuscleGroupStat>,
        sessions: Int,
        cardioSessions: Int,
    ): List<String> {
        if (sessions <= 0 && cardioSessions <= 0) {
            return listOf("Registre treinos de musculação e cardio para ver o equilíbrio e receber sugestões.")
        }
        val tips = mutableListOf<String>()
        val maxHits = stats.maxOfOrNull { it.sessionHits } ?: 0
        val minHits = stats.minOfOrNull { it.sessionHits } ?: 0
        val under = stats.filter { it.sessionHits == minHits && it.sessionHits < maxOf(1, maxHits - 1) }
        val over = stats.filter { it.sessionHits == maxHits && maxHits >= 3 }

        if (sessions == 0) {
            tips += "Nenhuma musculação no período. Combine força com cardio para evoluir melhor."
        }
        if (under.isNotEmpty() && sessions > 0 && maxHits - minHits >= 2) {
            val names = under.take(2).joinToString(" e ") { muscleLabel(it.group) }
            tips += "Priorize $names — está(ão) abaixo dos grupos mais treinados."
        }
        val chest = stats.firstOrNull { it.group == Muscle.chest }
        val back = stats.firstOrNull { it.group == Muscle.back }
        if (chest != null && back != null && chest.sessionHits >= back.sessionHits + 2) {
            tips += "Peito aparece mais que costas. Inclua puxadas/remadas para equilíbrio postural."
        }
        val legs = stats.firstOrNull { it.group == Muscle.legs }
        if (legs != null && legs.sessionHits == 0 && sessions >= 2) {
            tips += "Pernas ainda não entraram no período. Um treino de inferiores melhora recuperação."
        }
        if (over.size == 1) {
            val hot = over.first()
            if (hot.sessionHits >= 4) {
                tips += "${muscleLabel(hot.group)} foi muito estimulado (${hot.sessionHits}×). Garanta 48h de descanso nesse grupo."
            }
        }
        if (cardioSessions == 0 && sessions >= 2) {
            tips += "Inclua cardio (caminhada, corrida ou bike) 1–2× na semana para condicionamento."
        } else if (cardioSessions >= 5 && sessions == 0) {
            tips += "Muito cardio e pouca força. Adicione musculação para preservar massa muscular."
        }
        if (tips.isEmpty()) {
            tips += "Boa distribuição de estímulos. Mantenha a frequência e progresse carga com técnica."
        }
        return tips.take(4)
    }

    private fun normalize(name: String): String =
        name.trim().lowercase()
            .replace("á", "a").replace("à", "a").replace("ã", "a").replace("â", "a")
            .replace("é", "e").replace("ê", "e")
            .replace("í", "i")
            .replace("ó", "o").replace("ô", "o").replace("õ", "o")
            .replace("ú", "u").replace("ç", "c")
}
