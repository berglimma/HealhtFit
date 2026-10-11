package com.healthfit.android.ui.assistant

import java.text.Normalizer
import kotlin.math.roundToInt

/** Port of iOS AssistantGratitudeEngine. */
object AssistantGratitudeEngine {
    private val tokens = listOf(
        "obrigado", "obrigada", "obrigadao", "muito obrigado", "muito obrigada",
        "obrigadissimo", "obrigadissima", "super obrigado", "super obrigada",
        "grato", "grata", "gratidao", "agradecido", "agradecida",
        "agradecco", "te agradeco",
        "fico grato", "fico grata", "ficamos gratos",
        "valeu", "vlw", "obg", "obgd",
        "thanks", "thank you", "thx", "ty ",
    )

    private val questionHints = listOf(
        "como ", "qual ", "quais ", "quando ", "onde ", "por que", "porque",
        "o que ", "posso ", "devo ", "sera que", "?",
    )

    fun matches(text: String): Boolean {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return false
        val normalized = " ${normalize(trimmed)} "
        if (tokens.none { normalized.contains(it) }) return false

        if (trimmed.length <= 80 && !normalized.contains("?")) return true
        if (questionHints.any { normalized.contains(it) }) return false
        return trimmed.length <= 140
    }

    fun answer(ctx: AssistantAnswerContext): String {
        val greeting = if (ctx.name.isBlank()) "De nada!" else "De nada, ${ctx.name}!"
        return """
            $greeting Eu que agradeço a confiança. 🙏

            Estou aqui no IAssistente para treino, nutrição, rotina e o que mais você precisar. Qualquer dúvida, é só escrever.
        """.trimIndent()
    }

    private fun normalize(text: String): String {
        val stripped = Normalizer.normalize(text, Normalizer.Form.NFD).replace("\\p{Mn}+".toRegex(), "")
        return stripped.lowercase()
    }
}

/**
 * Port of iOS AssistantImprovementAnalysisEngine — simplified using Android context
 * (sleep, water, weeklyWorkoutCount, hoursSinceLastWorkout, routine, calorie target).
 */
object AssistantImprovementAnalysisEngine {
    val intentPhrases: List<String> = listOf(
        "o que preciso melhorar",
        "o que tenho que melhorar",
        "o que devo melhorar",
        "no que preciso melhorar",
        "no que devo melhorar",
        "onde preciso melhorar",
        "o que esta fraco",
        "pontos fracos",
        "ponto fraco",
        "areas de melhoria",
        "area de melhoria",
        "como evoluir",
        "analise do meu progresso",
        "analise de progresso",
        "analise do progresso",
        "analise do desempenho",
        "avaliacao do meu progresso",
        "avaliacao do progresso",
        "feedback do meu progresso",
        "feedback de progresso",
        "como esta meu progresso",
        "como esta o meu progresso",
        "como esta meu desempenho",
        "diagnostico do meu progresso",
        "raio x do meu progresso",
        "balanco da semana",
        "balanco do meu progresso",
        "preciso melhorar",
        "sugira melhorias",
        "sugira o que melhorar",
        "o que melhorar",
        "me da um feedback",
        "me de um feedback",
        "analise meus dados",
        "analise meu progresso",
    )

    fun matches(question: String): Boolean {
        val normalized = normalize(question)
        if (intentPhrases.none { normalized.contains(it) }) return false

        val loadProgressionHints = listOf("carga", "sobrecarga", "aumentar peso", "plateau", "estagnado")
        val highConfidenceImprovement = listOf(
            "melhorar", "fraco", "analise", "progresso", "desempenho",
            "feedback", "avaliacao", "melhoria", "balanco", "diagnostico",
        )
        val looksLikeLoadProgression = loadProgressionHints.any { normalized.contains(it) }
        val hasExplicitImprovement = highConfidenceImprovement.any { normalized.contains(it) }
        if (looksLikeLoadProgression && !hasExplicitImprovement) return false

        if (normalized.contains("evolucao corporal") ||
            normalized.contains("fotos de evolucao") ||
            normalized.contains("comparar medidas") ||
            normalized.contains("comparativo de medidas")
        ) {
            return false
        }
        return true
    }

