import Foundation

struct WorkoutOfTheDaySuggestion: Identifiable, Hashable {
    var id: String { sheet.id.uuidString }
    let sheet: WorkoutSheet
    let avoidedMuscles: [MuscleGroup]
    let focusMuscles: [MuscleGroup]
    let reason: String
}

struct MuscleGroupStat: Identifiable, Hashable {
    var id: String { group.rawValue }
    let group: MuscleGroup
    let sessionHits: Int
    let exerciseHits: Int
}

struct CardioTypeStat: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let count: Int
}

struct MuscleGroupPeriodReport: Hashable {
    let periodLabel: String
    let stats: [MuscleGroupStat]
    let suggestions: [String]
    let totalStrengthSessions: Int
    let totalCardioSessions: Int
    let cardioByType: [CardioTypeStat]
}

enum WorkoutDaySuggestionAnalyzer {
    static let weeklyGoalDefault = 3

    // MARK: - Muscles trained recently

    static func musclesTrained(
        in sessions: [WorkoutSession],
        sheets: [WorkoutSheet],
        since: Date,
        until: Date = .now
    ) -> Set<MuscleGroup> {
        var result = Set<MuscleGroup>()
        for session in strengthSessions(sessions, from: since, to: until) {
            result.formUnion(muscles(in: session, sheets: sheets))
        }
        return result.subtracting([.fullBody])
    }

    static func muscles(in session: WorkoutSession, sheets: [WorkoutSheet]) -> Set<MuscleGroup> {
        var result = Set<MuscleGroup>()
        for record in session.exerciseRecords where record.isCompleted || record.completedSets > 0 {
            let group = muscleGroup(for: record, session: session, sheets: sheets)
            if group == .fullBody {
                result.formUnion([.chest, .back, .legs, .shoulders, .arms])
            } else {
                result.insert(group)
            }
        }
        if result.isEmpty, let sheet = sheets.first(where: { $0.id == session.workoutSheetId }) {
            for exercise in sheet.exercises {
                if exercise.muscleGroup == .fullBody {
                    result.formUnion([.chest, .back, .legs, .shoulders, .arms])
                } else {
                    result.insert(exercise.muscleGroup)
                }
            }
        }
        return result
    }

    static func muscleGroup(
        for record: ExerciseSessionRecord,
        session: WorkoutSession,
        sheets: [WorkoutSheet]
    ) -> MuscleGroup {
        if let sheet = sheets.first(where: { $0.id == session.workoutSheetId }),
           let exercise = sheet.exercises.first(where: { $0.id == record.exerciseId }) {
            return exercise.muscleGroup
        }
        if let exercise = sheets.lazy.flatMap(\.exercises).first(where: { $0.id == record.exerciseId }) {
            return exercise.muscleGroup
        }
        let key = normalize(record.exerciseName)
        if let exercise = sheets.lazy.flatMap(\.exercises).first(where: { normalize($0.name) == key }) {
            return exercise.muscleGroup
        }
        return WorkoutSheetOCRParser.inferredMuscleGroup(for: record.exerciseName)
    }

    // MARK: - Treino do dia

    static func suggestWorkoutOfTheDay(
        sessions: [WorkoutSession],
        candidateSheets: [WorkoutSheet],
        sheetsCatalog: [WorkoutSheet],
        referenceDate: Date = .now
    ) -> WorkoutOfTheDaySuggestion? {
        let calendar = Calendar.current
        let since = calendar.date(byAdding: .day, value: -2, to: referenceDate) ?? referenceDate.addingTimeInterval(-172_800)
        let avoided = musclesTrained(in: sessions, sheets: sheetsCatalog, since: since, until: referenceDate)

        let uniqueCandidates = Dictionary(candidateSheets.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
            .values
            .filter { !$0.exercises.isEmpty && $0.isActive }
            .sorted { $0.updatedAt > $1.updatedAt }

        guard !uniqueCandidates.isEmpty else { return nil }

        let recentSheetIds = Set(
            strengthSessions(sessions, from: since, to: referenceDate)
                .compactMap(\.workoutSheetId)
        )

        struct Scored {
            let sheet: WorkoutSheet
            let focus: [MuscleGroup]
            let score: Int
        }

        let scored: [Scored] = uniqueCandidates.map { sheet in
            let focus = primaryMuscles(in: sheet)
            var score = 100
            let overlap = Set(focus).intersection(avoided)
            score -= overlap.count * 35
            if recentSheetIds.contains(sheet.id) { score -= 40 }
            // Prefer sheets that cover undertrained areas when we have history.
            if !avoided.isEmpty {
                let fresh = Set(focus).subtracting(avoided)
                score += fresh.count * 18
            }
            // Slight preference for structured splits.
            let title = sheet.title.lowercased()
            if title.contains("push") || title.contains("pull") || title.contains("legs") || title.contains("peito") || title.contains("costas") || title.contains("pernas") {
                score += 6
            }
            return Scored(sheet: sheet, focus: focus, score: score)
        }
        .sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.sheet.title.localizedCaseInsensitiveCompare(rhs.sheet.title) == .orderedAscending
        }

        guard let best = scored.first else { return nil }
        let avoidedList = avoided.sorted { $0.rawValue < $1.rawValue }
        let reason: String
        if avoidedList.isEmpty {
            reason = "Sem treino de musculação nos últimos 2 dias — boa hora para retomar."
        } else {
            let names = avoidedList.map(\.rawValue).joined(separator: ", ")
            reason = "Você treinou \(names) nos últimos 2 dias. Hoje o foco evita repetir esses grupos."
        }

        return WorkoutOfTheDaySuggestion(
            sheet: best.sheet,
            avoidedMuscles: avoidedList,
            focusMuscles: best.focus,
            reason: reason
        )
    }

