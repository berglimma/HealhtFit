import Foundation

struct MarathonPerformanceReport: Equatable {
    let distanceKm: Double
    let targetDistanceKm: Double
    let elapsedSeconds: Int
    let paceSecondsPerKm: Int
    let intensityLabel: String
    let projectedMarathonSeconds: Int
    let projectedHalfMarathonSeconds: Int
    let goalReached: Bool
    let previousBestSeconds: Int?
    let improvementSeconds: Int?
    let weeklyRunningKm: Double
    let readinessMessage: String
    let coachingTips: [String]

    var formattedPace: String { PaceFormatting.format(secondsPerKm: paceSecondsPerKm) }
    var formattedTime: String { PaceFormatting.formatDuration(seconds: elapsedSeconds) }
    var formattedMarathonProjection: String { PaceFormatting.formatDuration(seconds: projectedMarathonSeconds) }
    var formattedHalfMarathonProjection: String { PaceFormatting.formatDuration(seconds: projectedHalfMarathonSeconds) }
}

enum MarathonReportBuilder {
    static let marathonDistanceKm = PaceFormatting.marathonDistanceKm

    static func isDistanceRunSession(_ session: WorkoutSession) -> Bool {
        session.targetDistanceKm != nil && session.targetDistanceKm! > 0
    }

    static func build(session: WorkoutSession, allSessions: [WorkoutSession]) -> MarathonPerformanceReport? {
        guard let targetKm = session.targetDistanceKm, targetKm > 0 else { return nil }

        let distanceKm = session.completedDistanceKm ?? min(
            targetKm,
            estimatedDistance(from: session)
        )
        let elapsed = session.exerciseRecords.first?.elapsedSeconds ?? Int(session.duration)
        let pace = session.averagePaceSecondsPerKm ?? {
            guard distanceKm > 0 else { return 360 }
            return Int((Double(elapsed) / distanceKm).rounded())
        }()

        let intensity = session.cardioIntensityLabel ?? "Média"
        let goalReached = distanceKm >= targetKm * 0.98

        let previousBest = previousBestTime(
            for: targetKm,
            excluding: session.id,
            in: allSessions
        )
        let improvement: Int? = previousBest.map { elapsed - $0 }

        let weeklyKm = weeklyRunningVolume(excluding: session.id, in: allSessions) + distanceKm

        return MarathonPerformanceReport(
            distanceKm: distanceKm,
            targetDistanceKm: targetKm,
            elapsedSeconds: elapsed,
            paceSecondsPerKm: pace,
            intensityLabel: intensity,
            projectedMarathonSeconds: PaceFormatting.projectedFinish(
                secondsPerKm: pace,
                distanceKm: marathonDistanceKm
            ),
            projectedHalfMarathonSeconds: PaceFormatting.projectedFinish(
                secondsPerKm: pace,
                distanceKm: PaceFormatting.halfMarathonDistanceKm
            ),
            goalReached: goalReached,
            previousBestSeconds: previousBest,
            improvementSeconds: improvement,
            weeklyRunningKm: weeklyKm,
            readinessMessage: readinessMessage(longestKm: max(distanceKm, longestRun(in: allSessions)), weeklyKm: weeklyKm),
            coachingTips: coachingTips(distanceKm: distanceKm, pace: pace, goalReached: goalReached)
        )
    }

