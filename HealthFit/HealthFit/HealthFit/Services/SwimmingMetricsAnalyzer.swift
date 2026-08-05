import Foundation

/// Entrada do diário de bordo de natação a partir de `WorkoutSession`.
struct SwimmingLogEntry: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let title: String
    let poolLengthMeters: Double
    let laps: Int
    let distanceMeters: Double
    let durationSeconds: Int
    let paceSecondsPer100m: Int?
    let calories: Double
    let intensityLabel: String?

    var distanceKm: Double { distanceMeters / 1000.0 }

    var formattedPace: String {
        guard let pace = paceSecondsPer100m else { return "—" }
        return PaceFormatting.formatSwimPace(secondsPer100m: pace)
    }

    var formattedDistance: String {
        if distanceMeters >= 1000 {
            return String(format: "%.2f km", distanceKm)
        }
        return "\(Int(distanceMeters.rounded())) m"
    }
}

enum SwimmingMetricsAnalyzer {
    static func isSwimmingSession(_ session: WorkoutSession) -> Bool {
        session.isSwimmingSession
    }

    static func entries(from sessions: [WorkoutSession]) -> [SwimmingLogEntry] {
        sessions
            .filter(isSwimmingSession)
            .compactMap(makeEntry(from:))
            .sorted { $0.date > $1.date }
    }

    static func makeEntry(from session: WorkoutSession) -> SwimmingLogEntry? {
        guard isSwimmingSession(session) else { return nil }

        let pool = session.poolLengthMeters ?? 25
        let laps = session.swimLapCount
            ?? (session.completedDistanceKm.map { Int(($0 * 1000 / max(pool, 1)).rounded()) } ?? 0)
        let distanceMeters: Double = {
            if let km = session.completedDistanceKm, km > 0 {
                return km * 1000
            }
            return Double(laps) * pool
        }()

        let pace = session.swimPaceSecondsPer100m
            ?? {
                guard distanceMeters >= 25, session.activeDurationSeconds > 0 else { return nil }
                return max(1, Int((Double(session.activeDurationSeconds) / (distanceMeters / 100.0)).rounded()))
            }()

        return SwimmingLogEntry(
            id: session.id,
            date: session.endedAt ?? session.startedAt,
            title: session.workoutTitle,
            poolLengthMeters: pool,
            laps: max(0, laps),
            distanceMeters: max(0, distanceMeters),
            durationSeconds: session.activeDurationSeconds,
            paceSecondsPer100m: pace,
            calories: session.caloriesBurned,
            intensityLabel: session.cardioIntensityLabel
        )
    }

    static func totalDistanceMeters(entries: [SwimmingLogEntry]) -> Double {
        entries.reduce(0) { $0 + $1.distanceMeters }
    }

    static func totalCalories(entries: [SwimmingLogEntry]) -> Double {
        entries.reduce(0) { $0 + $1.calories }
    }

    static func averagePaceSecondsPer100m(entries: [SwimmingLogEntry]) -> Int? {
        let paces = entries.compactMap(\.paceSecondsPer100m)
        guard !paces.isEmpty else { return nil }
        return paces.reduce(0, +) / paces.count
    }

    /// Pontos para gráfico de distância (cronológico).
    static func distanceChartPoints(entries: [SwimmingLogEntry], limit: Int = 20) -> [(date: Date, meters: Double)] {
        Array(entries.sorted { $0.date < $1.date }.suffix(limit))
            .map { ($0.date, $0.distanceMeters) }
    }

    /// Pontos de ritmo (cronológico) — menor = mais rápido.
    static func paceChartPoints(entries: [SwimmingLogEntry], limit: Int = 20) -> [(date: Date, pace: Int)] {
        Array(entries.sorted { $0.date < $1.date }.suffix(limit))
            .compactMap { entry in
                guard let pace = entry.paceSecondsPer100m else { return nil }
                return (entry.date, pace)
            }
    }

    static func calorieChartPoints(entries: [SwimmingLogEntry], limit: Int = 20) -> [(date: Date, kcal: Double)] {
        Array(entries.sorted { $0.date < $1.date }.suffix(limit))
            .map { ($0.date, $0.calories) }
    }
}
