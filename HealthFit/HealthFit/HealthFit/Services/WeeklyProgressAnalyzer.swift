import Foundation

enum WeeklyProgressAnalyzer {
    private static let reportDays = 7

    static func buildReport(
        sessions: [WorkoutSession],
        goal: FitnessGoal,
        referenceDate: Date = .now
    ) -> WeeklyProgressReport {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: referenceDate)

        guard let currentStart = calendar.date(byAdding: .day, value: -(reportDays - 1), to: todayStart),
              let previousEnd = calendar.date(byAdding: .day, value: -1, to: currentStart),
              let previousStart = calendar.date(byAdding: .day, value: -(reportDays - 1), to: calendar.startOfDay(for: previousEnd)) else {
            return emptyReport(referenceDate: referenceDate)
        }

        let completedSessions = sessions.filter { $0.endedAt != nil }
        let currentSessions = sessions(in: currentStart...endOfDay(referenceDate, calendar: calendar), from: completedSessions)
        let previousSessions = sessions(in: previousStart...endOfDay(previousEnd, calendar: calendar), from: completedSessions)

        let currentWeek = stats(for: currentSessions, calendar: calendar)
        let previousWeek = stats(for: previousSessions, calendar: calendar)
        let trends = buildTrends(current: currentWeek, previous: previousWeek)
        let highlights = buildHighlights(current: currentWeek, previous: previousWeek)
        let improvements = buildImprovements(
            current: currentWeek,
            previous: previousWeek,
            goal: goal
        )
        let dailyActivity = buildDailyActivity(
            sessions: currentSessions,
            start: currentStart,
            end: todayStart,
            calendar: calendar
        )
        let score = calculateScore(current: currentWeek, previous: previousWeek, goal: goal)

