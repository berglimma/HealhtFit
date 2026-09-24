import Foundation

enum StrengthPerformancePeriod: String, CaseIterable, Identifiable {
    case oneMonth = "1m"
    case threeMonths = "3m"
    case sixMonths = "6m"
    case oneYear = "1a"
    case all = "Tudo"

    var id: String { rawValue }

    var monthSpan: Int? {
        switch self {
        case .oneMonth: return 1
        case .threeMonths: return 3
        case .sixMonths: return 6
        case .oneYear: return 12
        case .all: return nil
        }
    }
}

struct Estimated1RMPoint: Identifiable, Hashable {
    let id: Date
    let date: Date
    let estimated1RM: Double
    let performedWeight: Double
    let reps: Int
}

struct WeeklyVolumeSlice: Identifiable, Hashable {
    var id: String { "\(weekStart.timeIntervalSince1970)-\(muscleGroup.rawValue)" }
    let weekStart: Date
    let muscleGroup: MuscleGroup
    let volumeKg: Double
}

struct StrengthExerciseOption: Identifiable, Hashable {
    var id: String { nameKey }
    let nameKey: String
    let displayName: String
    let sessionCount: Int
}

enum StrengthPerformanceAnalyzer {
    /// Epley: 1RM ≈ w × (1 + reps/30). Com 1 rep, usa a própria carga.
    static func estimated1RM(weight: Double, reps: Int) -> Double {
        guard weight > 0 else { return 0 }
        let r = max(reps, 1)
        if r == 1 { return weight }
        return weight * (1 + Double(r) / 30.0)
    }