    static func primaryMuscles(in sheet: WorkoutSheet) -> [MuscleGroup] {
        var counts: [MuscleGroup: Int] = [:]
        for exercise in sheet.exercises {
            let group = exercise.muscleGroup == .fullBody ? MuscleGroup.legs : exercise.muscleGroup
            counts[group, default: 0] += 1
        }
        return counts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key.rawValue < rhs.key.rawValue
            }
            .prefix(3)
            .map(\.key)
    }

    // MARK: - Period stats

    static func report(
        sessions: [WorkoutSession],
        sheets: [WorkoutSheet],
        days: Int,
        periodLabel: String,
        referenceDate: Date = .now
    ) -> MuscleGroupPeriodReport {
        let calendar = Calendar.current
        let since = calendar.date(byAdding: .day, value: -days, to: referenceDate) ?? referenceDate
        let window = strengthSessions(sessions, from: since, to: referenceDate)

        var sessionHits: [MuscleGroup: Int] = [:]
        var exerciseHits: [MuscleGroup: Int] = [:]

        for session in window {
            let groups = muscles(in: session, sheets: sheets)
            for group in groups {
                sessionHits[group, default: 0] += 1
            }
            for record in session.exerciseRecords where record.completedSets > 0 {
                let group = muscleGroup(for: record, session: session, sheets: sheets)
                let targets = group == .fullBody
                    ? [.chest, .back, .legs, .shoulders, .arms]
                    : [group]
                for target in targets {
                    exerciseHits[target, default: 0] += 1
                }
            }
        }

        let tracked: [MuscleGroup] = [.chest, .back, .legs, .shoulders, .arms, .core]
        let stats = tracked.map { group in
            MuscleGroupStat(
                group: group,
                sessionHits: sessionHits[group, default: 0],
                exerciseHits: exerciseHits[group, default: 0]
            )
        }
        .sorted { lhs, rhs in
            if lhs.sessionHits != rhs.sessionHits { return lhs.sessionHits > rhs.sessionHits }
            if lhs.exerciseHits != rhs.exerciseHits { return lhs.exerciseHits > rhs.exerciseHits }
            return lhs.group.rawValue < rhs.group.rawValue
        }

        let cardioWindow = cardioSessions(sessions, from: since, to: referenceDate)
        var cardioCounts: [String: Int] = [:]
        for session in cardioWindow {
            let name = cardioDisplayName(for: session)
            cardioCounts[name, default: 0] += 1
        }
        let cardioByType = cardioCounts
            .map { CardioTypeStat(name: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

        return MuscleGroupPeriodReport(
            periodLabel: periodLabel,
            stats: stats,
            suggestions: buildSuggestions(
                stats: stats,
                sessions: window.count,
                cardioSessions: cardioWindow.count
            ),
            totalStrengthSessions: window.count,
            totalCardioSessions: cardioWindow.count,
            cardioByType: cardioByType
        )
    }

    // MARK: - Widget helpers

    static func bestRecentLift(
        sessions: [WorkoutSession],
        sheets: [WorkoutSheet],
        withinDays: Int = 30,
        referenceDate: Date = .now
    ) -> (weightKg: Int, exerciseName: String, equipment: String)? {
        let calendar = Calendar.current
        let since = calendar.date(byAdding: .day, value: -withinDays, to: referenceDate) ?? referenceDate
        var best: (weight: Double, name: String, equipment: String)?

        for session in strengthSessions(sessions, from: since, to: referenceDate) {
            for record in session.exerciseRecords {
                let maxWeight = record.performedWeight.flatMap { $0 > 0 ? $0 : nil }
                    ?? ((record.completedSets > 0) ? record.recommendedWeight.flatMap { $0 > 0 ? $0 : nil } : nil)
                    ?? 0
                guard maxWeight > 0 else { continue }
                if let current = best, maxWeight <= current.weight { continue }
                best = (
                    weight: maxWeight,
                    name: record.exerciseName.trimmingCharacters(in: .whitespacesAndNewlines),
                    equipment: equipmentHint(for: record.exerciseName)
                )
            }
        }

        guard let best, !best.name.isEmpty else { return nil }
        return (Int(best.weight.rounded()), best.name, best.equipment)
    }

    static func strengthSessionsThisWeek(
        sessions: [WorkoutSession],
        referenceDate: Date = .now
    ) -> Int {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start
            ?? calendar.startOfDay(for: referenceDate)
        return strengthSessions(sessions, from: weekStart, to: referenceDate).count
    }

    static func streakDays(sessions: [WorkoutSession], referenceDate: Date = .now) -> Int {
        let calendar = Calendar.current
        let days = Set(
            sessions.compactMap { session -> Date? in
                guard !WeeklyProgressAnalyzer.isCardioSession(session),
                      !WeeklyProgressAnalyzer.isMeditationSession(session) else { return nil }
                let ended = session.endedAt ?? session.startedAt
                return calendar.startOfDay(for: ended)
            }
        )
        var streak = 0
        var cursor = calendar.startOfDay(for: referenceDate)
        // Allow "yesterday" start if no workout today yet.
        if !days.contains(cursor) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        while days.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    // MARK: - Private

    private static func strengthSessions(
        _ sessions: [WorkoutSession],
        from: Date,
        to: Date
    ) -> [WorkoutSession] {
        sessions.filter { session in
            let ended = session.endedAt ?? session.startedAt
            guard ended >= from, ended <= to else { return false }
            guard !WeeklyProgressAnalyzer.isCardioSession(session) else { return false }
            guard !WeeklyProgressAnalyzer.isMeditationSession(session) else { return false }
            return true
        }
    }

    private static func cardioSessions(
        _ sessions: [WorkoutSession],
        from: Date,
        to: Date
    ) -> [WorkoutSession] {
        sessions.filter { session in
            let ended = session.endedAt ?? session.startedAt
            guard ended >= from, ended <= to else { return false }
            return WeeklyProgressAnalyzer.isCardioSession(session)
        }
    }

    private static func cardioDisplayName(for session: WorkoutSession) -> String {
        let title = session.completedModalityTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Cardio" : title
    }

    private static func buildSuggestions(
        stats: [MuscleGroupStat],
        sessions: Int,
        cardioSessions: Int
    ) -> [String] {
        guard sessions > 0 || cardioSessions > 0 else {
            return ["Registre treinos de musculação e cardio para ver o equilíbrio e receber sugestões."]
        }

        var tips: [String] = []
        let maxHits = stats.map(\.sessionHits).max() ?? 0
        let minHits = stats.map(\.sessionHits).min() ?? 0
        let under = stats.filter { $0.sessionHits == minHits && $0.sessionHits < max(1, maxHits - 1) }
        let over = stats.filter { $0.sessionHits == maxHits && maxHits >= 3 }

        if sessions == 0 {
            tips.append("Nenhuma musculação no período. Combine força com cardio para evoluir melhor.")
        }

        if !under.isEmpty, sessions > 0, maxHits - minHits >= 2 {
            let names = under.prefix(2).map(\.group.rawValue).joined(separator: " e ")
            tips.append("Priorize \(names) — está(ão) abaixo dos grupos mais treinados.")
        }

        if let chest = stats.first(where: { $0.group == .chest }),
           let back = stats.first(where: { $0.group == .back }),
           chest.sessionHits >= back.sessionHits + 2 {
            tips.append("Peito aparece mais que costas. Inclua puxadas/remadas para equilíbrio postural.")
        }

        if let legs = stats.first(where: { $0.group == .legs }), legs.sessionHits == 0, sessions >= 2 {
            tips.append("Pernas ainda não entraram no período. Um treino de inferiores melhora recuperação e hormônio.")
        }

        if over.count == 1, let hot = over.first, hot.sessionHits >= 4 {
            tips.append("\(hot.group.rawValue) foi muito estimulado (\(hot.sessionHits)×). Garanta 48h de descanso nesse grupo.")
        }

        if cardioSessions == 0, sessions >= 2 {
            tips.append("Inclua cardio (caminhada, corrida ou bike) 1–2× na semana para condicionamento.")
        } else if cardioSessions >= 5, sessions == 0 {
            tips.append("Muito cardio e pouca força. Adicione musculação para preservar massa muscular.")
        }

        if tips.isEmpty {
            tips.append("Boa distribuição de estímulos. Mantenha a frequência e progresse carga com técnica.")
        }
        if let firstUnder = under.first, tips.count < 3, under.count == 1, sessions > 0 {
            tips.append("Sugestão prática: abra uma ficha com foco em \(firstUnder.group.rawValue) no hub de treinos.")
        }
        return Array(tips.prefix(4))
    }

    private static func equipmentHint(for name: String) -> String {
        let n = name.lowercased()
        if n.contains("barra") || n.contains("supino reto") || n.contains("levantamento terra") || n.contains("agachamento livre") {
            return "Barra"
        }
        if n.contains("halter") { return "Halteres" }
        if n.contains("polia") || n.contains("pulley") || n.contains("cabo") || n.contains("crossover") {
            return "Cabo"
        }
        if n.contains("máquina") || n.contains("leg press") || n.contains("smith") {
            return "Máquina"
        }
        return ""
    }

    private static func normalize(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
    }
}
