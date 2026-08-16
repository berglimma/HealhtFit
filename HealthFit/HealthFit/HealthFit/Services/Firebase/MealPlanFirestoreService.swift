import FirebaseFirestore
import Foundation

struct MealPlanCloudSnapshot: Codable {
    var weeklyPlan: [DailyMealPlan]
    var shoppingList: [ShoppingItem]
    var customMenuSelection: CustomMenuSelection
    var basalMetabolicRate: Int
    var dailyCalorieTarget: Int
    var estimatedTDEE: Int
    var caloricDeficit: Int
}

enum MealPlanFirestoreService {
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

    private static func planDocument(userId: String) -> DocumentReference {
        db.collection("users").document(userId).collection("mealPlan").document("current")
    }

    static func savePlan(_ snapshot: MealPlanCloudSnapshot, userId: String) async throws {
        guard isAvailable else { return }
        let payload = try encoder.encode(snapshot)
        guard let json = String(data: payload, encoding: .utf8) else { return }
        try await planDocument(userId: userId).setData([
            "payload": json,
            "updatedAt": Timestamp(date: .now),
            "dailyCalorieTarget": snapshot.dailyCalorieTarget,
            "mealDays": snapshot.weeklyPlan.count,
        ], merge: true)
    }

    static func fetchPlan(userId: String) async throws -> (snapshot: MealPlanCloudSnapshot, updatedAt: Date)? {
        guard isAvailable else { return nil }
        let snapshot = try await planDocument(userId: userId).getDocument()
        guard let data = snapshot.data(),
              let json = data["payload"] as? String,
              let payload = json.data(using: .utf8),
              let decoded = try? decoder.decode(MealPlanCloudSnapshot.self, from: payload) else {
            return nil
        }
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
        return (decoded, updatedAt)
    }

    static func deleteAllUserData(userId: String) async throws {
        guard isAvailable else { return }
        let docs = try await db.collection("users").document(userId).collection("mealPlan").getDocuments()
        for document in docs.documents {
            try await document.reference.delete()
        }
    }
}
