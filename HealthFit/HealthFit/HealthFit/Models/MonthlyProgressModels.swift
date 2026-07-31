import Foundation

struct DailySleepActivity: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let hours: Double
}

struct DailySupplementActivity: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let intakeCount: Int
    let names: [String]
}

struct SupplementMonthSummary: Equatable {
    let daysLogged: Int
    let totalIntakes: Int
    let topSupplements: [SupplementFrequency]
    let entries: [SupplementIntakeEntry]

    static let empty = SupplementMonthSummary(
        daysLogged: 0,
        totalIntakes: 0,
        topSupplements: [],
        entries: []
    )
}

struct SupplementFrequency: Identifiable, Equatable {
    let name: String
    let count: Int
    var id: String { name }
}

struct SleepMonthSummary: Equatable {
    let daysLogged: Int
    let averageHours: Double
    let idealNights: Int
    let dailyHours: [DailySleepActivity]

    static let empty = SleepMonthSummary(
        daysLogged: 0,
        averageHours: 0,
        idealNights: 0,
        dailyHours: []
    )
}

struct MealPlanDaySummary: Identifiable, Equatable {
    let dayOfWeek: String
    let completed: Int
    let total: Int
    var id: String { dayOfWeek }
}

struct MealPlanMonthSummary: Equatable {
    let dayCount: Int
    let totalMeals: Int
    let completedMeals: Int
    let completionRate: Double
    let daySummaries: [MealPlanDaySummary]

    var hasPlan: Bool { dayCount > 0 && totalMeals > 0 }

    static let empty = MealPlanMonthSummary(
        dayCount: 0,
        totalMeals: 0,
        completedMeals: 0,
        completionRate: 0,
        daySummaries: []
    )
}

struct BodyMeasurementsMonthSummary: Equatable {
    let current: BodyMeasurements?
    let previous: BodyMeasurements?
    let comparison: BodyMeasurementComparison?

    var hasData: Bool {
        (current?.hasAnyValue ?? false) || (previous?.hasAnyValue ?? false)
    }

    static let empty = BodyMeasurementsMonthSummary(
        current: nil,
        previous: nil,
        comparison: nil
    )
}

struct MonthlyProgressReport: Equatable {
    let monthStart: Date
    let monthEnd: Date
    let currentMonth: WeekStats
    let overallScore: Int
    let dailyWorkoutMinutes: [DailyWorkoutActivity]
    let sleepSummary: SleepMonthSummary
    let supplementSummary: SupplementMonthSummary
    let dailySupplementActivity: [DailySupplementActivity]
    let bodyMeasurements: BodyMeasurementsMonthSummary
    let mealPlanSummary: MealPlanMonthSummary
    let highlights: [String]

    var periodLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "d MMM"
        return "\(formatter.string(from: monthStart)) – \(formatter.string(from: monthEnd))"
    }
}
