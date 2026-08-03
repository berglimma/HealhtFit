import Foundation

struct PreWorkoutUsageSummary: Equatable {
    let usedCount: Int
    let notUsedCount: Int

    var totalAnswered: Int { usedCount + notUsedCount }

    static let empty = PreWorkoutUsageSummary(usedCount: 0, notUsedCount: 0)

    static func from(sessions: [WorkoutSession]) -> PreWorkoutUsageSummary {
        let used = sessions.filter { $0.tookPreWorkout == true }.count
        let notUsed = sessions.filter { $0.tookPreWorkout == false }.count
        return PreWorkoutUsageSummary(usedCount: used, notUsedCount: notUsed)
    }
}

struct PreWorkoutSessionEntry: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let workoutTitle: String
    let tookPreWorkout: Bool
}

enum WorkoutReportBuilder {
    static func isCardioSession(_ session: WorkoutSession) -> Bool {
        session.workoutTitle.lowercased().hasPrefix("cardio")
    }

    static func emailSubject(session: WorkoutSession, athleteName: String) -> String {
        let kind = isCardioSession(session) ? "Cardio" : "Treino"
        return "Relatório de \(kind) — \(athleteName) — \(session.workoutTitle)"
    }

    /// Há polyline GPS suficiente para gerar mapa (caminhada, corrida, bikes outdoor).
    static func hasRouteMapForEmail(_ session: WorkoutSession) -> Bool {
        session.routePoints.count >= 2
    }

    /// Sessão outdoor GPS elegível a mapa no e-mail (mesmo sem pontos ainda gravados).
    static func isOutdoorRouteEmailCandidate(_ session: WorkoutSession) -> Bool {
        session.isOutdoorGPSCardio || hasRouteMapForEmail(session)
    }

    static func emailBody(
        session: WorkoutSession,
        athlete: UserProfile,
        allSessions: [WorkoutSession] = [],
        routeMapAttachmentIncluded: Bool = false
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "pt_BR")
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short

        var lines: [String] = [
            "Olá\(athlete.personalTrainerName.isEmpty ? "" : " \(athlete.personalTrainerName)"),",
            "",
            "Segue o relatório do treino realizado por \(athlete.name):",
            "",
            "Treino: \(session.workoutTitle)",
            "Data: \(dateFormatter.string(from: session.startedAt))",
            "Duração total: \(DurationFormatting.format(seconds: Int(session.duration)))"
        ]

        lines.append(contentsOf: outdoorGPSEmailLines(
            session: session,
            routeMapAttachmentIncluded: routeMapAttachmentIncluded
        ))

        lines.append(contentsOf: athleteProfileReportLines(athlete: athlete, dateFormatter: dateFormatter))

        if isCardioSession(session) {
            lines.append("Tipo: Cardio")
            if let record = session.exerciseRecords.first {
                lines.append("Atividade: \(record.exerciseName)")
                lines.append("Tempo ativo: \(DurationFormatting.format(seconds: record.elapsedSeconds))")
                lines.append("Meta atingida: \(record.isCompleted ? "Sim" : "Parcial")")
            }
            if let targetKm = session.targetDistanceKm, targetKm > 0,
               let report = MarathonReportBuilder.build(session: session, allSessions: allSessions) {
                lines.append(contentsOf: MarathonReportBuilder.emailLines(report: report, session: session))
            }
        } else {
            lines.append("Exercícios concluídos: \(session.completedExercises)/\(session.totalExercises)")
            lines.append("Tempo nos exercícios: \(DurationFormatting.format(seconds: session.totalExerciseSeconds))")
            lines.append("Descanso total: \(DurationFormatting.format(seconds: session.totalRestSeconds))")
        }

        lines.append(contentsOf: earlyEndReportLines(
            currentSession: session,
            allSessions: allSessions
        ))

        if session.caloriesBurned > 0 {
            lines.append("Calorias: \(Int(session.caloriesBurned)) kcal")
        }

        if let targetCalories = session.targetCalories, targetCalories > 0 {
            let burned = Int(session.caloriesBurned)
            let reached = burned >= Int(Double(targetCalories) * 0.98)
            lines.append("Meta calórica: \(targetCalories) kcal")
            lines.append("Meta calórica atingida: \(reached ? "Sim" : "Parcial")")
            if burned > targetCalories {
                lines.append("Superação: +\(burned - targetCalories) kcal além da meta")
            }
        }

