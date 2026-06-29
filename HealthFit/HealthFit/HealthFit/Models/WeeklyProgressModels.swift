import Foundation

struct WeekStats: Equatable {
    let workoutCount: Int
    let totalMinutes: Int
    let totalCalories: Double
    let averageCompletionRate: Double
    let activeDays: Int
    let cardioSessions: Int
    let strengthSessions: Int
    let averageHeartRate: Double
    let totalRestMinutes: Int
    let totalExerciseMinutes: Int

    static let empty = WeekStats(
        workoutCount: 0,
        totalMinutes: 0,
        totalCalories: 0,
        averageCompletionRate: 0,
        activeDays: 0,
        cardioSessions: 0,
        strengthSessions: 0,
        averageHeartRate: 0,
        totalRestMinutes: 0,
        totalExerciseMinutes: 0
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
    let trends: [ProgressTrend]
    let highlights: [String]
    let improvements: [ImprovementSuggestion]
    let dailyWorkoutMinutes: [DailyWorkoutActivity]
    let overallScore: Int

    var periodLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "d MMM"
        return "\(formatter.string(from: weekStart)) – \(formatter.string(from: weekEnd))"
    }
}

struct DailyWorkoutActivity: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let minutes: Int
    let workoutCount: Int
}
