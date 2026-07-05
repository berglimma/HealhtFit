import FirebaseFirestore
import Foundation

struct ExerciseVideoRecord: Codable, Equatable {
    let exerciseName: String
    let title: String
    let keywords: [String]
    let muscleGroup: String
    let storagePath: String

    var documentID: String {
        Self.slug(for: exerciseName)
    }

    var demoVideo: ExerciseDemoVideo {
        ExerciseDemoVideo(
            exerciseName: exerciseName,
            title: title,
            storagePath: storagePath
        )
    }

    static func slug(for exerciseName: String) -> String {
        exerciseName
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }
}

enum ExerciseVideoFirestoreService {
    private static var db: Firestore { Firestore.firestore() }

    private static var collection: CollectionReference {
        db.collection("exerciseVideos")
    }

    static var isAvailable: Bool {
        FirebaseBootstrap.isConfigured
    }

    static func syncCatalog() async -> ExerciseVideoUploadSummary {
        guard isAvailable else {
            return ExerciseVideoUploadSummary(uploaded: 0, skipped: 0, failed: 0, missingLocal: 0)
        }

        let summary = await ExerciseVideoStorageService.uploadBundledVideosIfNeeded(force: false)
        await syncFirestoreCatalog()
        return summary
    }

    static func syncFirestoreCatalog() async {
        guard isAvailable else { return }

        do {
            let records = ExerciseVideoCatalog.seedRecords()
            let batch = db.batch()

            for record in records {
                let document = collection.document(record.documentID)
                batch.setData([
                    "exerciseName": record.exerciseName,
                    "title": record.title,
                    "keywords": record.keywords,
                    "muscleGroup": record.muscleGroup,
                    "storagePath": record.storagePath,
                    "updatedAt": Timestamp(date: .now),
                ], forDocument: document, merge: true)
            }

            try await batch.commit()
        } catch {
            print("[HealthFit] Falha ao sincronizar vídeos no Firestore: \(error.localizedDescription)")
        }
    }

    static func fetchAllVideos() async throws -> [ExerciseVideoRecord] {
        guard isAvailable else { return [] }

        let snapshot = try await collection.getDocuments()
        return snapshot.documents.compactMap(decodeRecord)
    }

    private static func decodeRecord(from document: QueryDocumentSnapshot) -> ExerciseVideoRecord? {
        decodeRecord(from: document.data())
    }

    private static func decodeRecord(from data: [String: Any]) -> ExerciseVideoRecord? {
        guard let exerciseName = data["exerciseName"] as? String,
              let title = data["title"] as? String else {
            return nil
        }

        let muscleGroup = data["muscleGroup"] as? String ?? MuscleGroup.fullBody.rawValue
        let storagePath = data["storagePath"] as? String
            ?? ExerciseVideoStorageService.storagePath(
                for: exerciseName,
                muscleGroup: MuscleGroup.allCases.first { $0.rawValue == muscleGroup } ?? .fullBody
            )

        return ExerciseVideoRecord(
            exerciseName: exerciseName,
            title: title,
            keywords: data["keywords"] as? [String] ?? [],
            muscleGroup: muscleGroup,
            storagePath: storagePath
        )
    }
}
