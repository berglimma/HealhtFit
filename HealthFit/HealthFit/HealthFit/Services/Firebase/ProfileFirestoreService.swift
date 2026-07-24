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
            "gender": profile.gender.rawValue,
            "goal": profile.goal.rawValue,
            "biotype": profile.biotype.rawValue,
            "hasBodyMeasurements": profile.bodyMeasurements.hasAnyValue,
            "updatedAt": Timestamp(date: .now),
            "createdAt": Timestamp(date: profile.createdAt),
        ]

        let measurements = profile.bodyMeasurements
        var bodyMeasurementsData: [String: Any] = [:]
        if let value = measurements.neckCm { bodyMeasurementsData["neckCm"] = value }
        if let value = measurements.shouldersCm { bodyMeasurementsData["shouldersCm"] = value }
        if let value = measurements.chestCm { bodyMeasurementsData["chestCm"] = value }
        if let value = measurements.rightArmCm { bodyMeasurementsData["rightArmCm"] = value }
        if let value = measurements.leftArmCm { bodyMeasurementsData["leftArmCm"] = value }
        if let value = measurements.waistCm { bodyMeasurementsData["waistCm"] = value }
        if let value = measurements.abdomenCm { bodyMeasurementsData["abdomenCm"] = value }
        if let value = measurements.hipCm { bodyMeasurementsData["hipCm"] = value }
        if let value = measurements.rightThighCm { bodyMeasurementsData["rightThighCm"] = value }
        if let value = measurements.leftThighCm { bodyMeasurementsData["leftThighCm"] = value }
        if let value = measurements.rightCalfCm { bodyMeasurementsData["rightCalfCm"] = value }
        if let value = measurements.leftCalfCm { bodyMeasurementsData["leftCalfCm"] = value }
        if let measuredAt = measurements.measuredAt {
            bodyMeasurementsData["measuredAt"] = Timestamp(date: measuredAt)
            data["bodyMeasurementsUpdatedAt"] = Timestamp(date: measuredAt)
        }
        data["bodyMeasurements"] = bodyMeasurementsData
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
