import Foundation

enum MonthlyProgressAnalyzer {
    static let reportDays = 30

    static func buildReport(
        sessions: [WorkoutSession],
        wellnessEntries: [DailyWellnessEntry],
        bodyMeasurements: BodyMeasurements?,
        previousBodyMeasurements: BodyMeasurements?,
        weeklyPlan: [DailyMealPlan],
        goal: FitnessGoal,
        referenceDate: Date = .now
    ) -> MonthlyProgressReport {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: referenceDate)

        guard let monthStart = calendar.date(byAdding: .day, value: -(reportDays - 1), to: todayStart) else {
            return emptyReport(referenceDate: referenceDate)
        }

        let completedSessions = sessions.filter { $0.endedAt != nil }
        let rangeEnd = endOfDay(referenceDate, calendar: calendar)
        let monthSessions = filterSessions(in: monthStart...rangeEnd, from: completedSessions)
        let stats = weekStats(for: monthSessions, calendar: calendar)

        let entriesInRange = wellnessEntries.filter { entry in
            guard let date = date(fromDayKey: entry.dayKey, calendar: calendar) else { return false }
            return date >= monthStart && date <= todayStart
        }

        let sleepSummary = buildSleepSummary(
            entries: entriesInRange,
            start: monthStart,
            end: todayStart,
            calendar: calendar
        )
        let (supplementSummary, dailySupplements) = buildSupplementSummary(
            entries: entriesInRange,
            start: monthStart,
            end: todayStart,
            calendar: calendar
        )
        let mealPlanSummary = buildMealPlanSummary(weeklyPlan: weeklyPlan)
        let bodySummary = buildBodyMeasurementsSummary(
            current: bodyMeasurements,
            previous: previousBodyMeasurements
        )
        let dailyWorkouts = buildDailyWorkoutActivity(
            sessions: monthSessions,
            start: monthStart,
            end: todayStart,
            calendar: calendar
        )
        let score = calculateScore(
            stats: stats,
            sleep: sleepSummary,
            supplements: supplementSummary,
            meals: mealPlanSummary,
            goal: goal
        )
        let highlights = buildHighlights(
            stats: stats,
            sleep: sleepSummary,
            supplements: supplementSummary,
            meals: mealPlanSummary,
            body: bodySummary
        )

