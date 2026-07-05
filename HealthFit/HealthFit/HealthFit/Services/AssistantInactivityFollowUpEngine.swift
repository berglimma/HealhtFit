import Foundation

enum AssistantInactivityFollowUpEngine {
    static let inactivityThreshold: TimeInterval = 60 * 60

    static func message(
        context: HealthAssistantContext,
        sessions: [WorkoutSession]
    ) -> String {
        let name = context.user?.greetingName ?? "Atleta"
        let goal = context.user?.goal ?? .maintenance
        let report = WeeklyProgressAnalyzer.buildReport(sessions: sessions, goal: goal)
        let week = report.currentWeek

        var lines = [
            "Sentindo sua falta por aqui, \(name)! 💬",
            "",
            "Faz cerca de 1 hora sem sua resposta — queria te mostrar o que você já vem construindo:",
            "",
            "📊 **Seus resultados (últimos 7 dias)**",
            "• \(week.workoutCount) treino(s) realizados",
            "• \(week.totalMinutes) minutos de atividade",
            "• \(Int(week.totalCalories.rounded())) kcal queimadas",
            "• \(week.activeDays) dia(s) ativos na semana",
            "• Score semanal: \(report.overallScore)/100",
        ]

        if week.strengthSessions > 0 || week.cardioSessions > 0 || week.meditationSessions > 0 {
            lines.append("")
            lines.append("🏋️ **Distribuição**")
            if week.strengthSessions > 0 {
                lines.append("• Musculação: \(week.strengthSessions) sessão(ões)")
            }
            if week.cardioSessions > 0 {
                lines.append("• Cardio: \(week.cardioSessions) sessão(ões)")
            }
            if week.meditationSessions > 0 {
                lines.append("• Meditação: \(week.meditationMinutes) min em \(week.meditationSessions) sessão(ões)")
            }
        }

        if week.workoutCount > 0 {
            let completion = Int((week.averageCompletionRate * 100).rounded())
            lines.append("• Taxa média de conclusão dos exercícios: \(completion)%")
        }

        if context.waterIntakeMl > 0, let user = context.user {
            let waterGoal = user.recommendedDailyWaterML
            if waterGoal > 0 {
                lines.append("• Hidratação hoje: \(context.waterIntakeMl) ml de \(waterGoal) ml")
            }
        }

        if let sleep = context.sleepHours {
            lines.append("• Sono registrado hoje: \(String(format: "%.1f", sleep)) h")
        }

        if !report.highlights.isEmpty {
            lines.append("")
            lines.append("✨ **Destaques**")
            report.highlights.prefix(3).forEach { lines.append("• \($0)") }
        }

        if let topImprovement = report.improvements.first {
            lines.append("")
            lines.append("🎯 **Próximo passo**")
            lines.append("• \(topImprovement.title): \(topImprovement.detail)")
        }

        if week.workoutCount == 0 {
            lines.append("")
            lines.append("Ainda dá tempo de registrar um treino hoje na aba **Treinos** — cada sessão conta!")
        } else {
            lines.append("")
            lines.append("Você está no caminho certo para **\(goal.rawValue.lowercased())**. Continue assim!")
        }

        lines.append("")
        lines.append("Estou aqui na aba IAssistente quando quiser conversar, tirar dúvidas ou receber motivação. 💪")

        return lines.joined(separator: "\n")
    }

    static func shouldDeliverFollowUp(
        lastUserMessageAt: Date?,
        lastAssistantPromptAt: Date?,
        now: Date = .now,
        threshold: TimeInterval = inactivityThreshold
    ) -> Bool {
        let reference = lastUserMessageAt ?? lastAssistantPromptAt
        guard let reference else { return false }
        return now.timeIntervalSince(reference) >= threshold
    }
}