    static func availableExercises(
        sessions: [WorkoutSession],
        period: StrengthPerformancePeriod,
        referenceDate: Date = .now
    ) -> [StrengthExerciseOption] {
        let window = dateWindow(period: period, referenceDate: referenceDate)
        var counts: [String: (display: String, count: Int)] = [:]

        for session in strengthSessions(sessions, in: window) {
            for record in session.exerciseRecords {
                guard let weight = effectiveWeight(for: record), weight > 0, record.completedSets > 0 else { continue }
                let key = normalizeName(record.exerciseName)
                guard !key.isEmpty else { continue }
                let display = record.exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
                var entry = counts[key] ?? (display: display, count: 0)
                entry.count += 1
                if display.count > entry.display.count { entry.display = display }
                counts[key] = entry
            }
        }

        return counts
            .map { StrengthExerciseOption(nameKey: $0.key, displayName: $0.value.display, sessionCount: $0.value.count) }
            .sorted { lhs, rhs in
                if lhs.sessionCount != rhs.sessionCount { return lhs.sessionCount > rhs.sessionCount }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    static func estimated1RMSeries(
        exerciseNameKey: String,
        sessions: [WorkoutSession],
        sheets: [WorkoutSheet],
        period: StrengthPerformancePeriod,
        referenceDate: Date = .now
    ) -> [Estimated1RMPoint] {
        let window = dateWindow(period: period, referenceDate: referenceDate)
        let calendar = Calendar.current
        var bestByDay: [Date: Estimated1RMPoint] = [:]

        for session in strengthSessions(sessions, in: window) {
            let day = calendar.startOfDay(for: session.endedAt ?? session.startedAt)
            for record in session.exerciseRecords {
                guard normalizeName(record.exerciseName) == exerciseNameKey else { continue }
                guard let weight = effectiveWeight(for: record), weight > 0 else { continue }
                guard record.completedSets > 0 || record.isCompleted else { continue }

                let meta = resolveExerciseMeta(record: record, session: session, sheets: sheets)
                let oneRM = estimated1RM(weight: weight, reps: meta.reps)
                guard oneRM > 0 else { continue }

                let point = Estimated1RMPoint(
                    id: day,
                    date: day,
                    estimated1RM: oneRM,
                    performedWeight: weight,
                    reps: meta.reps
                )
                if let existing = bestByDay[day] {
                    if point.estimated1RM > existing.estimated1RM {
                        bestByDay[day] = point
                    }
                } else {
                    bestByDay[day] = point
                }
            }
        }

        return bestByDay.values.sorted { $0.date < $1.date }
    }

    static func weeklyVolumeSeries(
        sessions: [WorkoutSession],
        sheets: [WorkoutSheet],
        period: StrengthPerformancePeriod,
        referenceDate: Date = .now
    ) -> [WeeklyVolumeSlice] {
        let window = dateWindow(period: period, referenceDate: referenceDate)
        let calendar = Calendar.current
        var buckets: [Date: [MuscleGroup: Double]] = [:]

        for session in strengthSessions(sessions, in: window) {
            let day = session.endedAt ?? session.startedAt
            let weekStart = startOfWeek(for: day, calendar: calendar)

            for record in session.exerciseRecords {
                guard let weight = effectiveWeight(for: record), weight > 0 else { continue }
                let sets = max(record.completedSets, record.isCompleted ? 1 : 0)
                guard sets > 0 else { continue }

                let meta = resolveExerciseMeta(record: record, session: session, sheets: sheets)
                let volume = Double(sets) * weight * Double(meta.reps)
                guard volume > 0 else { continue }

                // Volume atribuído ao grupo principal; corpo inteiro divide entre grupos principais.
                let shares = volumeShares(for: meta.muscleGroup)
                var week = buckets[weekStart] ?? [:]
                for (group, fraction) in shares {
                    week[group, default: 0] += volume * fraction
                }
                buckets[weekStart] = week
            }
        }

        var slices: [WeeklyVolumeSlice] = []
        for (week, groups) in buckets {
            for (group, volume) in groups where volume > 0 {
                slices.append(WeeklyVolumeSlice(weekStart: week, muscleGroup: group, volumeKg: volume))
            }
        }
        return slices.sorted {
            if $0.weekStart != $1.weekStart { return $0.weekStart < $1.weekStart }
            return $0.muscleGroup.rawValue < $1.muscleGroup.rawValue
        }
    }

    // MARK: - Helpers

    private static func dateWindow(
        period: StrengthPerformancePeriod,
        referenceDate: Date
    ) -> DateInterval? {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: referenceDate).addingTimeInterval(24 * 60 * 60 - 1)
        guard let months = period.monthSpan else { return nil }
        guard let start = calendar.date(byAdding: .month, value: -months, to: calendar.startOfDay(for: referenceDate)) else {
            return nil
        }
        return DateInterval(start: start, end: end)
    }

    private static func strengthSessions(_ sessions: [WorkoutSession], in window: DateInterval?) -> [WorkoutSession] {
        sessions.filter { session in
            guard session.endedAt != nil else { return false }
            guard session.source != .appleHealthExternal else { return false }
            guard !session.exerciseRecords.isEmpty else { return false }
            let date = session.endedAt ?? session.startedAt
            if let window, !window.contains(date) { return false }
            return true
        }
    }

    private static func effectiveWeight(for record: ExerciseSessionRecord) -> Double? {
        if let performed = record.performedWeight, performed > 0 { return performed }
        if let recommended = record.recommendedWeight, recommended > 0 { return recommended }
        return nil
    }

    private static func normalizeName(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
    }

    private static func startOfWeek(for date: Date, calendar: Calendar) -> Date {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    }

    private struct ExerciseMeta {
        let reps: Int
        let muscleGroup: MuscleGroup
    }

    private static func resolveExerciseMeta(
        record: ExerciseSessionRecord,
        session: WorkoutSession,
        sheets: [WorkoutSheet]
    ) -> ExerciseMeta {
        if let sheet = sheets.first(where: { $0.id == session.workoutSheetId }),
           let exercise = sheet.exercises.first(where: { $0.id == record.exerciseId }) {
            return ExerciseMeta(reps: max(exercise.reps, 1), muscleGroup: exercise.muscleGroup)
        }
        if let exercise = sheets.lazy.flatMap(\.exercises).first(where: { $0.id == record.exerciseId }) {
            return ExerciseMeta(reps: max(exercise.reps, 1), muscleGroup: exercise.muscleGroup)
        }
        let key = normalizeName(record.exerciseName)
        if let exercise = sheets.lazy.flatMap(\.exercises).first(where: { normalizeName($0.name) == key }) {
            return ExerciseMeta(reps: max(exercise.reps, 1), muscleGroup: exercise.muscleGroup)
        }
        return ExerciseMeta(
            reps: 8,
            muscleGroup: WorkoutSheetOCRParser.inferredMuscleGroup(for: record.exerciseName)
        )
    }

    private static func volumeShares(for group: MuscleGroup) -> [(MuscleGroup, Double)] {
        switch group {
        case .fullBody:
            return [
                (.chest, 0.2),
                (.back, 0.2),
                (.legs, 0.2),
                (.shoulders, 0.2),
                (.arms, 0.2)
            ]
        default:
            return [(group, 1.0)]
        }
    }
}
