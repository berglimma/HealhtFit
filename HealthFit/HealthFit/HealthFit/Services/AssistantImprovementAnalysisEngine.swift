import Foundation

/// Gera resposta do IAssistente a perguntas sobre o que melhorar / análise de progresso.
enum AssistantImprovementAnalysisEngine {
    /// Frases e trechos que acionam a análise (texto sem acentos, minúsculas).
    static let intentPhrases: [String] = [
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
    ]

    /// Detecta intent de melhoria/análise sem capturar progressão de carga genérica.
    static func matches(_ question: String) -> Bool {
        let normalized = normalize(question)
        guard intentPhrases.contains(where: { normalized.contains($0) }) else {
            return false
        }

        // "como evoluir a carga / sobrecarga" → deixa o tópico de progressão de treino responder.
        let loadProgressionHints = ["carga", "sobrecarga", "aumentar peso", "plateau", "estagnado"]
        let highConfidenceImprovement = [
            "melhorar", "fraco", "analise", "progresso", "desempenho",
            "feedback", "avaliacao", "melhoria", "balanco", "diagnostico",
        ]
        let looksLikeLoadProgression = loadProgressionHints.contains { normalized.contains($0) }
        let hasExplicitImprovement = highConfidenceImprovement.contains { normalized.contains($0) }
        if looksLikeLoadProgression && !hasExplicitImprovement {
            return false
        }

        // Evolução corporal (fotos/medidas) tem tópico próprio.
        if normalized.contains("evolucao corporal")
            || normalized.contains("fotos de evolucao")
            || normalized.contains("comparar medidas")
            || normalized.contains("comparativo de medidas")
        {
            return false
        }

        return true
    }

    static func answer(context: HealthAssistantContext) -> String {
        let name = context.user?.greetingName ?? "Atleta"
        let goal = context.user?.goal ?? .maintenance
        let sessions = context.recentWorkoutSessions
        let report = WeeklyProgressAnalyzer.buildReport(sessions: sessions, goal: goal)
        let week = report.currentWeek
        let earlyEnds = earlyEndedCount(from: sessions, days: 7)
        let lifetimeCount = sessions.filter { $0.endedAt != nil }.count

        var findings: [String] = []
        var missing: [String] = []
        var suggestions: [String] = []

        // —— Treinos ——
        appendWorkoutFindings(
            week: week,
            report: report,
            earlyEnds: earlyEnds,
            lifetimeCount: lifetimeCount,
            hoursSinceLast: context.hoursSinceLastWorkout,
            findings: &findings,
            missing: &missing,
            suggestions: &suggestions
        )

        // —— Sono ——
        appendSleepFindings(
            hours: context.sleepHours,
            findings: &findings,
            missing: &missing,
            suggestions: &suggestions
        )

        // —— Água ——
        appendWaterFindings(
            context: context,
            findings: &findings,
            missing: &missing,
            suggestions: &suggestions
        )

        // —— Cardápio ——
        appendMealFindings(
            context: context,
            findings: &findings,
            missing: &missing,
            suggestions: &suggestions
        )

        // —— Suplementos (opcional) ——
        if context.supplementsLoggedToday > 0 {
            let n = context.supplementsLoggedToday
            findings.append(
                "Suplementos: \(n) registro(s) hoje — bom, mantenha o hábito se fizer parte do seu plano."
            )
        }

        // —— Medidas (opcional, curto) ——
        if let user = context.user {
            if user.bodyMeasurements.hasAnyValue {
                findings.append("Medidas corporais: já há registro no perfil (útil para acompanhar evolução).")
            } else if findings.count >= 2 {
                // Só menciona se há outros achados, para não poluir cenários muito vazios.
                missing.append("medidas corporais no Perfil")
            }
        }

        if suggestions.isEmpty {
            suggestions = defaultSuggestions(sparse: findings.isEmpty && missing.count >= 2)
        }

        // Prioriza e limita a 2–4
        let prioritized = Array(suggestions.prefix(4))
        let sparse = findings.isEmpty || (lifetimeCount == 0 && context.sleepHours == nil && !context.hasMealPlan)

        return buildReply(
            name: name,
            goal: goal,
            findings: findings,
            missing: missing,
            suggestions: prioritized,
            sparse: sparse,
            score: report.overallScore
        )
    }

