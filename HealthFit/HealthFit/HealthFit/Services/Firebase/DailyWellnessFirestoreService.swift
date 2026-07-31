import FirebaseFirestore
import Foundation

enum DailyWellnessFirestoreService {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static var db: Firestore { Firestore.firestore() }

    static var isAvailable: Bool {
        FirebaseBootstrap.isConfigured
    }

    private static func entriesCollection(userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("dailyWellness")
    }

    private static func metaDocument(userId: String) -> DocumentReference {
        db.collection("users").document(userId).collection("wellnessMeta").document("state")
    }

    static func saveEntry(_ entry: DailyWellnessEntry, userId: String, waterGoalMl: Int? = nil) async throws {
        guard isAvailable else { return }

        let payload = try encoder.encode(entry)
        guard let json = String(data: payload, encoding: .utf8) else { return }

        let document = entriesCollection(userId: userId).document(entry.dayKey)
        var data: [String: Any] = [
            "payload": json,
            "dayKey": entry.dayKey,
            "waterIntakeMl": entry.waterIntakeMl,
            "energyDrinksCount": entry.energyDrinksCount,
            "preWorkoutCount": entry.preWorkoutCount,
            "supplementIntakeCount": entry.supplementIntakes.count,
            "updatedAt": Timestamp(date: .now),
        ]
        if let waterGoalMl, waterGoalMl > 0 {
            data["waterGoalMl"] = waterGoalMl
        }
        if let sleepHours = entry.sleepHours {
            data["sleepHours"] = sleepHours
        } else {
            data["sleepHours"] = NSNull()
        }
        if let sleepUpdatedAt = entry.sleepUpdatedAt {
            data["sleepUpdatedAt"] = Timestamp(date: sleepUpdatedAt)
        }
        if let waterUpdatedAt = entry.waterUpdatedAt {
            data["waterUpdatedAt"] = Timestamp(date: waterUpdatedAt)
        }

        try await document.setData(data, merge: true)
    }

    static func fetchEntry(userId: String, dayKey: String) async throws -> DailyWellnessEntry? {
        guard isAvailable else { return nil }

        let snapshot = try await entriesCollection(userId: userId).document(dayKey).getDocument()
        guard let data = snapshot.data() else { return nil }
        return decodeEntry(from: data)
    }

    static func fetchRecentEntries(userId: String, limit: Int = 60) async throws -> [DailyWellnessEntry] {
        guard isAvailable else { return [] }

        let snapshot = try await entriesCollection(userId: userId)
            .order(by: "dayKey", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { decodeEntry(from: $0.data()) }
    }

    static func saveMeta(
        userId: String,
        lastWaterOrSleepUpdateAt: Date?,
        trackingStartedAt: Date?
    ) async throws {
        guard isAvailable else { return }

        var data: [String: Any] = [
            "updatedAt": Timestamp(date: .now),
        ]
        if let lastWaterOrSleepUpdateAt {
            data["lastWaterOrSleepUpdateAt"] = Timestamp(date: lastWaterOrSleepUpdateAt)
        }
        if let trackingStartedAt {
            data["trackingStartedAt"] = Timestamp(date: trackingStartedAt)
        }

        try await metaDocument(userId: userId).setData(data, merge: true)
    }

    static func fetchMeta(userId: String) async throws -> (lastWaterOrSleepUpdateAt: Date?, trackingStartedAt: Date?) {
        guard isAvailable else { return (nil, nil) }

        let snapshot = try await metaDocument(userId: userId).getDocument()
        guard let data = snapshot.data() else { return (nil, nil) }

        let last = (data["lastWaterOrSleepUpdateAt"] as? Timestamp)?.dateValue()
        let tracking = (data["trackingStartedAt"] as? Timestamp)?.dateValue()
        return (last, tracking)
    }

    static func deleteAllEntries(userId: String) async throws {
        guard isAvailable else { return }

        let entries = try await entriesCollection(userId: userId).getDocuments()
        for document in entries.documents {
            try await document.reference.delete()
        }

        let meta = try await db.collection("users").document(userId).collection("wellnessMeta").getDocuments()
        for document in meta.documents {
            try await document.reference.delete()
        }
    }

    private static func decodeEntry(from data: [String: Any]) -> DailyWellnessEntry? {
        if let json = data["payload"] as? String,
           let payload = json.data(using: .utf8),
           let entry = try? decoder.decode(DailyWellnessEntry.self, from: payload) {
            return entry
        }

        // Fallback para documentos parciais.
        guard let dayKey = data["dayKey"] as? String else { return nil }
        return DailyWellnessEntry(
            dayKey: dayKey,
            sleepHours: data["sleepHours"] as? Double,
            waterIntakeMl: data["waterIntakeMl"] as? Int ?? 0,
            energyDrinksCount: data["energyDrinksCount"] as? Int ?? 0,
            preWorkoutCount: data["preWorkoutCount"] as? Int ?? 0,
            sleepUpdatedAt: (data["sleepUpdatedAt"] as? Timestamp)?.dateValue(),
            waterUpdatedAt: (data["waterUpdatedAt"] as? Timestamp)?.dateValue()
        )
    }
}
