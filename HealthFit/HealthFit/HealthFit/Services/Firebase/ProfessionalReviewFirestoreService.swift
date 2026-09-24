import FirebaseFirestore
import FirebaseStorage
import Foundation
import UIKit

enum ProfessionalReviewFirestoreService {
    private static var db: Firestore { Firestore.firestore() }
    private static var storage: Storage { Storage.storage() }

    static var isAvailable: Bool { FirebaseBootstrap.isConfigured }

    private static func reviewDoc(linkId: String) -> DocumentReference {
        db.collection("coachLinks").document(linkId).collection("professionalReview").document("current")
    }

    private static func dailyPhotos(linkId: String) -> CollectionReference {
        db.collection("coachLinks").document(linkId).collection("dailyMealPhotos")
    }

    // MARK: - Review snapshot

    static func publishReview(_ snapshot: ProfessionalReviewSnapshot) async throws {
        guard isAvailable else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        guard let json = String(data: data, encoding: .utf8) else { return }
        try await reviewDoc(linkId: snapshot.linkId).setData([
            "payload": json,
            "studentUid": snapshot.studentUid,
            "generatedAt": Timestamp(date: snapshot.generatedAt),
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    static func fetchReview(linkId: String) async throws -> ProfessionalReviewSnapshot? {
        guard isAvailable else { return nil }
        let snap = try await reviewDoc(linkId: linkId).getDocument()
        guard let json = snap.data()?["payload"] as? String,
              let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ProfessionalReviewSnapshot.self, from: data)
    }

    static func listenReview(
        linkId: String,
        handler: @escaping (ProfessionalReviewSnapshot?) -> Void
    ) -> ListenerRegistration? {
        guard isAvailable else { return nil }
        return reviewDoc(linkId: linkId).addSnapshotListener { snap, _ in
            guard let json = snap?.data()?["payload"] as? String,
                  let data = json.data(using: .utf8) else {
                handler(nil)
                return
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            handler(try? decoder.decode(ProfessionalReviewSnapshot.self, from: data))
        }
    }

    // MARK: - Daily meal photo (view once)

    static func publishDailyMealPhoto(
        link: CoachLink,
        image: UIImage,
        mealLabel: String,
        note: String
    ) async throws -> DailyMealPhotoShare {
        guard isAvailable else { throw CoachFirestoreError.unavailable }
        let dayKey = DailyMealPhotoShare.dayKey()
        let id = UUID().uuidString
        let path = "coachLinks/\(link.id)/dailyMealPhotos/\(dayKey)/\(id).jpg"
        let ref = storage.reference().child(path)
        guard let jpeg = image.jpegData(compressionQuality: 0.72) else {
            throw CoachFirestoreError.unavailable
        }
        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"
        _ = try await putData(jpeg, to: ref, metadata: meta)
        let url = try await ref.downloadURL()

        let share = DailyMealPhotoShare(
            id: id,
            linkId: link.id,
            studentUid: link.studentUid,
            studentName: link.studentName,
            dayKey: dayKey,
            mealLabel: mealLabel.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            storagePath: path,
            downloadURL: url.absoluteString,
            createdAt: .now,
            viewedAt: nil,
            viewedByUid: nil
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payload = try encoder.encode(share)
        guard let json = String(data: payload, encoding: .utf8) else { return share }
        try await dailyPhotos(linkId: link.id).document(id).setData([
            "payload": json,
            "dayKey": dayKey,
            "createdAt": Timestamp(date: share.createdAt),
            "viewedAt": NSNull()
        ])
        return share
    }

    static func listenTodayPhotos(
        linkId: String,
        dayKey: String = DailyMealPhotoShare.dayKey(),
        handler: @escaping ([DailyMealPhotoShare]) -> Void
    ) -> ListenerRegistration? {
        guard isAvailable else { return nil }
        return dailyPhotos(linkId: linkId)
            .whereField("dayKey", isEqualTo: dayKey)
            .addSnapshotListener { snap, _ in
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let items = (snap?.documents ?? []).compactMap { doc -> DailyMealPhotoShare? in
                    guard let json = doc.data()["payload"] as? String,
                          let data = json.data(using: .utf8),
                          var item = try? decoder.decode(DailyMealPhotoShare.self, from: data)
                    else { return nil }
                    item.id = doc.documentID
                    return item.isViewed ? nil : item
                }
                .sorted { $0.createdAt > $1.createdAt }
                handler(items)
            }
    }

    /// Marca como vista e apaga Storage + documento (uso único pelo nutricionista).
    static func markPhotoViewedAndDelete(_ photo: DailyMealPhotoShare, viewerUid: String) async throws {
        guard isAvailable else { return }
        try? await storage.reference().child(photo.storagePath).delete()
        try await dailyPhotos(linkId: photo.linkId).document(photo.id).delete()
    }

    private static func putData(
        _ data: Data,
        to reference: StorageReference,
        metadata: StorageMetadata
    ) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            reference.putData(data, metadata: metadata) { _, error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume()
                }
            }
        }
    }
}
