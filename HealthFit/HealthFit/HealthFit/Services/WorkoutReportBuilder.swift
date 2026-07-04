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
    static func emailSubject(session: WorkoutSession, athleteName: String) -> String {
        "Relatório de Treino — \(athleteName) — \(session.workoutTitle)"
    }

    static func emailBody(
        session: WorkoutSession,
        athlete: UserProfile,
        allSessions: [WorkoutSession] = []
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
            "Duração total: \(DurationFormatting.format(seconds: Int(session.duration)))",
            "Exercícios concluídos: \(session.completedExercises)/\(session.totalExercises)",
            "Tempo nos exercícios: \(DurationFormatting.format(seconds: session.totalExerciseSeconds))",
            "Descanso total: \(DurationFormatting.format(seconds: session.totalRestSeconds))"
        ]

        if session.caloriesBurned > 0 {
            lines.append("Calorias: \(Int(session.caloriesBurned)) kcal")
        }

        if session.averageHeartRate > 0 {
            lines.append(String(format: "FC média: %.0f BPM", session.averageHeartRate))
        }

        lines.append(contentsOf: preWorkoutReportLines(
            currentSession: session,
            allSessions: allSessions
        ))

        if !session.exerciseRecords.isEmpty {
            lines.append("")
            lines.append("Detalhamento por exercício:")
            for record in session.exerciseRecords {
                let status = record.isCompleted ? "✓" : "○"
                lines.append("\(status) \(record.exerciseName) — \(DurationFormatting.format(seconds: record.elapsedSeconds)) (descanso: \(DurationFormatting.format(seconds: record.restSeconds)))")
            }
        }

        lines.append("")
        lines.append("Enviado pelo app HealthFit")
        return lines.joined(separator: "\n")
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
}
