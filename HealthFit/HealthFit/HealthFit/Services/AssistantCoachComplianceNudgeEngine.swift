import Foundation

/// IAssistente: alerta se o aluno parou de enviar relatório ao personal e/ou não está cumprindo as fichas prescritas.
@MainActor
enum AssistantCoachComplianceNudgeEngine {
    /// Sem relatório há 7 dias (ou nunca enviou, com vínculo há ≥7 dias).
    static let reportStaleThreshold: TimeInterval = 7 * 24 * 60 * 60
    /// Sem sessão em ficha do personal nos últimos 7 dias.
    static let sheetIdleThreshold: TimeInterval = 7 * 24 * 60 * 60

    private static let nudgeDayKey = "healthfit_coach_compliance_nudge_day"

    struct Evaluation: Equatable {
        var reportOverdue: Bool
        var daysSinceReport: Int?
        var sheetsIdle: Bool
        var idleSheetTitles: [String]
        var personalName: String?

        var shouldNudge: Bool { reportOverdue || sheetsIdle }
    }

    static func evaluate(
        user: UserProfile?,
        hasActivePersonalLink: Bool,
        personalCoachName: String?,
        coachSheets: [WorkoutSheet],
        sessions: [WorkoutSession],
        now: Date = .now
    ) -> Evaluation? {
        guard let user else { return nil }

        let linkedViaCoach = hasActivePersonalLink
        let linkedViaProfile = user.usesPersonalTrainer
            || !user.personalTrainerEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard linkedViaCoach || linkedViaProfile else { return nil }

        let personalName = personalCoachName
            ?? (user.personalTrainerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : user.personalTrainerName)

        let canSendEmailReport = !user.personalTrainerEmail
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty

        var reportOverdue = false
        var daysSinceReport: Int?
        if canSendEmailReport {
            if let last = user.lastTrainerReportSentAt {
                let elapsed = now.timeIntervalSince(last)
                if elapsed >= reportStaleThreshold {
                    reportOverdue = true
                    daysSinceReport = max(1, Int(elapsed / 86_400))
                }
            } else {
                // Nunca enviou: só cobra após alguns dias de conta / vínculo.
                let anchor = max(user.createdAt, user.updatedAt.addingTimeInterval(-reportStaleThreshold))
                if now.timeIntervalSince(anchor) >= reportStaleThreshold {
                    reportOverdue = true
                    daysSinceReport = nil
                }
            }
        }

        let activeCoachSheets = coachSheets.filter {
            $0.isCoachPrescribed && $0.isActive && !$0.exercises.isEmpty
        }
        let coachSheetIds = Set(activeCoachSheets.map(\.id))

        var sheetsIdle = false
        var idleTitles: [String] = []
        if !coachSheetIds.isEmpty {
            let recentCoachSessions = sessions.filter { session in
                guard coachSheetIds.contains(session.workoutSheetId) else { return false }
                let when = session.endedAt ?? session.startedAt
                return now.timeIntervalSince(when) <= sheetIdleThreshold
            }
            if recentCoachSessions.isEmpty {
                sheetsIdle = true
                idleTitles = Array(
                    activeCoachSheets
                        .map(\.title)
                        .prefix(4)
                )
            }
        }

        let evaluation = Evaluation(
            reportOverdue: reportOverdue,
            daysSinceReport: daysSinceReport,
            sheetsIdle: sheetsIdle,
            idleSheetTitles: idleTitles,
            personalName: personalName
        )
        return evaluation.shouldNudge ? evaluation : nil
    }

    static func shouldDeliverToday(now: Date = .now) -> Bool {
        let dayKey = DailyWellnessEntry.dayKey(for: now)
        return UserDefaults.standard.string(forKey: nudgeDayKey) != dayKey
    }

    static func markDelivered(now: Date = .now) {
        UserDefaults.standard.set(DailyWellnessEntry.dayKey(for: now), forKey: nudgeDayKey)
    }

    static func message(for evaluation: Evaluation, athleteName: String) -> String {
        let name = athleteName.isEmpty ? "Atleta" : athleteName
        let personal = evaluation.personalName ?? "seu personal"
        var lines = [
            "Ei, \(name)! Sobre o acompanhamento com \(personal):",
            "",
        ]

        if evaluation.reportOverdue {
            if let days = evaluation.daysSinceReport {
                lines.append(
                    "• Faz cerca de **\(days) dia(s)** sem enviar o **relatório de treino** por e-mail para o personal."
                )
            } else {
                lines.append(
                    "• Ainda não vejo relatório de treino enviado ao personal. Vale compartilhar o progresso."
                )
            }
            lines.append(
                "  Depois de um treino, abra o resumo e toque em **Enviar e-mail para o Personal**."
            )
            lines.append("")
        }

        if evaluation.sheetsIdle {
            lines.append(
                "• Suas **fichas do personal** no HealthFit Coach parecem sem uso recente (últimos 7 dias)."
            )
            if !evaluation.idleSheetTitles.isEmpty {
                let listed = evaluation.idleSheetTitles.map { "“\($0)”" }.joined(separator: ", ")
                lines.append("  Em destaque: \(listed).")
            }
            lines.append(
                "  Abra **Treinos → Musculação** e priorize as fichas prescritas pelo personal."
            )
            lines.append("")
        }

        lines.append(
            "Cumprir a ficha e reportar o treino ajuda o profissional a ajustar carga e volume com segurança. Estou no IAssistente se quiser motivação ou dúvidas! 💪"
        )
        return lines.joined(separator: "\n")
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: nudgeDayKey)
    }
}