    // MARK: - Sections

    private static func appendWorkoutFindings(
        week: WeekStats,
        report: WeeklyProgressReport,
        earlyEnds: Int,
        lifetimeCount: Int,
        hoursSinceLast: Double?,
        findings: inout [String],
        missing: inout [String],
        suggestions: inout [String]
    ) {
        if lifetimeCount == 0 {
            missing.append("treinos registrados")
            suggestions.append(
                "Comece com 2–3 treinos esta semana na aba **Treinos** (musculação, cardio ou o que preferir) — o hábito importa mais que a perfeição."
            )
            return
        }

        findings.append(
            "Treinos (últimos 7 dias): \(week.workoutCount) sessão(ões), \(week.totalMinutes) min, \(week.activeDays) dia(s) ativo(s), score \(report.overallScore)/100."
        )

        if week.strengthSessions > 0 || week.cardioSessions > 0 || week.meditationSessions > 0 {
            var parts: [String] = []
            if week.strengthSessions > 0 { parts.append("força \(week.strengthSessions)") }
            if week.cardioSessions > 0 { parts.append("cardio \(week.cardioSessions)") }
            if week.meditationSessions > 0 { parts.append("meditação \(week.meditationSessions)") }
            findings.append("Distribuição: \(parts.joined(separator: ", ")).")
        }

        if week.workoutCount > 0 {
            let completion = Int((week.averageCompletionRate * 100).rounded())
            findings.append("Conclusão média dos exercícios: \(completion)%.")
            if week.averageCompletionRate < 0.7 {
                suggestions.append(
                    "Priorize concluir mais séries/exercícios por sessão (hoje ~\(completion)%) — sessões incompletas frequentes atrapalham a progressão."
                )
            }
        }

        if earlyEnds > 0 {
            findings.append("Encerramentos antecipados (7 dias): \(earlyEnds)x.")
            suggestions.append(
                "Reduza treinos interrompidos cedo: planeje um volume realista e finalize com qualidade (\(earlyEnds) encerramento(s) antecipado(s) na semana)."
            )
        }

        if week.workoutCount == 0 {
            if let hours = hoursSinceLast, hours >= 48 {
                let days = max(Int(hours / 24), 2)
                findings.append("Inatividade: faz cerca de \(days) dia(s) desde o último treino.")
            } else {
                findings.append("Nenhum treino finalizado nos últimos 7 dias.")
            }
            suggestions.append(
                "Retome com 2–3 sessões esta semana — consistência vence intensidade isolada."
            )
        } else if week.workoutCount < 3 {
            suggestions.append(
                "Suba a frequência: \(week.workoutCount) treino(s) nos últimos 7 dias; o alvo comum é pelo menos 3."
            )
        }

        if week.strengthSessions > 0, week.cardioSessions == 0, week.workoutCount >= 2 {
            suggestions.append(
                "Inclua 1 sessão de cardio leve na semana para condicionamento e recuperação ativa."
            )
        } else if week.cardioSessions > 0, week.strengthSessions == 0, week.workoutCount >= 2 {
            suggestions.append(
                "Inclua 2 treinos de força na semana para preservar/ganhar músculo e apoiar o metabolismo."
            )
        }

        // Melhorias do relatório semanal (já priorizadas)
        for item in report.improvements.prefix(2) {
            let line = "\(item.title): \(item.detail)"
            if !suggestions.contains(where: { $0.localizedCaseInsensitiveContains(item.title) }) {
                suggestions.append(line)
            }
        }
    }

    private static func appendSleepFindings(
        hours: Double?,
        findings: inout [String],
        missing: inout [String],
        suggestions: inout [String]
    ) {
        guard let hours else {
            missing.append("sono de hoje")
            suggestions.append(
                "Registre o sono no check-in diário — dormindo 7–9 h a recuperação e o treino rendem mais."
            )
            return
        }

        let formatted = String(format: "%.1f", hours)
        let assessment = SleepAssessment.evaluate(hours: hours)
        findings.append("Sono (hoje): \(formatted) h — \(assessment.title.lowercased()).")

        switch assessment {
        case .ideal:
            break
        case .needsMore, .unregulated:
            suggestions.append(
                "Priorize 7–9 h de sono (hoje \(formatted) h): horário mais estável e menos telas late night."
            )
        case .aboveRecommended:
            suggestions.append(
                "Avalie se o excesso de sono (\(formatted) h) reflete fadiga ou rotina irregular; busque faixa 7–9 h com horários mais fixos."
            )
        }
    }

