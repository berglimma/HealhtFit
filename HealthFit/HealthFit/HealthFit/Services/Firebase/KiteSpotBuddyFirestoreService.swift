import FirebaseAuth
import FirebaseFirestore
import Foundation

enum KiteSpotBuddyFirestoreError: LocalizedError {
    case unavailable
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Firebase indisponível para o Kite Spot Buddy."
        case .notSignedIn:
            return "Entre na sua conta para usar o Kite Spot Buddy."
        }
    }
}

enum KiteSpotBuddyFirestoreService {
    private static let collectionName = "kiteSpotPresence"
    private static let presenceTTL: TimeInterval = 30 * 60

    private static var db: Firestore { Firestore.firestore() }

    static var isAvailable: Bool { FirebaseBootstrap.isConfigured }

    private static func doc(_ uid: String) -> DocumentReference {
        db.collection(collectionName).document(uid)
    }

    static func upsertPresence(
        uid: String,
        displayName: String,
        photoURL: String?,
        latitude: Double,
        longitude: Double,
        sessionId: String,
        needsHelp: Bool
    ) async throws {
        guard isAvailable else { throw KiteSpotBuddyFirestoreError.unavailable }
        let expiresAt = Date().addingTimeInterval(presenceTTL)
        var payload: [String: Any] = [
            "uid": uid,
            "displayName": String(displayName.prefix(80)),
            "latitude": latitude,
            "longitude": longitude,
            "sessionId": sessionId,
            "visible": true,
            "isKitesurf": true,
            "needsHelp": needsHelp,
            "updatedAt": FieldValue.serverTimestamp(),
            "expiresAt": Timestamp(date: expiresAt),
        ]
        if let photoURL, !photoURL.isEmpty {
            payload["photoURL"] = photoURL
        } else {
            payload["photoURL"] = FieldValue.delete()
        }
        if needsHelp {
            payload["helpRequestedAt"] = FieldValue.serverTimestamp()
        } else {
            payload["helpRequestedAt"] = FieldValue.delete()
        }
        try await doc(uid).setData(payload, merge: true)
    }

    static func setNeedsHelp(uid: String, needsHelp: Bool) async throws {
        guard isAvailable else { throw KiteSpotBuddyFirestoreError.unavailable }
        var payload: [String: Any] = [
            "needsHelp": needsHelp,
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        if needsHelp {
            payload["helpRequestedAt"] = FieldValue.serverTimestamp()
        } else {
            payload["helpRequestedAt"] = FieldValue.delete()
        }
        try await doc(uid).setData(payload, merge: true)
    }

    static func deletePresence(uid: String) async {
        guard isAvailable else { return }
        try? await doc(uid).delete()
    }

    static func listenVisiblePresence(
        handler: @escaping ([QueryDocumentSnapshot]) -> Void
    ) -> ListenerRegistration? {
        guard isAvailable else { return nil }
        return db.collection(collectionName)
            .whereField("visible", isEqualTo: true)
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                handler(docs)
            }
    }

    static func parsePresence(_ data: [String: Any], documentId: String) -> KiteSpotBuddyPresence? {
        let uid = (data["uid"] as? String) ?? documentId
        guard let latitude = data["latitude"] as? Double ?? (data["latitude"] as? NSNumber)?.doubleValue,
              let longitude = data["longitude"] as? Double ?? (data["longitude"] as? NSNumber)?.doubleValue,
              let sessionId = data["sessionId"] as? String else {
            return nil
        }
        let displayName = (data["displayName"] as? String) ?? "Amigo"
        let photoURL = data["photoURL"] as? String
        let needsHelp = (data["needsHelp"] as? Bool)
            ?? ((data["needsHelp"] as? NSNumber)?.boolValue ?? false)
        let helpAt = (data["helpRequestedAt"] as? Timestamp)?.dateValue()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
        let expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue() ?? .distantFuture
        guard expiresAt > Date() else { return nil }
        return KiteSpotBuddyPresence(
            uid: uid,
            displayName: displayName,
            photoURL: photoURL,
            latitude: latitude,
            longitude: longitude,
            needsHelp: needsHelp,
            helpRequestedAt: helpAt,
            sessionId: sessionId,
            updatedAt: updatedAt
        )
    }
}
