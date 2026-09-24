import Foundation

/// Cruza nutrição + Apple Health/sono + treino + peso + medidas + metas do profissional.
enum ProfessionalReviewEngine {
    static func buildSnapshot(
        link: CoachLink,
        profile: UserProfile?,
        weeklyPlan: [DailyMealPlan],
        wellnessEntries: [DailyWellnessEntry],
        sessions: [WorkoutSession],
        careGoals: [NutritionGoal],
        checkIns: [NutritionCheckIn],
        referenceDate: Date = .now
    ) -> ProfessionalReviewSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let monthStart = calendar.date(byAdding: .day, value: -29, to: today) ?? today

        let adherence = AssistantImprovementAnalysisEngine.mealAdherence(from: weeklyPlan, referenceDate: referenceDate)
        let mealPct: Int = {
            guard adherence.hasPlan, adherence.weekTotal > 0 else { return 0 }
            return Int((Double(adherence.weekCompleted) / Double(adherence.weekTotal) * 100).rounded())
        }()

        let proteinAvg = averageCompletedProtein(weeklyPlan: weeklyPlan)
        let proteinGoal = proteinGoalGrams(for: profile, weeklyPlan: weeklyPlan)

        let sleepEntries = wellnessEntries.filter { entry in
            guard let d = dayDate(entry.dayKey, calendar: calendar) else { return false }
            return d >= weekStart && d <= today && entry.sleepHours != nil
        }
        let avgSleep = sleepEntries.isEmpty
            ? 0
            : sleepEntries.compactMap(\.sleepHours).reduce(0, +) / Double(sleepEntries.count)

        let weekSessions = sessions.filter { session in
            guard let ended = session.endedAt else { return false }
            let day = calendar.startOfDay(for: ended)
            return day >= weekStart && day <= today
        }
        let workoutsDone = Set(weekSessions.map { calendar.startOfDay(for: $0.endedAt ?? $0.startedAt) }).count

        let weightDelta = weightDeltaKg(
            profile: profile,
            checkIns: checkIns,
            since: monthStart,
            calendar: calendar
        )
        let waistDelta = waistDeltaCm(profile: profile)

        let goals = careGoals.filter { $0.status == .active }.prefix(5).map(\.title)
        var sources: [String] = []
        if adherence.hasPlan { sources.append("Cardápio / adesão alimentar") }
        if !sleepEntries.isEmpty { sources.append("Sono (Apple Health / app)") }
        if !weekSessions.isEmpty { sources.append("Treinos registrados") }
        if profile?.weight != nil || !checkIns.isEmpty { sources.append("Peso") }
        if profile?.bodyMeasurements.waistCm != nil || profile?.previousBodyMeasurements?.waistCm != nil {
            sources.append("Medidas corporais")
        }
        if !goals.isEmpty { sources.append("Metas do profissional") }

        let points = reviewPoints(
            mealPct: mealPct,
            proteinAvg: proteinAvg,
            proteinGoal: proteinGoal,
            avgSleep: avgSleep,
            workoutsDone: workoutsDone,
            weightDelta: weightDelta,
            waistDelta: waistDelta,
            hasGoals: !goals.isEmpty
        )

