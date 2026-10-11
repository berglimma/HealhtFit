package com.healthfit.android.ui.assistant

import com.healthfit.android.ui.home.AthleteProfile
import com.healthfit.android.ui.home.DailyWellness
import kotlin.math.roundToInt

object AssistantEngine {
    const val Disclaimer = AssistantTopicEngine.Disclaimer

    /** Delay before any assistant reply (matches product request: 4s typing). */
    const val ReplyDelayMs = 4_000L

    val suggestions = listOf(
        "Montar cardápio personalizado",
        "Montar treino sem personal",
        "Treino em casa funciona?",
        "Como treinar em casa sem equipamento?",
        "Qual é meu IMC?",
        "O que é ectomorfo?",
        "O que é mesomorfo?",
        "O que é endomorfo?",
        "Como dormir corretamente?",
        "Como treinar conforme o personal?",
        "Quanto de proteína comer?",
        "Quantas séries e repetições?",
        "O que fazer no déficit calórico?",
        "Quanto de doce posso comer?",
        "Posso beber álcool ou cerveja?",
        "Horários livres para consulta",
        "Agendar consulta com personal",
        "Agendar consulta com nutricionista",
        "Cerveja zero álcool é liberada?",
        "Cerveja light faz mal?",
        "Treino, cardio ou meditação?",
        "Por que descansar é importante?",
        "Quais suplementos devo tomar?",
        "Para que serve a creatina?",
        "Whey protein faz mal?",
        "Como está minha evolução corporal?",
        "O que preciso melhorar?",
        "Estou ótimo!",
        "Me sinto bem",
        "Mais ou menos",
        "Estou cansado",
        "Sinto dor",
    )

    fun welcome(
        name: String,
        wellness: DailyWellness,
        athlete: AthleteProfile,
        profile: AssistantRoutineProfile = AssistantRoutineProfile.Empty,
        hasWorkoutAlert: Boolean = false,
    ): String {
        val alerts = alerts(wellness)
        val greeting = MotivationMessages.namedGreeting(name).removeSuffix("!")
        val lines = mutableListOf("$greeting. Sou o assistente HealthFit.", "")
        if (alerts.isEmpty()) {
            lines += "Seu dia está no eixo: sono, água e treino dentro do combinado."
        } else {
            lines += "Atenção ao seu dia:"
            alerts.forEach { lines += "• $it" }
        }
        lines += ""
        lines += MotivationMessages.chatWelcomeMotivation(
            hasSleepAlert = alerts.any { it.contains("Sono", ignoreCase = true) },
            hasWaterAlert = alerts.any { it.contains("água", ignoreCase = true) || it.contains("Hidrata", ignoreCase = true) },
            hasWorkoutAlert = hasWorkoutAlert,
        )
        val routineLines = AssistantRoutineProfileEngine.welcomePersonalizationLines(profile)
        if (routineLines.isNotEmpty()) {
            lines += ""
            lines += routineLines
        } else {
            lines += ""
            lines += "Analiso seus dados (treino, sono, água, nutrição e check-ins) e personalizo os avisos conforme sua rotina."
        }
        lines += ""
        lines += "Biotipo ${athlete.bodyType.title.lowercase()} e objetivo ${athlete.objective.lowercase()} valem aqui e em Nutrição."
        lines += "Posso montar cardápio, treino, falar de IMC, sono, proteína, suplemento, cardio, meditação e descanso."
        lines += ""
        lines += Disclaimer
        lines += ""
        lines += "Toque em uma sugestão ou escreva sua pergunta."
        return lines.joinToString("\n")
    }

    fun alerts(wellness: DailyWellness): List<String> {
        val notes = mutableListOf<String>()
        val hours = wellness.sleepHours
        when {
            hours < 6f -> notes += "Sono curto: ${formatHours(hours)} registradas. O ideal é 7–9 h para recuperar o treino."
            hours < 7f -> notes += "Sono abaixo do ideal: ${formatHours(hours)}. Tente chegar entre 7 e 9 horas."
            hours > 9f -> notes += "Sono acima do recomendado: ${formatHours(hours)}. O ideal continua 7–9 h."
        }
        val goal = wellness.goalMl
        if (wellness.waterMl < goal) {
            val pct = (wellness.waterMl * 100 / goal).coerceAtLeast(0)
            val missing = goal - wellness.waterMl
            notes += if (pct < 50) {
                "Hidratação baixa: ${wellness.waterMl} ml de $goal ml ($pct% da meta). Beba água ao longo do dia."
            } else {
                "Meta de água não atingida: ${wellness.waterMl} ml de $goal ml. Faltam $missing ml."
            }
        }
        return notes
    }

    fun reply(
        text: String,
        wellness: DailyWellness,
        athlete: AthleteProfile,
        name: String,
        profile: AssistantRoutineProfile = AssistantRoutineProfile.Empty,
        weeklyWorkoutCount: Int = 0,
        hoursSinceLastWorkout: Double? = null,
    ): String {
        val ctx = AssistantAnswerContext.build(
            name = name,
            wellness = wellness,
            athlete = athlete,
            routine = profile,
            weeklyWorkoutCount = weeklyWorkoutCount,
            hoursSinceLastWorkout = hoursSinceLastWorkout,
        )
        return AssistantTopicEngine.answer(text, ctx)
    }

    private fun formatHours(hours: Float): String {
        val whole = hours.toInt()
        val minutes = ((hours - whole) * 60).roundToInt()
        return if (minutes == 0) "$whole h" else "$whole h ${minutes.toString().padStart(2, '0')} min"
    }
}
