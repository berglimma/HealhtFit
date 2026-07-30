import FirebaseFirestore
import Foundation

enum BodyEvolutionFirestoreService {
    static let maxStoredEvaluations = BodyEvolutionEvaluation.maxRetainedEvaluations

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

    private static func evaluationsCollection(userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("bodyEvolutionEvaluations")
    }

    private static func metaDocument(userId: String) -> DocumentReference {
        db.collection("users").document(userId).collection("bodyEvolutionMeta").document("state")
    }

    static func saveMeta(_ meta: BodyEvolutionMeta, userId: String) async throws {
        guard isAvailable else { return }
        let payload = try encoder.encode(meta)
        guard let json = String(data: payload, encoding: .utf8) else { return }

        var data: [String: Any] = [
            "payload": json,
            "updatedAt": Timestamp(date: .now),
            "hasActivePhotoSet": meta.activePhotoSet?.hasAnyPhoto == true,
        ]
        if let set = meta.activePhotoSet {
            data["activePhotoSetId"] = set.id
            data["comparisonEligibleAt"] = Timestamp(date: set.comparisonEligibleAt)
        }
        if let lastEvaluationAt = meta.lastEvaluationAt {
            data["lastEvaluationAt"] = Timestamp(date: lastEvaluationAt)
        }

        try await metaDocument(userId: userId).setData(data, merge: true)
    }

    static func fetchMeta(userId: String) async throws -> BodyEvolutionMeta? {
        guard isAvailable else { return nil }
        let snapshot = try await metaDocument(userId: userId).getDocument()
        guard let data = snapshot.data(),
              let json = data["payload"] as? String,
              let payload = json.data(using: .utf8) else {
            return nil
        }
        return try? decoder.decode(BodyEvolutionMeta.self, from: payload)
    }

    static func saveEvaluation(_ evaluation: BodyEvolutionEvaluation, userId: String) async throws {
        guard isAvailable else { return }
        let payload = try encoder.encode(evaluation)
        guard let json = String(data: payload, encoding: .utf8) else { return }

        try await evaluationsCollection(userId: userId).document(evaluation.id).setData([
            "payload": json,
            "createdAt": Timestamp(date: evaluation.createdAt),
            "periodDays": evaluation.periodDays,
            "summaryText": evaluation.summaryText,
            "updatedAt": Timestamp(date: .now),
        ].merging(
            evaluation.pdfStoragePath.map { ["pdfStoragePath": $0] } ?? [:]
        ) { _, new in new })

        try await trimEvaluations(userId: userId)
    }

    static func fetchEvaluations(userId: String) async throws -> [BodyEvolutionEvaluation] {
        guard isAvailable else { return [] }
        let snapshot = try await evaluationsCollection(userId: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: maxStoredEvaluations)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            guard let json = document.data()["payload"] as? String,
                  let payload = json.data(using: .utf8) else {
                return nil
            }
            return try? decoder.decode(BodyEvolutionEvaluation.self, from: payload)
        }
    }

    /// Remove avaliações excedentes e retorna os `pdfStoragePath` que devem ser apagados do Storage.
    @discardableResult
    static func trimEvaluations(userId: String) async throws -> [String] {
        guard isAvailable else { return [] }
        let snapshot = try await evaluationsCollection(userId: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        guard snapshot.documents.count > maxStoredEvaluations else { return [] }

        var removedPDFPaths: [String] = []
        for document in snapshot.documents.dropFirst(maxStoredEvaluations) {
            if let path = document.data()["pdfStoragePath"] as? String, !path.isEmpty {
                removedPDFPaths.append(path)
            }
            try await document.reference.delete()
        }
        return removedPDFPaths
    }
}
