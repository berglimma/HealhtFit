import FirebaseFirestore
import Foundation

enum MealPhotoAnalysisFirestoreService {
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

    private static func collection(userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("mealPhotoAnalyses")
    }

    static func save(_ entry: MealPhotoAnalysisEntry, userId: String) async throws {
        guard isAvailable else { return }
        let payload = try encoder.encode(entry)
        guard let json = String(data: payload, encoding: .utf8) else { return }

        try await collection(userId: userId).document(entry.id).setData([
            "payload": json,
            "mealType": entry.mealType.rawValue,
            "dayKey": entry.dayKey,
            "foodLabel": entry.foodLabel,
            "proteinGrams": entry.proteinGrams,
            "carbsGrams": entry.carbsGrams,
            "fatGrams": entry.fatGrams,
            "calories": entry.calories,
            "confidence": entry.confidence,
            "photoDiscarded": true,
            "analyzedAt": Timestamp(date: entry.analyzedAt),
            "updatedAt": Timestamp(date: .now),
        ], merge: true)
    }

    static func fetchRecent(userId: String, limit: Int = 60) async throws -> [MealPhotoAnalysisEntry] {
        guard isAvailable else { return [] }
        let snapshot = try await collection(userId: userId)
            .order(by: "analyzedAt", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            guard let json = document.data()["payload"] as? String,
                  let data = json.data(using: .utf8) else { return nil }
            return try? decoder.decode(MealPhotoAnalysisEntry.self, from: data)
        }
    }

    static func deleteAllUserData(userId: String) async throws {
        guard isAvailable else { return }
        let docs = try await collection(userId: userId).getDocuments()
        for document in docs.documents {
            try await document.reference.delete()
        }
    }
}
