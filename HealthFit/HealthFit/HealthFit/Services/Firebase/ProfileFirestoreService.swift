import FirebaseFirestore
import Foundation

enum ProfileFirestoreService {
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

    private static func userDocument(userId: String) -> DocumentReference {
        db.collection("users").document(userId)
    }

    static func saveProfile(_ profile: UserProfile) async throws {
        guard isAvailable else { return }

        let payload = try encoder.encode(profile)
        guard let json = String(data: payload, encoding: .utf8) else { return }

        var data: [String: Any] = [
            "profilePayload": json,
            "email": profile.email,
            "name": profile.name,
            "displayName": profile.displayName,
            "weight": profile.weight,
            "height": profile.height,
            "age": profile.age,
            "goal": profile.goal.rawValue,
            "biotype": profile.biotype.rawValue,
            "hasBodyMeasurements": profile.bodyMeasurements.hasAnyValue,
            "updatedAt": Timestamp(date: .now),
            "createdAt": Timestamp(date: profile.createdAt),
        ]

            if let measuredAt = profile.bodyMeasurements.measuredAt {
                data["bodyMeasurementsUpdatedAt"] = Timestamp(date: measuredAt)
            }
            data["hasPreviousBodyMeasurements"] = profile.previousBodyMeasurements?.hasAnyValue == true

            try await userDocument(userId: profile.id).setData(data, merge: true)
    }

    static func fetchProfile(userId: String) async throws -> UserProfile? {
        guard isAvailable else { return nil }

        let snapshot = try await userDocument(userId: userId).getDocument()
        guard let data = snapshot.data(),
              let json = data["profilePayload"] as? String,
              let payload = json.data(using: .utf8) else {
            return nil
        }
        return try decoder.decode(UserProfile.self, from: payload)
    }
}