        if session.averageHeartRate > 0 {
            lines.append(String(format: "FC média: %.0f BPM", session.averageHeartRate))
        }

        if !isCardioSession(session) {
            lines.append(contentsOf: preWorkoutReportLines(
                currentSession: session,
                allSessions: allSessions
            ))
        }

        if !session.exerciseRecords.isEmpty {
            lines.append("")
            lines.append(isCardioSession(session) ? "Detalhes da sessão:" : "Detalhamento por exercício:")
            for record in session.exerciseRecords {
                let status = record.isCompleted ? "✓" : "○"
                if isCardioSession(session) {
                    lines.append("\(status) \(record.exerciseName) — \(DurationFormatting.format(seconds: record.elapsedSeconds))")
                } else {
                    var detail = "\(status) \(record.exerciseName) — \(DurationFormatting.format(seconds: record.elapsedSeconds)) (descanso: \(DurationFormatting.format(seconds: record.restSeconds)))"
                    if let weights = record.weightComparisonLabel {
                        detail += " · \(weights)"
                    }
                    lines.append(detail)
                }
            }
        }

        lines.append("")
        lines.append("Enviado pelo app HealthFit")
        return lines.joined(separator: "\n")
    }

    /// Corpo HTML para `MFMailCompose` (preserva quebras de linha do texto).
    static func emailHTMLBody(
        session: WorkoutSession,
        athlete: UserProfile,
        allSessions: [WorkoutSession] = [],
        routeMapAttachmentIncluded: Bool = false
    ) -> String {
        let plain = emailBody(
            session: session,
            athlete: athlete,
            allSessions: allSessions,
            routeMapAttachmentIncluded: routeMapAttachmentIncluded
        )
        return htmlDocument(fromPlainText: plain)
    }

    /// Distância, ritmo/velocidade e nota sobre o mapa (anexo ou fallback in-app).
    static func outdoorGPSEmailLines(
        session: WorkoutSession,
        routeMapAttachmentIncluded: Bool
    ) -> [String] {
        guard isOutdoorRouteEmailCandidate(session) else { return [] }

        var lines: [String] = []
        let distanceKm = session.displayDistanceKm
        if distanceKm > 0 {
            lines.append(String(format: "Distância: %.2f km", distanceKm))
        }

        if session.isOutdoorCyclingSession, distanceKm > 0.05, session.duration > 0 {
            let kmh = distanceKm / (session.duration / 3600.0)
            lines.append(String(format: "Velocidade média: %.1f km/h", kmh))
        } else if let pace = session.displayPaceSecondsPerKm, pace > 0 {
            lines.append("Ritmo médio: \(PaceFormatting.format(secondsPerKm: pace))")
        }

        if routeMapAttachmentIncluded {
            lines.append("Mapa do percurso em anexo (rota-treino.png).")
            lines.append("Legenda: \(RoutePerformanceColoring.legendText).")
        } else if hasRouteMapForEmail(session) {
            // mailto: não suporta anexos — avisa que o mapa está no app.
            lines.append("Mapa do percurso: disponível no app HealthFit (e-mail sem suporte a anexos).")
        }

        return lines
    }

    private static func htmlDocument(fromPlainText plain: String) -> String {
        let escaped = plain
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\n", with: "<br>\n")
        return """
        <html><body style="font-family:-apple-system,BlinkMacSystemFont,sans-serif;font-size:15px;line-height:1.45;color:#111;">
        \(escaped)
        </body></html>
        """
    }

    static func preWorkoutEntries(from sessions: [WorkoutSession]) -> [PreWorkoutSessionEntry] {
        sessions
            .compactMap { session -> PreWorkoutSessionEntry? in
                guard let tookPreWorkout = session.tookPreWorkout else { return nil }
                return PreWorkoutSessionEntry(
                    id: session.id,
                    date: session.startedAt,
                    workoutTitle: session.workoutTitle,
                    tookPreWorkout: tookPreWorkout
                )
            }
            .sorted { $0.date > $1.date }
    }

    static func todayPreWorkoutEntries(from sessions: [WorkoutSession]) -> [PreWorkoutSessionEntry] {
        let todayKey = DailyWellnessEntry.dayKey(for: .now)
        return preWorkoutEntries(from: sessions).filter {
            DailyWellnessEntry.dayKey(for: $0.date) == todayKey
        }
    }

    static func preWorkoutReportLines(
        currentSession: WorkoutSession? = nil,
        allSessions: [WorkoutSession],
        periodLabel: String? = nil
    ) -> [String] {
        let entries = preWorkoutEntries(from: allSessions)
        guard !entries.isEmpty || currentSession?.tookPreWorkout != nil else { return [] }

        let summary = PreWorkoutUsageSummary.from(sessions: allSessions)
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "pt_BR")
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short

        var lines = ["", "Pré-treino:"]

        if let periodLabel {
            lines.append("Período: \(periodLabel)")
        }

        if let currentSession, let tookPreWorkout = currentSession.tookPreWorkout {
            lines.append("Neste treino: \(tookPreWorkout ? "Sim, tomei" : "Não tomei")")
        }

        lines.append("Usou pré-treino: \(summary.usedCount) vez(es)")
        lines.append("Não usou pré-treino: \(summary.notUsedCount) vez(es)")
        lines.append("Total de respostas registradas: \(summary.totalAnswered)")

        if !entries.isEmpty {
            lines.append("")
            lines.append("Histórico de respostas:")
            for entry in entries {
                let answer = entry.tookPreWorkout ? "Sim" : "Não"
                lines.append("• \(dateFormatter.string(from: entry.date)) — \(entry.workoutTitle) — \(answer)")
            }
        }

        return lines
    }

    static func athleteProfileReportLines(
        athlete: UserProfile,
        dateFormatter: DateFormatter
    ) -> [String] {
        var lines: [String] = [
            "",
            "Perfil do atleta:",
            "Peso: \(String(format: "%.1f kg", athlete.weight))",
            "Altura: \(String(format: "%.0f cm", athlete.height))",
            "Idade: \(athlete.age) anos",
            "Objetivo: \(athlete.goal.rawValue)",
            "Biotipo: \(athlete.biotype.rawValue)"
        ]
        lines.append(contentsOf: athlete.bodyMeasurements.reportLines(dateFormatter: dateFormatter))
        if let comparison = athlete.latestMeasurementComparison,
           comparison.periodDays >= BodyMeasurements.comparisonIntervalDays {
            lines.append(contentsOf: comparison.reportLines(dateFormatter: dateFormatter))
        }
        return lines
    }

    static func earlyEndCount(from sessions: [WorkoutSession]) -> Int {
        sessions.filter(\.endedEarly).count
    }

    static func earlyEndReportLines(
        currentSession: WorkoutSession,
        allSessions: [WorkoutSession]
    ) -> [String] {
        let historyIncludingCurrent: [WorkoutSession] = {
            if allSessions.contains(where: { $0.id == currentSession.id }) {
                return allSessions
            }
            return [currentSession] + allSessions
        }()
        let count = earlyEndCount(from: historyIncludingCurrent)

        var lines: [String] = []

        if currentSession.autoEndedByInactivity {
            lines.append("Encerramento: Automático por inatividade (mais de 2h30 sem finalizar)")
            lines.append("Alerta: o aluno esqueceu de encerrar o treino; a sessão foi fechada pelo app.")
            if let justification = currentSession.earlyEndJustification?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !justification.isEmpty {
                lines.append("Detalhe: \(justification)")
            }
        } else if currentSession.endedEarly {
            lines.append("Encerramento: Antecipado (sem concluir todos os exercícios)")
            if let justification = currentSession.earlyEndJustification?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !justification.isEmpty {
                lines.append("Justificativa: \(justification)")
            }
        }

        let autoEndCount = historyIncludingCurrent.filter(\.autoEndedByInactivity).count
        if autoEndCount > 0 {
            lines.append("Encerramentos automáticos por inatividade (histórico): \(autoEndCount) vez(es)")
        }

        if count > 0 || currentSession.endedEarly {
            lines.append("Encerramentos antecipados (histórico): \(count) vez(es)")
        }

        return lines
    }
}