    fun answer(ctx: AssistantAnswerContext): String {
        val name = ctx.name.ifBlank { "Atleta" }
        val findings = mutableListOf<String>()
        val missing = mutableListOf<String>()
        val suggestions = mutableListOf<String>()

        // Treinos
        when {
            ctx.weeklyWorkoutCount == 0 -> {
                missing += "treinos registrados"
                val inactivity = ctx.hoursSinceLastWorkout?.let { hours ->
                    if (hours >= 48) {
                        val days = maxOf((hours / 24).toInt(), 2)
                        "Inatividade: faz cerca de $days dia(s) desde o último treino."
                    } else null
                }
                if (inactivity != null) findings += inactivity
                else findings += "Nenhum treino finalizado nos últimos 7 dias."
                suggestions += "Comece com 2–3 treinos esta semana na aba **Treinos** — o hábito importa mais que a perfeição."
            }
            ctx.weeklyWorkoutCount < 3 -> {
                findings += "Treinos (últimos 7 dias): ${ctx.weeklyWorkoutCount} sessão(ões)."
                suggestions += "Suba a frequência: ${ctx.weeklyWorkoutCount} treino(s) nos últimos 7 dias; o alvo comum é pelo menos 3."
            }
            else -> {
                findings += "Treinos (últimos 7 dias): ${ctx.weeklyWorkoutCount} sessão(ões) — bom ritmo de consistência."
            }
        }
        ctx.routine.summaryLine?.let { findings += "Rotina aprendida: $it" }
        ctx.routine.usualWindowLabel?.let { findings += "Janela habitual de treino: $it." }

        // Sono
        val sleep = ctx.sleepHours
        if (sleep == null) {
            missing += "sono de hoje"
            suggestions += "Registre o sono no check-in diário — dormindo 7–9 h a recuperação e o treino rendem mais."
        } else {
            val formatted = "%.1f".format(sleep)
            val status = when {
                sleep < 5f -> "não regulado"
                sleep < 7f -> "abaixo do ideal"
                sleep <= 9f -> "ideal"
                else -> "acima do recomendado"
            }
            findings += "Sono (hoje): $formatted h — $status."
            when {
                sleep < 7f -> suggestions +=
                    "Priorize 7–9 h de sono (hoje $formatted h): horário mais estável e menos telas late night."
                sleep > 9f -> suggestions +=
                    "Avalie se o excesso de sono ($formatted h) reflete fadiga ou rotina irregular; busque faixa 7–9 h."
            }
        }

        // Água
        val waterGoal = ctx.waterGoalMl
        if (waterGoal > 0) {
            if (ctx.waterMl <= 0) {
                missing += "água de hoje"
                suggestions += "Comece a registrar água hoje (meta ~$waterGoal ml) — hidratação aparece rápido no bem-estar do treino."
            } else {
                val pct = (ctx.waterMl * 100.0 / waterGoal).roundToInt()
                findings += "Água (hoje): ${ctx.waterMl} ml de $waterGoal ml ($pct%)."
                if (ctx.waterMl < waterGoal) {
                    val remaining = waterGoal - ctx.waterMl
                    suggestions += "Feche a meta de água: faltam $remaining ml para chegar em $waterGoal ml."
                }
            }
        }

        // Nutrição (simplificado)
        findings += "Meta calórica do plano: ${ctx.dailyCalorieTarget} kcal/dia (TDEE ~${ctx.estimatedTdee})."
        suggestions += "Monte ou revise o cardápio em **Nutrição** e marque as refeições para medir adesão."

        if (suggestions.isEmpty()) {
            suggestions += "Mantenha consistência: 3 treinos/semana, sono 7–9 h e meta de água."
            suggestions += "Revise o próximo treino e o cardápio do dia — pequenos ajustes diários somam."
        }

        val prioritized = suggestions.take(4)
        val sparse = findings.size <= 1 || (ctx.weeklyWorkoutCount == 0 && sleep == null)

        return buildReply(name, ctx.objective, findings, missing, prioritized, sparse)
    }