        return ProfessionalReviewSnapshot(
            id: "review-\(link.id)",
            linkId: link.id,
            studentUid: link.studentUid,
            studentName: link.studentName,
            generatedAt: referenceDate,
            windowDays: 7,
            mealAdherencePercent: mealPct,
            averageProteinGramsPerDay: proteinAvg,
            proteinGoalGramsPerDay: proteinGoal,
            averageSleepHours: avgSleep,
            workoutsCompleted: workoutsDone,
            workoutsExpected: 7,
            weightDeltaKg30d: weightDelta,
            waistDeltaCm: waistDelta,
            reviewPoints: points,
            professionalGoals: Array(goals),
            dataSources: sources
        )
    }

    static func formatAssistantCard(_ snapshot: ProfessionalReviewSnapshot) -> String {
        """
        Resumo para revisão profissional (não é diagnóstico)

        Adesão alimentar: \(snapshot.mealAdherencePercent)%
        Proteína média: \(snapshot.averageProteinGramsPerDay) g/dia
        Meta: \(snapshot.proteinGoalGramsPerDay) g/dia
        Sono médio: \(snapshot.sleepFormatted)
        Treinos realizados: \(snapshot.workoutsCompleted)/\(snapshot.workoutsExpected)
        Peso: \(snapshot.weightDeltaLabel)
        Circunferência abdominal: \(snapshot.waistDeltaLabel)

        Pontos que merecem revisão pelo profissional:
        \(snapshot.reviewPoints.map { "• \($0)" }.joined(separator: "\n"))
        """
    }

    // MARK: - Private

    private static func averageCompletedProtein(weeklyPlan: [DailyMealPlan]) -> Int {
        var total = 0
        var daysWithCompleted = 0
        for day in weeklyPlan {
            let meals = day.options.first?.meals ?? []
            let done = meals.filter(\.isCompleted)
            guard !done.isEmpty else { continue }
            total += done.reduce(0) { $0 + $1.protein }
            daysWithCompleted += 1
        }
        guard daysWithCompleted > 0 else {
            // Fallback: média do plano prescrito (opção 1).
            let planned = weeklyPlan.compactMap { $0.options.first?.totalProtein }
            guard !planned.isEmpty else { return 0 }
            return Int((Double(planned.reduce(0, +)) / Double(planned.count)).rounded())
        }
        return Int((Double(total) / Double(daysWithCompleted)).rounded())
    }

    private static func proteinGoalGrams(for profile: UserProfile?, weeklyPlan: [DailyMealPlan]) -> Int {
        if let planned = weeklyPlan.compactMap({ $0.options.first?.totalProtein }).max(), planned > 0 {
            return planned
        }
        guard let weight = profile?.weight, weight > 0 else { return 0 }
        let perKg: Double
        switch profile?.goal {
        case .muscleGain: perKg = 2.0
        case .fatLoss: perKg = 1.8
        default: perKg = 1.6
        }
        return Int((weight * perKg).rounded())
    }

    private static func weightDeltaKg(
        profile: UserProfile?,
        checkIns: [NutritionCheckIn],
        since: Date,
        calendar: Calendar
    ) -> Double? {
        let sorted = checkIns
            .filter { $0.weightKg != nil && $0.createdAt >= since }
            .sorted { $0.createdAt < $1.createdAt }
        if let first = sorted.first?.weightKg, let last = sorted.last?.weightKg, sorted.count >= 2 {
            return (last - first) * 10 / 10
        }
        // Sem série de check-ins: não inventa delta.
        _ = profile
        _ = calendar
        return nil
    }

    private static func waistDeltaCm(profile: UserProfile?) -> Double? {
        guard let current = profile?.bodyMeasurements.waistCm ?? profile?.bodyMeasurements.abdomenCm,
              let previous = profile?.previousBodyMeasurements?.waistCm
                ?? profile?.previousBodyMeasurements?.abdomenCm
                ?? profile?.bodyMeasurementHistory.first?.waistCm
                ?? profile?.bodyMeasurementHistory.first?.abdomenCm
        else { return nil }
        return ((current - previous) * 10).rounded() / 10
    }

    private static func reviewPoints(
        mealPct: Int,
        proteinAvg: Int,
        proteinGoal: Int,
        avgSleep: Double,
        workoutsDone: Int,
        weightDelta: Double?,
        waistDelta: Double?,
        hasGoals: Bool
    ) -> [String] {
        var points: [String] = []
        if mealPct < 60 {
            points.append("Adesão alimentar abaixo de 60% na semana — revisar barreiras práticas e preferências.")
        }
        if proteinGoal > 0, proteinAvg > 0, Double(proteinAvg) < Double(proteinGoal) * 0.8 {
            points.append("Proteína média abaixo de 80% da meta — avaliar distribuição nas refeições.")
        }
        if avgSleep > 0, avgSleep < 6.5 {
            points.append("Sono médio abaixo de 6h30 — correlacionar com recuperação e fome.")
        }
        if workoutsDone < 3 {
            points.append("Poucos treinos na semana (\(workoutsDone)/7) — alinhar carga e disponibilidade.")
        }
        if let w = weightDelta, abs(w) >= 2 {
            points.append("Variação de peso relevante em 30 dias (\(String(format: "%+.1f", w)) kg) — validar contexto (água, ciclo, adesão).")
        }
        if let waist = waistDelta, abs(waist) >= 2 {
            points.append("Variação de cintura/abdômen ≥ 2 cm — confirmar técnica de medida e tendência.")
        }
        if !hasGoals {
            points.append("Sem metas ativas do profissional — sugerir definir 1–3 metas acompanháveis.")
        }
        if points.isEmpty {
            points.append("Indicadores estáveis no período — manter acompanhamento de rotina.")
        }
        return points
    }

    private static func dayDate(_ key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var c = DateComponents()
        c.year = parts[0]
        c.month = parts[1]
        c.day = parts[2]
        return calendar.date(from: c)
    }
}
