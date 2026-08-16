import FirebaseFirestore
import Foundation

enum WorkoutFirestoreService {
    static let maxStoredSessions = 100

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

    private static func sessionsCollection(userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("workoutSessions")
    }

    private static func sheetsCollection(userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("workoutSheets")
    }

    static func saveSheet(_ sheet: WorkoutSheet, userId: String) async throws {
        guard isAvailable, sheet.isCloudSyncable else { return }

        let payload = try encoder.encode(sheet)
        guard let json = String(data: payload, encoding: .utf8) else { return }

        let document = sheetsCollection(userId: userId).document(sheet.id.uuidString)
        try await document.setData([
            "payload": json,
            "title": sheet.title,
            "createdAt": Timestamp(date: sheet.createdAt),
            "updatedAt": Timestamp(date: sheet.updatedAt),
            "isUserCreated": sheet.isUserCreated,
            "createdByAssistant": sheet.createdByAssistant,
        ])
    }

    static func deleteSheet(id: UUID, userId: String) async throws {
        guard isAvailable else { return }
        try await sheetsCollection(userId: userId).document(id.uuidString).delete()
    }

    static func fetchSheets(userId: String) async throws -> [WorkoutSheet] {
        guard isAvailable else { return [] }

        let snapshot = try await sheetsCollection(userId: userId).getDocuments()
        return snapshot.documents.compactMap { decodeSheet(from: $0.data()) }
    }

    private static func decodeSheet(from data: [String: Any]) -> WorkoutSheet? {
        guard let json = data["payload"] as? String,
              let payload = json.data(using: .utf8) else {
            return nil
        }
        return try? decoder.decode(WorkoutSheet.self, from: payload)
    }

    static func saveSession(_ session: WorkoutSession, userId: String) async throws {
        guard isAvailable else { return }

        let payload = try encoder.encode(session)
        guard let json = String(data: payload, encoding: .utf8) else { return }

        let endedAt = session.endedAt ?? session.startedAt
        let document = sessionsCollection(userId: userId).document(session.id.uuidString)

        try await document.setData([
            "payload": json,
            "workoutTitle": session.workoutTitle,
            "startedAt": Timestamp(date: session.startedAt),
            "endedAt": Timestamp(date: endedAt),
            "updatedAt": Timestamp(date: .now),
        ])

        try await trimOldestSessions(userId: userId)
    }

    static func fetchRecentSessions(userId: String) async throws -> [WorkoutSession] {
        guard isAvailable else { return [] }

        let snapshot = try await sessionsCollection(userId: userId)
            .order(by: "endedAt", descending: true)
            .limit(to: maxStoredSessions)
            .getDocuments()

        return snapshot.documents.compactMap { decodeSession(from: $0.data()) }
    }

    private static func trimOldestSessions(userId: String) async throws {
        let snapshot = try await sessionsCollection(userId: userId)
            .order(by: "endedAt", descending: true)
            .getDocuments()

        guard snapshot.documents.count > maxStoredSessions else { return }

        for document in snapshot.documents.dropFirst(maxStoredSessions) {
            try await document.reference.delete()
        }
    }

    private static func decodeSession(from data: [String: Any]) -> WorkoutSession? {
        guard let json = data["payload"] as? String,
              let payload = json.data(using: .utf8) else {
            return nil
        }
        return try? decoder.decode(WorkoutSession.self, from: payload)
    }

    static func deleteAllUserData(userId: String) async throws {
        guard isAvailable else { return }

        let userDocument = db.collection("users").document(userId)
        let sessions = try await userDocument.collection("workoutSessions").getDocuments()
        for document in sessions.documents {
            try await document.reference.delete()
        }

        let sheets = try await userDocument.collection("workoutSheets").getDocuments()
        for document in sheets.documents {
            try await document.reference.delete()
        }
    }

    /// Remove o documento raiz do usuário após limpar subcollections.
    static func deleteUserDocument(userId: String) async throws {
        guard isAvailable else { return }
        try await db.collection("users").document(userId).delete()
    }
}