        return MonthlyProgressReport(
            monthStart: monthStart,
            monthEnd: referenceDate,
            currentMonth: stats,
            overallScore: score,
            dailyWorkoutMinutes: dailyWorkouts,
            sleepSummary: sleepSummary,
            supplementSummary: supplementSummary,
            dailySupplementActivity: dailySupplements,
            bodyMeasurements: bodySummary,
            mealPlanSummary: mealPlanSummary,
            highlights: highlights
        )
    }

    // MARK: - Sleep

    private static func buildSleepSummary(
        entries: [DailyWellnessEntry],
        start: Date,
        end: Date,
        calendar: Calendar
    ) -> SleepMonthSummary {
        var byDay: [String: Double] = [:]
        for entry in entries {
            if let hours = entry.sleepHours {
                byDay[entry.dayKey] = hours
            }
        }

        var daily: [DailySleepActivity] = []
        var cursor = start
        while cursor <= end {
            let key = DailyWellnessEntry.dayKey(for: cursor)
            let hours = byDay[key] ?? 0
            daily.append(DailySleepActivity(date: cursor, hours: hours))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        let logged = byDay.values.map { $0 }
        let average = logged.isEmpty ? 0 : logged.reduce(0, +) / Double(logged.count)
        let ideal = logged.filter { (7...9).contains($0) }.count

        return SleepMonthSummary(
            daysLogged: logged.count,
            averageHours: average,
            idealNights: ideal,
            dailyHours: daily
        )
    }

    // MARK: - Supplements

    private static func buildSupplementSummary(
        entries: [DailyWellnessEntry],
        start: Date,
        end: Date,
        calendar: Calendar
    ) -> (SupplementMonthSummary, [DailySupplementActivity]) {
        var nameCounts: [String: Int] = [:]
        var allIntakes: [SupplementIntakeEntry] = []
        var byDay: [String: [SupplementIntakeEntry]] = [:]

        for entry in entries {
            guard !entry.supplementIntakes.isEmpty else { continue }
            byDay[entry.dayKey] = entry.supplementIntakes
            allIntakes.append(contentsOf: entry.supplementIntakes)
            for intake in entry.supplementIntakes {
                nameCounts[intake.name, default: 0] += 1
            }
        }

        var daily: [DailySupplementActivity] = []
        var cursor = start
        while cursor <= end {
            let key = DailyWellnessEntry.dayKey(for: cursor)
            let intakes = byDay[key] ?? []
            daily.append(
                DailySupplementActivity(
                    date: cursor,
                    intakeCount: intakes.count,
                    names: intakes.map(\.name)
                )
            )
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        let top = nameCounts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value { return lhs.key < rhs.key }
                return lhs.value > rhs.value
            }
            .prefix(5)
            .map { SupplementFrequency(name: $0.key, count: $0.value) }

        let summary = SupplementMonthSummary(
            daysLogged: byDay.count,
            totalIntakes: allIntakes.count,
            topSupplements: Array(top),
            entries: allIntakes.sorted { $0.loggedAt > $1.loggedAt }
        )
        return (summary, daily)
    }

    // MARK: - Meal plan

    private static func buildMealPlanSummary(weeklyPlan: [DailyMealPlan]) -> MealPlanMonthSummary {
        guard !weeklyPlan.isEmpty else { return .empty }

        var daySummaries: [MealPlanDaySummary] = []
        var totalMeals = 0
        var completedMeals = 0

        for day in weeklyPlan {
            let meals = day.options.first?.meals ?? day.meals
            let total = meals.count
            let completed = meals.filter(\.isCompleted).count
            totalMeals += total
            completedMeals += completed
            daySummaries.append(
                MealPlanDaySummary(dayOfWeek: day.dayOfWeek, completed: completed, total: total)
            )
        }

        let rate = totalMeals > 0 ? Double(completedMeals) / Double(totalMeals) : 0
        return MealPlanMonthSummary(
            dayCount: weeklyPlan.count,
            totalMeals: totalMeals,
            completedMeals: completedMeals,
            completionRate: rate,
            daySummaries: daySummaries
        )
    }

    // MARK: - Body measurements

    private static func buildBodyMeasurementsSummary(
        current: BodyMeasurements?,
        previous: BodyMeasurements?
    ) -> BodyMeasurementsMonthSummary {
        let comparison: BodyMeasurementComparison?
        if let current, let previous {
            comparison = BodyMeasurementComparison.make(previous: previous, current: current)
        } else {
            comparison = nil
        }
        return BodyMeasurementsMonthSummary(
            current: current,
            previous: previous,
            comparison: comparison
        )
    }

    // MARK: - Workouts / score

    private static func weekStats(for sessions: [WorkoutSession], calendar: Calendar) -> WeekStats {
        WeeklyProgressAnalyzer.monthCompatibleStats(for: sessions, calendar: calendar)
    }

    private static func buildDailyWorkoutActivity(
        sessions: [WorkoutSession],
        start: Date,
        end: Date,
        calendar: Calendar
    ) -> [DailyWorkoutActivity] {
        var result: [DailyWorkoutActivity] = []
        var cursor = start
        while cursor <= end {
            let daySessions = sessions.filter {
                calendar.isDate($0.startedAt, inSameDayAs: cursor)
            }
            let minutes = daySessions.reduce(0) { $0 + Int($1.duration / 60) }
            result.append(
                DailyWorkoutActivity(date: cursor, minutes: minutes, workoutCount: daySessions.count)
            )
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    private static func calculateScore(
        stats: WeekStats,
        sleep: SleepMonthSummary,
        supplements: SupplementMonthSummary,
        meals: MealPlanMonthSummary,
        goal: FitnessGoal
    ) -> Int {
        var score = 0

        let activeTarget = goal == .maintenance ? 12 : 16
        score += min(35, Int(Double(stats.activeDays) / Double(activeTarget) * 35))
        score += min(20, Int(Double(stats.workoutCount) / 20.0 * 20))

        if sleep.daysLogged > 0 {
            let sleepRatio = min(sleep.averageHours / 8.0, 1.2)
            score += Int(min(20, sleepRatio * 15))
            score += min(5, sleep.idealNights)
        }

        if supplements.daysLogged > 0 {
            score += min(10, supplements.daysLogged / 3)
        }

        if meals.hasPlan {
            score += Int(meals.completionRate * 10)
        }

        return min(100, max(0, score))
    }

    private static func buildHighlights(
        stats: WeekStats,
        sleep: SleepMonthSummary,
        supplements: SupplementMonthSummary,
        meals: MealPlanMonthSummary,
        body: BodyMeasurementsMonthSummary
    ) -> [String] {
        var items: [String] = []

        if stats.workoutCount > 0 {
            items.append("\(stats.workoutCount) treinos no período (\(stats.totalMinutes) min).")
        }
        if sleep.daysLogged > 0 {
            items.append(
                String(
                    format: "Sono médio de %.1f h em %d noite(s); %d no ideal (7–9 h).",
                    sleep.averageHours,
                    sleep.daysLogged,
                    sleep.idealNights
                )
            )
        }
        if supplements.totalIntakes > 0 {
            let top = supplements.topSupplements.first.map { "\($0.name) (\($0.count)×)" } ?? "—"
            items.append(
                "\(supplements.totalIntakes) registros de suplementos em \(supplements.daysLogged) dia(s). Mais frequente: \(top)."
            )
        }
        if meals.hasPlan {
            let pct = Int((meals.completionRate * 100).rounded())
            items.append(
                "Plano de refeições: \(meals.completedMeals)/\(meals.totalMeals) refeições concluídas (\(pct)%)."
            )
        }
        if body.hasData {
            if let comparison = body.comparison, !comparison.changes.isEmpty {
                items.append("Medidas corporais atualizadas com \(comparison.changes.count) variação(ões) no comparativo.")
            } else {
                items.append("Medidas corporais registradas no perfil.")
            }
        }
        return items
    }

    private static func emptyReport(referenceDate: Date) -> MonthlyProgressReport {
        MonthlyProgressReport(
            monthStart: referenceDate,
            monthEnd: referenceDate,
            currentMonth: .empty,
            overallScore: 0,
            dailyWorkoutMinutes: [],
            sleepSummary: .empty,
            supplementSummary: .empty,
            dailySupplementActivity: [],
            bodyMeasurements: .empty,
            mealPlanSummary: .empty,
            highlights: []
        )
    }

    private static func filterSessions(
        in range: ClosedRange<Date>,
        from sessions: [WorkoutSession]
    ) -> [WorkoutSession] {
        sessions.filter { range.contains($0.startedAt) }
    }

    private static func endOfDay(_ date: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? date
    }

    private static func date(fromDayKey dayKey: String, calendar: Calendar) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dayKey).map { calendar.startOfDay(for: $0) }
    }
}