    private fun buildReply(
        name: String,
        goal: String,
        findings: List<String>,
        missing: List<String>,
        suggestions: List<String>,
        sparse: Boolean,
    ): String {
        val lines = mutableListOf(
            "$name, montei uma análise objetiva do que vale melhorar, com base nos dados do app.",
            "",
        )
        if (sparse) {
            lines += "📊 **Panorama**"
            lines += "Ainda há poucos dados para um resumo educativo completo — e isso é normal no começo."
            lines += ""
        } else {
            lines += "📊 **O que os dados mostram**"
            lines += "Objetivo no app: $goal."
        }
        if (findings.isNotEmpty()) {
            if (sparse) lines += "Achei isto nos registros:"
            findings.forEach { lines += "• $it" }
            lines += ""
        }
        if (missing.isNotEmpty()) {
            lines += "📝 **Ainda falta registrar**"
            missing.forEach { lines += "• ${it.replaceFirstChar { c -> c.uppercase() }}" }
            lines += ""
        }
        lines += "🎯 **Prioridades para evoluir**"
        suggestions.forEachIndexed { index, suggestion ->
            lines += "${index + 1}. $suggestion"
        }
        lines += ""
        lines += if (sparse) {
            """
            💪 **Você consegue**
            $name, todo progresso começa com o primeiro registro honesto. Sono, refeições e 2–3 treinos já mudam o jogo. Estou aqui no IAssistente para ajustar o caminho rumo a ${goal.lowercase()} — sem culpa, com constância.
            """.trimIndent()
        } else {
            """
            💪 **Você consegue**
            $name, melhorar não é recomeçar do zero — é apertar os pontos certos e manter a disciplina. Olhe para essas prioridades como um plano claro, não como cobrança. Um dia de cada vez e você chega mais perto de ${goal.lowercase()}. Estou com você.
            """.trimIndent()
        }
        return lines.joinToString("\n")
    }

    private fun normalize(text: String): String {
        val stripped = Normalizer.normalize(text, Normalizer.Form.NFD).replace("\\p{Mn}+".toRegex(), "")
        return stripped.lowercase()
    }
}

/**
 * Port of iOS AssistantRestDayEngine Q&A — simplified without consecutiveTrainingDays
 * (uses weeklyWorkoutCount + hoursSinceLastWorkout).
 */
object AssistantRestDayEngine {
    private val HypertrophyRestBlock = """
**Descanso e hipertrofia**
• O músculo se adapta **depois** do estímulo — sono, alimentação e dias sem carga pesada são parte do ganho.
• Treinar todo dia sem pausa eleva cortisol, reduz performance e aumenta risco de lesão.
• Para hipertrofia, **1–2 dias de descanso por semana** (ou descanso ativo leve) costumam funcionar melhor que volume infinito.
""".trimIndent()

    fun matches(question: String): Boolean {
        val normalized = normalize(question)
        if (normalized.contains("entre series") ||
            normalized.contains("timer de descanso") ||
            normalized.contains("pausa entre series")
        ) {
            return false
        }
        val keywords = listOf(
            "dia de descanso", "dia descanso", "preciso descansar", "devo descansar",
            "overtraining", "over training", "7 dias seguidos", "sete dias seguidos",
            "treinar todo dia", "treino todo dia", "hipertrofia descanso",
            "recuperacao muscular", "descanso ativo",
            "descanso entre treinos", "descanso pos treino",
            "marquei descanso", "descanso e hipertrofia", "musculo descansa",
            "fadiga muscular", "super treino",
        )
        return keywords.any { normalized.contains(it) }
    }

    fun answer(question: String, ctx: AssistantAnswerContext): String {
        val name = ctx.name.ifBlank { "Atleta" }
        val sections = mutableListOf<String>()

        val hours = ctx.hoursSinceLastWorkout
        if (ctx.weeklyWorkoutCount >= 6) {
            sections += "Você registrou **${ctx.weeklyWorkoutCount} treinos** nos últimos 7 dias, $name. " +
                "O corpo precisa de pausa para adaptar e crescer — considere um dia leve ou off."
        } else if (hours != null && hours < 24 && ctx.weeklyWorkoutCount >= 4) {
            sections += "Você treinou recentemente e já tem ${ctx.weeklyWorkoutCount} sessões na semana. " +
                "Um dia de recuperação ajuda hipertrofia e evita fadiga acumulada."
        }

        sections += HypertrophyRestBlock
        sections += "**Recuperação geral:** alternar estímulo e descanso é o que sustenta progresso em qualquer modalidade.\n" +
            "**Musculação:** fibras e sistema nervoso precisam de 24–48 h após treinos pesados de força."

        sections += "**Resumo:** descanso não é preguiça — é quando músculo, tendões e sistema nervoso se adaptam. " +
            "Alterne estímulo e recuperação; meditação ajuda a mente, mas **não substitui** o descanso físico de um dia sem treino pesado.\n\n" +
            "Estou aqui no IAssistente! 💪🌿"

        return sections.joinToString("\n\n")
    }

    private fun normalize(text: String): String {
        val stripped = Normalizer.normalize(text, Normalizer.Form.NFD).replace("\\p{Mn}+".toRegex(), "")
        return stripped.lowercase()
    }
}