    static func emailLines(report: MarathonPerformanceReport, session: WorkoutSession) -> [String] {
        var lines = [
            "",
            "Relatório de performance — Maratona",
            "Distância: \(String(format: "%.2f", report.distanceKm)) km (meta \(String(format: "%.0f", report.targetDistanceKm)) km)",
            "Tempo: \(report.formattedTime)",
            "Ritmo médio: \(report.formattedPace)",
            "Intensidade: \(report.intensityLabel)",
            "Meta atingida: \(report.goalReached ? "Sim" : "Parcial")",
            "",
            "Projeções com este ritmo:",
            "• Meia-maratona (21,1 km): \(report.formattedHalfMarathonProjection)",
            "• Maratona (42,2 km): \(report.formattedMarathonProjection)",
            "",
            "Volume de corrida na semana: \(String(format: "%.1f", report.weeklyRunningKm)) km",
            report.readinessMessage
        ]

        if let previous = report.previousBestSeconds {
            let prevFormatted = PaceFormatting.formatDuration(seconds: previous)
            if let delta = report.improvementSeconds {
                if delta < 0 {
                    lines.append("Melhor marca nos \(String(format: "%.0f", report.targetDistanceKm)) km: bateu recorde por \(abs(delta) / 60) min!")
                } else if delta > 0 {
                    lines.append("Marca anterior nos \(String(format: "%.0f", report.targetDistanceKm)) km: \(prevFormatted) (+\(delta / 60) min vs hoje)")
                } else {
                    lines.append("Empatou sua melhor marca nos \(String(format: "%.0f", report.targetDistanceKm)) km: \(prevFormatted)")
                }
            }
        }

        if !report.coachingTips.isEmpty {
            lines.append("")
            lines.append("Orientações:")
            for tip in report.coachingTips {
                lines.append("• \(tip)")
            }
        }

        return lines
    }

    private static func estimatedDistance(from session: WorkoutSession) -> Double {
        guard let target = session.targetDistanceKm else { return 0 }
        let elapsed = session.exerciseRecords.first?.elapsedSeconds ?? Int(session.duration)
        let pace = session.averagePaceSecondsPerKm ?? 360
        return min(target, Double(elapsed) / Double(pace))
    }

    private static func previousBestTime(
        for targetKm: Double,
        excluding sessionId: UUID,
        in sessions: [WorkoutSession]
    ) -> Int? {
        let matches = sessions.filter { session in
            session.id != sessionId
                && session.targetDistanceKm == targetKm
                && session.endedAt != nil
        }

        let times = matches.compactMap { session -> Int? in
            session.exerciseRecords.first?.elapsedSeconds ?? Int(session.duration)
        }

        return times.min()
    }

    private static func weeklyRunningVolume(excluding sessionId: UUID, in sessions: [WorkoutSession]) -> Double {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: .now) ?? .now

        return sessions
            .filter { $0.id != sessionId && $0.startedAt >= weekAgo && isDistanceRunSession($0) }
            .reduce(0) { partial, session in
                partial + (session.completedDistanceKm ?? session.targetDistanceKm ?? 0)
            }
    }

    private static func longestRun(in sessions: [WorkoutSession]) -> Double {
        sessions
            .filter(isDistanceRunSession)
            .compactMap { $0.completedDistanceKm ?? $0.targetDistanceKm }
            .max() ?? 0
    }

    private static func readinessMessage(longestKm: Double, weeklyKm: Double) -> String {
        switch longestKm {
        case 25...:
            return "Preparação avançada: volume longo compatível com fase específica de maratona."
        case 20..<25:
            return "Boa base aeróbica. Próximo passo: consolidar 25–30 km em ritmo controlado."
        case 15..<20:
            return "Evolução sólida. Aumente gradualmente o longão para 20–22 km."
        case 10..<15:
            return "Fase de construção. Mantenha 2–3 corridas/semana e progrida distância aos poucos."
        default:
            return "Início de preparação. Foque em consistência antes de aumentar distância."
        }
    }

    private static func coachingTips(distanceKm: Double, pace: Int, goalReached: Bool) -> [String] {
        var tips: [String] = []

        if !goalReached {
            tips.append("Complete a distância planejada ou reduza a intensidade para manter o ritmo.")
        }
        if pace < 300 {
            tips.append("Ritmo muito intenso para longos — use zona aeróbica em treinos acima de 15 km.")
        }
        if distanceKm >= 20 {
            tips.append("Após longões, priorize hidratação, proteína e sono de 7–9 h.")
        }
        if distanceKm >= 10 {
            tips.append("Inclua 1 treino de ritmo (tempo run) e 1 rodagem leve por semana na preparação.")
        }
        tips.append("Projeção de maratona assume ritmo constante — em prova, estratégia de pacing é essencial.")

        return Array(tips.prefix(4))
    }
}