        return WeeklyProgressReport(
            weekStart: currentStart,
            weekEnd: referenceDate,
            currentWeek: currentWeek,
            previousWeek: previousWeek.workoutCount > 0 ? previousWeek : nil,
            trends: trends,
            highlights: highlights,
            improvements: improvements,
            dailyWorkoutMinutes: dailyActivity,
            overallScore: score
        )
    }

    private static func emptyReport(referenceDate: Date) -> WeeklyProgressReport {
        WeeklyProgressReport(
            weekStart: referenceDate,
            weekEnd: referenceDate,
            currentWeek: .empty,
            previousWeek: nil,
            trends: [],
            highlights: [],
            improvements: [
                ImprovementSuggestion(
                    icon: "figure.run",
                    title: "Comece a treinar",
                    detail: "Finalize seu primeiro treino para gerar o relatório semanal.",
                    priority: .high
                )
            ],
            dailyWorkoutMinutes: [],
            overallScore: 0
        )
    }

    private static func sessions(
        in range: ClosedRange<Date>,
        from sessions: [WorkoutSession]
    ) -> [WorkoutSession] {
        sessions.filter { range.contains($0.startedAt) }
    }

    private static func endOfDay(_ date: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? date
    }

    private static func stats(for sessions: [WorkoutSession], calendar: Calendar) -> WeekStats {
        guard !sessions.isEmpty else { return .empty }

        let totalMinutes = sessions.reduce(0) { $0 + Int($1.duration / 60) }
        let totalCalories = sessions.reduce(0) { $0 + $1.caloriesBurned }
        let completionRates = sessions.map { session -> Double in
            guard session.totalExercises > 0 else { return session.endedAt != nil ? 1 : 0 }
            return Double(session.completedExercises) / Double(session.totalExercises)
        }
        let averageCompletion = completionRates.reduce(0, +) / Double(max(completionRates.count, 1))

        let activeDays = Set(sessions.map { calendar.startOfDay(for: $0.startedAt) }).count
        let cardioSessions = sessions.filter(isCardioSession).count
        let strengthSessions = sessions.count - cardioSessions

        let heartRates = sessions.map(\.averageHeartRate).filter { $0 > 0 }
        let averageHeartRate = heartRates.isEmpty ? 0 : heartRates.reduce(0, +) / Double(heartRates.count)

        let totalRest = sessions.reduce(0) { $0 + $1.totalRestSeconds } / 60
        let totalExercise = sessions.reduce(0) { $0 + $1.totalExerciseSeconds } / 60

        return WeekStats(
            workoutCount: sessions.count,
            totalMinutes: totalMinutes,
            totalCalories: totalCalories,
            averageCompletionRate: averageCompletion,
            activeDays: activeDays,
            cardioSessions: cardioSessions,
            strengthSessions: strengthSessions,
            averageHeartRate: averageHeartRate,
            totalRestMinutes: totalRest,
            totalExerciseMinutes: totalExercise
        )
    }

    private static func isCardioSession(_ session: WorkoutSession) -> Bool {
        session.workoutTitle.lowercased().hasPrefix("cardio")
    }

    private static func buildTrends(current: WeekStats, previous: WeekStats) -> [ProgressTrend] {
        guard previous.workoutCount > 0 || current.workoutCount > 0 else { return [] }

        return [
            makeTrend(
                title: "Treinos",
                current: current.workoutCount,
                previous: previous.workoutCount,
                icon: "dumbbell.fill",
                format: { "\($0)" }
            ),
            makeTrend(
                title: "Minutos",
                current: current.totalMinutes,
                previous: previous.totalMinutes,
                icon: "clock.fill",
                format: { "\($0) min" }
            ),
            makeTrend(
                title: "Calorias",
                current: Int(current.totalCalories),
                previous: Int(previous.totalCalories),
                icon: "flame.fill",
                format: { "\($0) kcal" }
            ),
            makeTrend(
                title: "Dias ativos",
                current: current.activeDays,
                previous: previous.activeDays,
                icon: "calendar",
                format: { "\($0)/7" }
            )
        ]
    }

    private static func makeTrend<T: Comparable & Numeric>(
        title: String,
        current: T,
        previous: T,
        icon: String,
        format: (T) -> String
    ) -> ProgressTrend {
        let direction: ProgressTrendDirection
        if current > previous {
            direction = .up
        } else if current < previous {
            direction = .down
        } else {
            direction = .stable
        }

        return ProgressTrend(
            title: title,
            currentValue: format(current),
            previousValue: format(previous),
            direction: direction,
            icon: icon
        )
    }

    private static func buildHighlights(current: WeekStats, previous: WeekStats) -> [String] {
        var highlights: [String] = []

        if current.workoutCount >= 4 {
            highlights.append("Excelente frequência: \(current.workoutCount) treinos na semana.")
        } else if current.workoutCount >= 3 {
            highlights.append("Boa consistência com \(current.workoutCount) treinos realizados.")
        }

        if current.averageCompletionRate >= 0.85 {
            highlights.append("Alta taxa de conclusão dos exercícios (\(Int(current.averageCompletionRate * 100))%).")
        }

        if current.activeDays >= 4 {
            highlights.append("Treinos bem distribuídos em \(current.activeDays) dias diferentes.")
        }

        if previous.workoutCount > 0, current.totalMinutes > previous.totalMinutes {
            let diff = current.totalMinutes - previous.totalMinutes
            highlights.append("Você treinou \(diff) minutos a mais que na semana anterior.")
        }

        if current.cardioSessions >= 2 {
            highlights.append("Bom volume de cardio: \(current.cardioSessions) sessões.")
        }

        if highlights.isEmpty && current.workoutCount > 0 {
            highlights.append("Você manteve atividade esta semana. Continue evoluindo!")
        }

        return highlights
    }

    private static func buildImprovements(
        current: WeekStats,
        previous: WeekStats,
        goal: FitnessGoal
    ) -> [ImprovementSuggestion] {
        var suggestions: [ImprovementSuggestion] = []

        if current.workoutCount == 0 {
            suggestions.append(
                ImprovementSuggestion(
                    icon: "calendar.badge.plus",
                    title: "Retome os treinos",
                    detail: "Nenhum treino foi registrado nos últimos 7 dias. Planeje pelo menos 3 sessões para a próxima semana.",
                    priority: .high
                )
            )
            return suggestions
        }

        if current.workoutCount < 3 {
            suggestions.append(
                ImprovementSuggestion(
                    icon: "repeat",
                    title: "Aumente a frequência",
                    detail: "Você treinou \(current.workoutCount)x esta semana. O ideal é pelo menos 3 treinos por semana.",
                    priority: .high
                )
            )
        }

        if current.activeDays < 3 && current.workoutCount >= 2 {
            suggestions.append(
                ImprovementSuggestion(
                    icon: "calendar",
                    title: "Distribua melhor os treinos",
                    detail: "Seus treinos estão concentrados em poucos dias. Espalhe ao longo da semana para melhor recuperação.",
                    priority: .medium
                )
            )
        }

        if current.averageCompletionRate < 0.7 && current.workoutCount > 0 {
            suggestions.append(
                ImprovementSuggestion(
                    icon: "checkmark.circle",
                    title: "Conclua mais exercícios",
                    detail: "Taxa média de conclusão de \(Int(current.averageCompletionRate * 100))%. Tente finalizar mais séries e exercícios por sessão.",
                    priority: .high
                )
            )
        }

        if current.totalMinutes < 90 && current.workoutCount > 0 {
            suggestions.append(
                ImprovementSuggestion(
                    icon: "clock.badge.exclamationmark",
                    title: "Aumente o tempo de treino",
                    detail: "Total de \(current.totalMinutes) minutos na semana. Busque pelo menos 90 minutos semanais para resultados consistentes.",
                    priority: .medium
                )
            )
        }

        if current.totalRestMinutes > current.totalExerciseMinutes && current.totalExerciseMinutes > 0 {
            suggestions.append(
                ImprovementSuggestion(
                    icon: "timer",
                    title: "Reduza descansos longos",
                    detail: "O tempo de descanso superou o tempo de exercício. Mantenha intervalos mais curtos para manter a intensidade.",
                    priority: .medium
                )
            )
        }

        switch goal {
        case .fatLoss, .endurance:
            if current.cardioSessions == 0 {
                suggestions.append(
                    ImprovementSuggestion(
                        icon: "figure.run",
                        title: "Inclua cardio",
                        detail: "Seu objetivo é \(goal.rawValue.lowercased()). Adicione pelo menos 1–2 sessões de cardio na próxima semana.",
                        priority: .high
                    )
                )
            }
        case .muscleGain:
            if current.strengthSessions < 2 {
                suggestions.append(
                    ImprovementSuggestion(
                        icon: "figure.strengthtraining.traditional",
                        title: "Priorize musculação",
                        detail: "Para ganho de massa, faça pelo menos 3 treinos de força por semana com foco em progressão de carga.",
                        priority: .high
                    )
                )
            }
        case .maintenance:
            if current.workoutCount < 2 {
                suggestions.append(
                    ImprovementSuggestion(
                        icon: "heart.circle",
                        title: "Mantenha a regularidade",
                        detail: "Para manutenção, tente treinar pelo menos 2–3 vezes por semana de forma equilibrada.",
                        priority: .medium
                    )
                )
            }
        }

        if previous.workoutCount > 0 {
            if current.workoutCount < previous.workoutCount {
                suggestions.append(
                    ImprovementSuggestion(
                        icon: "chart.line.downtrend.xyaxis",
                        title: "Recupere o ritmo",
                        detail: "Você fez \(previous.workoutCount) treinos na semana anterior e \(current.workoutCount) nesta. Evite quedas consecutivas.",
                        priority: .medium
                    )
                )
            }

            if current.totalMinutes < Int(Double(previous.totalMinutes) * 0.8) && previous.totalMinutes > 0 {
                suggestions.append(
                    ImprovementSuggestion(
                        icon: "arrow.down.right",
                        title: "Volume em queda",
                        detail: "O tempo total de treino caiu em relação à semana passada. Reavalie sua rotina.",
                        priority: .medium
                    )
                )
            }
        }

        if suggestions.isEmpty {
            suggestions.append(
                ImprovementSuggestion(
                    icon: "star.fill",
                    title: "Continue assim",
                    detail: "Semana sólida! Mantenha a consistência e busque pequenas progressões na carga ou duração.",
                    priority: .low
                )
            )
        }

        return suggestions.sorted { $0.priority < $1.priority }
    }

    private static func buildDailyActivity(
        sessions: [WorkoutSession],
        start: Date,
        end: Date,
        calendar: Calendar
    ) -> [DailyWorkoutActivity] {
        var result: [DailyWorkoutActivity] = []
        var day = start

        while day <= end {
            let daySessions = sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
            let minutes = daySessions.reduce(0) { $0 + Int($1.duration / 60) }
            result.append(
                DailyWorkoutActivity(
                    date: day,
                    minutes: minutes,
                    workoutCount: daySessions.count
                )
            )
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        return result
    }

    private static func calculateScore(current: WeekStats, previous: WeekStats, goal: FitnessGoal) -> Int {
        guard current.workoutCount > 0 else { return 0 }

        var score = 0.0

        score += min(Double(current.workoutCount) / 4.0, 1.0) * 30
        score += min(Double(current.activeDays) / 5.0, 1.0) * 20
        score += min(current.averageCompletionRate, 1.0) * 25
        score += min(Double(current.totalMinutes) / 120.0, 1.0) * 15

        switch goal {
        case .fatLoss, .endurance:
            score += min(Double(current.cardioSessions) / 2.0, 1.0) * 10
        case .muscleGain:
            score += min(Double(current.strengthSessions) / 3.0, 1.0) * 10
        case .maintenance:
            score += min(Double(current.workoutCount) / 3.0, 1.0) * 10
        }

        if previous.workoutCount > 0, current.workoutCount >= previous.workoutCount {
            score = min(score + 5, 100)
        }

        return Int(score.rounded())
    }
}
