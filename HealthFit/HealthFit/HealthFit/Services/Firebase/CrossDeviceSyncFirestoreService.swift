import FirebaseFirestore
import Foundation

// MARK: - Snapshots

struct UIPreferencesCloudSnapshot: Codable {
    var language: String?
    var restSeconds: Int
    var maxRestSeconds: Int
    var restNotifications: Bool
    var supplementRemindersEnabled: Bool
    var mealRemindersEnabled: Bool
    var mealMinutesFromMidnight: [String: Int]
    var lastWeeklyReportViewed: Date?
    var lastMonthlyReportViewed: Date?
    var updatedAt: Date
}

struct BikeCloudSnapshot: Codable {
    var entries: [BikeLogEntry]
    var wearByPart: [String: BikeWearState]
    var lifetimeKm: Double
    var updatedAt: Date
}

struct ClimbingGearCloudSnapshot: Codable {
    var items: [ClimbingGearItem]
    var updatedAt: Date
}

struct ActiveWorkoutCloudSnapshot: Codable {
    var session: WorkoutSession?
    var exerciseRecords: [ExerciseSessionRecord]
    var activeSessionExercises: [Exercise]
    var currentExerciseIndex: Int
    var isMinimized: Bool
    var isPaused: Bool
    var lastProgressAt: Date?
    var cardioConfig: CardioWorkoutConfig?
    var updatedAt: Date
    var deviceId: String
}

/// Persistência Firestore para estado que antes ficava só no device (iPhone ↔ iPad).
enum CrossDeviceSyncFirestoreService {
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

    static var isAvailable: Bool { FirebaseBootstrap.isConfigured }

    static var deviceId: String {
        let key = "healthfit.cross_device.device_id"
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }

    // MARK: - Paths

    private static func preferencesDoc(userId: String) -> DocumentReference {
        db.collection("users").document(userId).collection("settings").document("preferences")
    }

    private static func bikeDoc(userId: String) -> DocumentReference {
        db.collection("users").document(userId).collection("bikeMeta").document("state")
    }

    private static func climbingGearDoc(userId: String) -> DocumentReference {
        db.collection("users").document(userId).collection("climbingGear").document("inventory")
    }

    private static func activeWorkoutDoc(userId: String) -> DocumentReference {
        db.collection("users").document(userId).collection("activeWorkout").document("current")
    }

    // MARK: - Preferences

    static func savePreferences(_ snapshot: UIPreferencesCloudSnapshot, userId: String) async throws {
        try await savePayload(snapshot, to: preferencesDoc(userId: userId), updatedAt: snapshot.updatedAt)
    }

    static func fetchPreferences(userId: String) async throws -> UIPreferencesCloudSnapshot? {
        try await fetchPayload(from: preferencesDoc(userId: userId))
    }

    // MARK: - Bike

    static func saveBike(_ snapshot: BikeCloudSnapshot, userId: String) async throws {
        try await savePayload(snapshot, to: bikeDoc(userId: userId), updatedAt: snapshot.updatedAt)
    }

    static func fetchBike(userId: String) async throws -> BikeCloudSnapshot? {
        try await fetchPayload(from: bikeDoc(userId: userId))
    }

    // MARK: - Climbing gear

    static func saveClimbingGear(_ snapshot: ClimbingGearCloudSnapshot, userId: String) async throws {
        try await savePayload(snapshot, to: climbingGearDoc(userId: userId), updatedAt: snapshot.updatedAt)
    }

    static func fetchClimbingGear(userId: String) async throws -> ClimbingGearCloudSnapshot? {
        try await fetchPayload(from: climbingGearDoc(userId: userId))
    }

    // MARK: - Active workout

    static func saveActiveWorkout(_ snapshot: ActiveWorkoutCloudSnapshot, userId: String) async throws {
        try await savePayload(snapshot, to: activeWorkoutDoc(userId: userId), updatedAt: snapshot.updatedAt)
    }

    static func fetchActiveWorkout(userId: String) async throws -> ActiveWorkoutCloudSnapshot? {
        try await fetchPayload(from: activeWorkoutDoc(userId: userId))
    }

    static func clearActiveWorkout(userId: String) async throws {
        guard isAvailable else { return }
        try await activeWorkoutDoc(userId: userId).delete()
    }

    // MARK: - Account wipe

    static func deleteAllUserData(userId: String) async throws {
        guard isAvailable else { return }
        let refs = [
            preferencesDoc(userId: userId),
            bikeDoc(userId: userId),
            climbingGearDoc(userId: userId),
            activeWorkoutDoc(userId: userId),
        ]
        for ref in refs {
            try? await ref.delete()
        }
    }

    // MARK: - Helpers

    private static func savePayload<T: Encodable>(
        _ value: T,
        to document: DocumentReference,
        updatedAt: Date
    ) async throws {
        guard isAvailable else { return }
        let data = try encoder.encode(value)
        guard let json = String(data: data, encoding: .utf8) else { return }
        try await document.setData([
            "payload": json,
            "updatedAt": Timestamp(date: updatedAt),
        ], merge: true)
    }

    private static func fetchPayload<T: Decodable>(from document: DocumentReference) async throws -> T? {
        guard isAvailable else { return nil }
        let snapshot = try await document.getDocument()
        guard let data = snapshot.data(),
              let json = data["payload"] as? String,
              let payload = json.data(using: .utf8) else {
            return nil
        }
        return try? decoder.decode(T.self, from: payload)
    }
}