    private static func appendWaterFindings(
        context: HealthAssistantContext,
        findings: inout [String],
        missing: inout [String],
        suggestions: inout [String]
    ) {
        guard let user = context.user else { return }
        let goal = user.recommendedDailyWaterML
        guard goal > 0 else { return }

        let current = context.waterIntakeMl
        if current <= 0 {
            missing.append("água de hoje")
            suggestions.append(
                "Comece a registrar água hoje (meta ~\(goal) ml) — hidratação aparece rápido no bem-estar do treino."
            )
            return
        }

        let pct = Int((Double(current) / Double(goal) * 100).rounded())
        findings.append("Água (hoje): \(current) ml de \(goal) ml (\(pct)%).")

        if current < goal {
            let remaining = goal - current
            suggestions.append(
                "Feche a meta de água: faltam \(remaining) ml para chegar em \(goal) ml."
            )
        }
    }

    private static func appendMealFindings(
        context: HealthAssistantContext,
        findings: inout [String],
        missing: inout [String],
        suggestions: inout [String]
    ) {
        guard context.hasMealPlan else {
            missing.append("cardápio / refeições marcadas")
            suggestions.append(
                "Monte ou ative o cardápio em **Nutrição** e marque as refeições concluídas para medir adesão."
            )
            return
        }

        let todayCompleted = context.todayMealsCompleted
        let todayTotal = context.todayMealsTotal
        let weekCompleted = context.weekMealsCompleted
        let weekTotal = context.weekMealsTotal

        if todayTotal > 0 {
            findings.append("Cardápio (hoje): \(todayCompleted)/\(todayTotal) refeições concluídas.")
            if todayCompleted < todayTotal {
                suggestions.append(
                    "Complete as refeições do dia no app (\(todayCompleted)/\(todayTotal)) — adesão estável acelera o objetivo \(context.user?.goal.rawValue.lowercased() ?? "definido")."
                )
            }
        }

        if weekTotal > 0 {
            let pct = Int((Double(weekCompleted) / Double(weekTotal) * 100).rounded())
            findings.append("Cardápio (semana no plano): \(weekCompleted)/\(weekTotal) refeições marcadas (\(pct)%).")
            if pct < 50 {
                suggestions.append(
                    "Melhore a adesão ao cardápio: só \(pct)% das refeições da semana foram marcadas — foque em 1–2 refeições-chave por dia."
                )
            }
        } else if todayTotal == 0 {
            findings.append("Cardápio: plano gerado, mas ainda sem refeições listadas para marcar hoje.")
        }
    }

    private static func defaultSuggestions(sparse: Bool) -> [String] {
        if sparse {
            return [
                "Registre sono e água no check-in diário para começar o baseline.",
                "Finalize 2–3 treinos esta semana e marque as refeições do cardápio.",
            ]
        }
        return [
            "Mantenha consistência: 3 treinos/semana, sono 7–9 h e meta de água.",
            "Revise o próximo treino e o cardápio do dia — pequenos ajustes diários somam.",
        ]
    }

