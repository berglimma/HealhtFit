import Foundation

/// Amostra de humor/check-in usada para aprender a rotina emocional do usuário.
struct AssistantMoodSample: Codable, Equatable, Identifiable {
    var id: UUID
    var dateKey: String
    var kind: String
    var feeling: String
    var recordedAt: Date

    init(
        id: UUID = UUID(),
        dateKey: String,
        kind: String,
        feeling: String,
        recordedAt: Date = .now
    ) {
        self.id = id
        self.dateKey = dateKey
        self.kind = kind
        self.feeling = feeling
        self.recordedAt = recordedAt
    }
}

struct AssistantRoutineSnapshot: Codable, Equatable {
    var moodSamples: [AssistantMoodSample]
    var lastInsightDayKey: String?
    var lastAnalysisDayKey: String?

    static let empty = AssistantRoutineSnapshot(
        moodSamples: [],
        lastInsightDayKey: nil,
        lastAnalysisDayKey: nil
    )
}

/// Persistência leve da rotina aprendida pelo IAssistente (UserDefaults por usuário).
enum AssistantRoutineStore {
    private static let logicalKey = "assistant_routine.v1"
    private static let maxMoodSamples = 90

    static func load(userId: String?) -> AssistantRoutineSnapshot {
        guard let userId, !userId.isEmpty else { return .empty }
        guard let data = UserScopedDefaults.data(
            forLogicalKey: logicalKey,
            uid: userId,
            legacyKey: nil
        ),
        let decoded = try? JSONDecoder().decode(AssistantRoutineSnapshot.self, from: data) else {
            return .empty
        }
        return decoded
    }

    static func save(_ snapshot: AssistantRoutineSnapshot, userId: String?) {
        guard let userId, !userId.isEmpty else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserScopedDefaults.setData(data, forLogicalKey: logicalKey, uid: userId, legacyKey: nil)
    }

    static func recordMood(
        userId: String?,
        kind: String,
        feeling: String,
        date: Date = .now
    ) {
        guard let userId, !userId.isEmpty else { return }
        var snapshot = load(userId: userId)
        let key = dayKey(for: date)
        snapshot.moodSamples.removeAll {
            $0.dateKey == key && $0.kind == kind
        }
        snapshot.moodSamples.append(
            AssistantMoodSample(dateKey: key, kind: kind, feeling: feeling, recordedAt: date)
        )
        if snapshot.moodSamples.count > maxMoodSamples {
            snapshot.moodSamples = Array(
                snapshot.moodSamples.sorted { $0.recordedAt < $1.recordedAt }.suffix(maxMoodSamples)
            )
        }
        save(snapshot, userId: userId)
    }

    static func markInsightDelivered(userId: String?, dayKey: String) {
        var snapshot = load(userId: userId)
        snapshot.lastInsightDayKey = dayKey
        save(snapshot, userId: userId)
    }

    static func markAnalysisDelivered(userId: String?, dayKey: String) {
        var snapshot = load(userId: userId)
        snapshot.lastAnalysisDayKey = dayKey
        save(snapshot, userId: userId)
    }

    static func clear(userId: String?) {
        guard let userId, !userId.isEmpty else { return }
        UserScopedDefaults.remove(logicalKey: logicalKey, uid: userId, legacyKey: nil)
    }

    static func dayKey(for date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.calendar = MotivationMessages.localCalendar
        formatter.timeZone = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
