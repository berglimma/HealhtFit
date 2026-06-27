import Foundation

enum WorkoutReportBuilder {
    static func emailSubject(session: WorkoutSession, athleteName: String) -> String {
        "Relatório de Treino — \(athleteName) — \(session.workoutTitle)"
    }

    static func emailBody(session: WorkoutSession, athlete: UserProfile) -> String {
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
}