    private static func buildReply(
        name: String,
        goal: FitnessGoal,
        findings: [String],
        missing: [String],
        suggestions: [String],
        sparse: Bool,
        score: Int
    ) -> String {
        var lines: [String] = [
            "\(name), montei uma análise objetiva do que vale melhorar, com base nos dados do app.",
            "",
        ]

        if sparse {
            lines.append("📊 **Panorama**")
            lines.append("Ainda há poucos dados para um diagnóstico completo — e isso é normal no começo.")
            lines.append("")
        } else {
            lines.append("📊 **O que os dados mostram**")
            if score > 0 {
                lines.append("Score semanal de treino: \(score)/100 · Objetivo: \(goal.rawValue).")
            } else {
                lines.append("Objetivo no app: \(goal.rawValue).")
            }
        }

        if !findings.isEmpty {
            if sparse { lines.append("Achei isto nos registros:") }
            findings.forEach { lines.append("• \($0)") }
            lines.append("")
        }

        if !missing.isEmpty {
            lines.append("📝 **Ainda falta registrar**")
            missing.forEach { lines.append("• \($0.capitalizedSentence)") }
            lines.append("")
        }

        lines.append("🎯 **Prioridades para evoluir**")
        for (index, suggestion) in suggestions.enumerated() {
            lines.append("\(index + 1). \(suggestion)")
        }
        lines.append("")

        lines.append(motivationalClose(sparse: sparse, name: name, goal: goal))

        return lines.joined(separator: "\n")
    }

    private static func motivationalClose(sparse: Bool, name: String, goal: FitnessGoal) -> String {
        if sparse {
            return """
            💪 **Você consegue**
            \(name), todo progresso começa com o primeiro registro honesto. Sono, refeições e 2–3 treinos já mudam o jogo. Estou aqui no IAssistente para ajustar o caminho rumo a \(goal.rawValue.lowercased()) — sem culpa, com constância.
            """
        }
        return """
        💪 **Você consegue**
        \(name), melhorar não é recomeçar do zero — é apertar os pontos certos e manter a disciplina. Olhe para essas prioridades como um plano claro, não como cobrança. Um dia de cada vez e você chega mais perto de \(goal.rawValue.lowercased()). Estou com você.
        """
    }

    // MARK: - Helpers

    static func earlyEndedCount(from sessions: [WorkoutSession], days: Int, referenceDate: Date = .now) -> Int {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: referenceDate)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            return 0
        }
        return sessions.filter { session in
            guard session.endedAt != nil else { return false }
            guard session.startedAt >= start else { return false }
            return session.endedEarly || session.autoEndedByInactivity
        }.count
    }

    /// Índice do cardápio (Segunda=0 … Domingo=6) a partir do calendário.
    static func mealPlanDayIndex(for date: Date = .now, calendar: Calendar = .current) -> Int {
        let weekday = calendar.component(.weekday, from: date) // 1 = domingo
        return (weekday + 5) % 7
    }

    static func mealAdherence(from weeklyPlan: [DailyMealPlan], referenceDate: Date = .now) -> (
        hasPlan: Bool,
        todayCompleted: Int,
        todayTotal: Int,
        weekCompleted: Int,
        weekTotal: Int
    ) {
        guard !weeklyPlan.isEmpty else {
            return (false, 0, 0, 0, 0)
        }

        let dayIndex = mealPlanDayIndex(for: referenceDate)
        var todayCompleted = 0
        var todayTotal = 0
        if weeklyPlan.indices.contains(dayIndex) {
            let meals = weeklyPlan[dayIndex].options.first?.meals ?? []
            todayTotal = meals.count
            todayCompleted = meals.filter(\.isCompleted).count
        }

        var weekCompleted = 0
        var weekTotal = 0
        for day in weeklyPlan {
            let meals = day.options.first?.meals ?? []
            weekTotal += meals.count
            weekCompleted += meals.filter(\.isCompleted).count
        }

        return (true, todayCompleted, todayTotal, weekCompleted, weekTotal)
    }

    /// Kcal das refeições marcadas como feitas no cardápio do dia.
    static func todayConsumedCalories(
        from weeklyPlan: [DailyMealPlan],
        referenceDate: Date = .now
    ) -> Int {
        guard !weeklyPlan.isEmpty else { return 0 }
        let dayIndex = mealPlanDayIndex(for: referenceDate)
        guard weeklyPlan.indices.contains(dayIndex) else { return 0 }
        let meals = weeklyPlan[dayIndex].options.first?.meals ?? []
        return meals.filter(\.isCompleted).reduce(0) { $0 + $1.calories }
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
    }
}

private extension String {
    /// Capitaliza só a primeira letra (para itens de “falta registrar”).
    var capitalizedSentence: String {
        guard let first else { return self }
        return String(first).uppercased() + dropFirst()
    }
}
