import Foundation

struct WeekStats: Equatable {
    let workoutCount: Int
    let totalMinutes: Int
    let totalCalories: Double
    let averageCompletionRate: Double
    let activeDays: Int
    let cardioSessions: Int
    let strengthSessions: Int
    let meditationSessions: Int
    let meditationMinutes: Int
    let averageHeartRate: Double
    let totalRestMinutes: Int
    let totalExerciseMinutes: Int
    let preWorkoutUsedCount: Int
    let preWorkoutNotUsedCount: Int
    /// Média do esforço percebido (1…10) nas sessões avaliadas.
    let averagePerceivedEffort: Double
    let ratedEffortSessionCount: Int

    static let empty = WeekStats(
        workoutCount: 0,
        totalMinutes: 0,
        totalCalories: 0,
        averageCompletionRate: 0,
        activeDays: 0,
        cardioSessions: 0,
        strengthSessions: 0,
        meditationSessions: 0,
        meditationMinutes: 0,
        averageHeartRate: 0,
        totalRestMinutes: 0,
        totalExerciseMinutes: 0,
        preWorkoutUsedCount: 0,
        preWorkoutNotUsedCount: 0,
        averagePerceivedEffort: 0,
        ratedEffortSessionCount: 0
    )
}

enum ProgressTrendDirection: String {
    case up = "Melhorou"
    case down = "Caiu"
    case stable = "Estável"
}

struct ProgressTrend: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let currentValue: String
    let previousValue: String
    let direction: ProgressTrendDirection
    let icon: String
}

enum ImprovementPriority: Int, Comparable {
    case high = 0
    case medium = 1
    case low = 2

    static func < (lhs: ImprovementPriority, rhs: ImprovementPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct ImprovementSuggestion: Identifiable, Equatable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
    let priority: ImprovementPriority
}

struct WeeklyProgressReport: Equatable {
    let weekStart: Date
    let weekEnd: Date
    let currentWeek: WeekStats
    let previousWeek: WeekStats?
    let meditationSummary: MeditationWeekSummary
    let trends: [ProgressTrend]
    let highlights: [String]
    let improvements: [ImprovementSuggestion]
    let dailyWorkoutMinutes: [DailyWorkoutActivity]
    let dailyMeditationMinutes: [DailyMeditationActivity]
    let overallScore: Int
    let preWorkoutSummary: PreWorkoutUsageSummary
    let lifetimePreWorkoutSummary: PreWorkoutUsageSummary
    let preWorkoutEntries: [PreWorkoutSessionEntry]
    let effortEntries: [WorkoutEffortEntry]

    var periodLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "d MMM"
        return "\(formatter.string(from: weekStart)) – \(formatter.string(from: weekEnd))"
    }
}

struct MeditationWeekSummary: Equatable {
    let sessionCount: Int
    let totalMinutes: Int
    let topics: [String]
    let previousMinutes: Int

    static let empty = MeditationWeekSummary(
        sessionCount: 0,
        totalMinutes: 0,
        topics: [],
        previousMinutes: 0
    )
}

struct DailyWorkoutActivity: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let minutes: Int
    let workoutCount: Int
    /// Média 1…10 das sessões avaliadas no dia (`nil` se ninguém avaliou).
    let averagePerceivedEffort: Double?
    let ratedEffortCount: Int

    init(
        date: Date,
        minutes: Int,
        workoutCount: Int,
        averagePerceivedEffort: Double? = nil,
        ratedEffortCount: Int = 0
    ) {
        self.date = date
        self.minutes = minutes
        self.workoutCount = workoutCount
        self.averagePerceivedEffort = averagePerceivedEffort
        self.ratedEffortCount = ratedEffortCount
    }
}

/// Sessão com esforço percebido para listagens de relatório.
struct WorkoutEffortEntry: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let workoutTitle: String
    let perceivedEffort: Int
    let effortLabel: String
}

struct DailyMeditationActivity: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let minutes: Int
    let sessionCount: Int
}
