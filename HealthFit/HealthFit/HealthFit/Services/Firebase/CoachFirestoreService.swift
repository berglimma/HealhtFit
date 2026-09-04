import FirebaseAuth
import FirebaseFirestore
import Foundation

enum CoachFirestoreError: LocalizedError {
    case unavailable
    case notSignedIn
    case encodeFailed
    case notFound
    case limitReached
    case invalid

    var errorDescription: String? {
        switch self {
        case .unavailable: return "Firebase indisponível para o HealthFit Coach."
        case .notSignedIn: return "Entre na sua conta para usar o Coach."
        case .encodeFailed: return "Falha ao preparar os dados do Coach."
        case .notFound: return "Registro do Coach não encontrado."
        case .limitReached: return "Limite de alunos do profissional atingido."
        case .invalid: return "Dados inválidos para o Coach."
        }
    }
}

enum CoachFirestoreService {
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

    // MARK: - Paths

    private static func profiles() -> CollectionReference { db.collection("coachProfiles") }
    private static func links() -> CollectionReference { db.collection("coachLinks") }
    private static func invites() -> CollectionReference { db.collection("coachInvites") }
    private static func inviteCodes() -> CollectionReference { db.collection("coachInviteCodes") }

    private static func membership(uid: String, linkId: String) -> DocumentReference {
        db.collection("users").document(uid).collection("coachMemberships").document(linkId)
    }

    private static func assignedWorkouts(linkId: String) -> CollectionReference {
        links().document(linkId).collection("assignedWorkouts")
    }

    private static func messages(linkId: String) -> CollectionReference {
        links().document(linkId).collection("messages")
    }

    private static func mealPlanDoc(linkId: String) -> DocumentReference {
        links().document(linkId).collection("mealPlan").document("current")
    }

    // MARK: - Encode helpers

    private static func encode<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try encoder.encode(value)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CoachFirestoreError.encodeFailed
        }
        return json
    }

    /// Firestore devolve `Timestamp` e outros tipos não-JSON. Serializar direto causa SIGABRT.
    private static func sanitizeForJSON(_ value: Any) -> Any? {
        switch value {
        case is NSNull:
            return NSNull()
        case let timestamp as Timestamp:
            return ISO8601DateFormatter().string(from: timestamp.dateValue())
        case let date as Date:
            return ISO8601DateFormatter().string(from: date)
        case let dict as [String: Any]:
            return sanitizeDictionary(dict)
        case let array as [Any]:
            return array.compactMap { sanitizeForJSON($0) }
        case let number as NSNumber:
            return number
        case is String:
            return value
        default:
            return nil
        }
    }

    private static func sanitizeDictionary(_ data: [String: Any]) -> [String: Any] {
        var clean: [String: Any] = [:]
        clean.reserveCapacity(data.count)
        for (key, value) in data {
            if let converted = sanitizeForJSON(value) {
                clean[key] = converted
            }
        }
        return clean
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: [String: Any]) throws -> T {
        let clean = sanitizeDictionary(data)
        guard JSONSerialization.isValidJSONObject(clean) else {
            throw CoachFirestoreError.encodeFailed
        }
        let json = try JSONSerialization.data(withJSONObject: clean)
        return try decoder.decode(type, from: json)
    }

    // MARK: - Profile

    static func saveProfile(_ profile: CoachProfessionalProfile) async throws {
        guard isAvailable else { throw CoachFirestoreError.unavailable }
        guard let authUid = Auth.auth().currentUser?.uid, !authUid.isEmpty else {
            throw CoachFirestoreError.notSignedIn
        }
        // Doc ID e campo uid devem ser o Auth UID — senão as rules negam (permission-denied).
        var toSave = profile
        toSave.uid = authUid
        var payload = try encode(toSave)
        payload["uid"] = authUid
        // Timestamp nativo (não FieldValue) evita misturar tipos e facilita o decode.
        payload["updatedAt"] = Timestamp(date: .now)
        if payload["createdAt"] == nil {
            payload["createdAt"] = Timestamp(date: toSave.createdAt)
        }
        try await profiles().document(authUid).setData(payload, merge: true)
    }

    static func fetchProfile(uid: String) async throws -> CoachProfessionalProfile? {
        guard isAvailable else { throw CoachFirestoreError.unavailable }
        let snap = try await profiles().document(uid).getDocument()
        guard let data = snap.data() else { return nil }
        return try? decode(CoachProfessionalProfile.self, from: data)
    }

    static func searchDirectory(
        name: String? = nil,
        city: String?,
        stateCode: String?,
        profession: CoachProfession?
    ) async throws -> [CoachProfessionalProfile] {
        guard isAvailable else { throw CoachFirestoreError.unavailable }
        var query: Query = profiles().whereField("isDirectoryVisible", isEqualTo: true)
        if let stateCode, !stateCode.isEmpty {
            query = query.whereField("stateCode", isEqualTo: stateCode.uppercased())
        }
        let limit = (name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? 80 : 40
        let snap = try await query.limit(to: limit).getDocuments()
        var results = snap.documents.compactMap { try? decode(CoachProfessionalProfile.self, from: $0.data()) }
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let needle = name.trimmingCharacters(in: .whitespacesAndNewlines)
            results = results.filter { $0.displayName.localizedCaseInsensitiveContains(needle) }
        }
        if let city, !city.isEmpty {
            let needle = city.lowercased()
            results = results.filter { $0.city.lowercased().contains(needle) }
        }
        if let profession {
            results = results.filter { $0.professions.contains(profession) }
        }
        return results.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    // MARK: - Invites & links

    static func createInvite(_ invite: CoachInvite) async throws {
        guard isAvailable else { throw CoachFirestoreError.unavailable }
        let payload = try encode(invite)
        try await invites().document(invite.id).setData(payload)
        try await inviteCodes().document(invite.code).setData([
            "inviteId": invite.id,
            "fromUid": invite.fromUid,
            "status": invite.status.rawValue,
            "profession": invite.profession.rawValue,
            "expiresAt": Timestamp(date: invite.expiresAt),
        ])
    }

    static func fetchInvite(code: String) async throws -> CoachInvite? {
        guard isAvailable else { throw CoachFirestoreError.unavailable }
        let codeSnap = try await inviteCodes().document(code.uppercased()).getDocument()
        guard let inviteId = codeSnap.data()?["inviteId"] as? String else { return nil }
        let snap = try await invites().document(inviteId).getDocument()
        guard let data = snap.data() else { return nil }
        return try? decode(CoachInvite.self, from: data)
    }

    static func saveLink(_ link: CoachLink) async throws {
        guard isAvailable else { throw CoachFirestoreError.unavailable }
        let payload = try encode(link)
        try await links().document(link.id).setData(payload, merge: true)
        let membershipPayload: [String: Any] = [
            "linkId": link.id,
            "coachUid": link.coachUid,
            "studentUid": link.studentUid,
            "profession": link.profession.rawValue,
            "status": link.status.rawValue,
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        try await membership(uid: link.coachUid, linkId: link.id).setData(membershipPayload, merge: true)
        try await membership(uid: link.studentUid, linkId: link.id).setData(membershipPayload, merge: true)
    }

    static func updateInviteStatus(
        inviteId: String,
        status: CoachInviteStatus,
        linkId: String?,
        code: String?
    ) async throws {
        guard isAvailable else { throw CoachFirestoreError.unavailable }
        var data: [String: Any] = ["status": status.rawValue]
        if let linkId { data["linkId"] = linkId }
        try await invites().document(inviteId).setData(data, merge: true)
        // Mantém o lookup por código alinhado (rules só permitem pending → accepted/…).
        if let code {
            let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !normalized.isEmpty else { return }
            var codeData: [String: Any] = ["status": status.rawValue]
            if let linkId { codeData["linkId"] = linkId }
            try await inviteCodes().document(normalized).setData(codeData, merge: true)
        }
    }

    static func listenMemberships(
        uid: String,
        handler: @escaping ([QueryDocumentSnapshot]) -> Void
    ) -> ListenerRegistration? {
        guard isAvailable else { return nil }
        return db.collection("users").document(uid).collection("coachMemberships")
            .addSnapshotListener { snap, _ in
                handler(snap?.documents ?? [])
            }
    }

    static func fetchLink(id: String) async throws -> CoachLink? {
        guard isAvailable else { throw CoachFirestoreError.unavailable }
        let snap = try await links().document(id).getDocument()
        guard let data = snap.data() else { return nil }
        return try? decode(CoachLink.self, from: data)
    }

    static func listenLink(
        id: String,
        handler: @escaping (CoachLink?) -> Void
    ) -> ListenerRegistration? {
        guard isAvailable else { return nil }
        return links().document(id).addSnapshotListener { snap, _ in
            guard let data = snap?.data() else {
                handler(nil)
                return
            }
            handler(try? decode(CoachLink.self, from: data))
        }
    }

    // MARK: - Assigned workouts

    static func publishWorkout(_ assignment: CoachAssignedWorkout) async throws {
        guard isAvailable else { throw CoachFirestoreError.unavailable }
        let payload = try encode(assignment)
        try await assignedWorkouts(linkId: assignment.linkId).document(assignment.id).setData(payload, merge: true)
    }

    static func listenAssignedWorkouts(
        linkId: String,
        handler: @escaping ([CoachAssignedWorkout]) -> Void
    ) -> ListenerRegistration? {
        guard isAvailable else { return nil }
        return assignedWorkouts(linkId: linkId)
            .whereField("isActive", isEqualTo: true)
            .addSnapshotListener { snap, _ in
                let items = (snap?.documents ?? []).compactMap { try? decode(CoachAssignedWorkout.self, from: $0.data()) }
                handler(items.sorted { $0.updatedAt > $1.updatedAt })
            }
    }

    // MARK: - Meal plan

    static func publishMealPlan(linkId: String, planJSON: [String: Any], coachUid: String, coachName: String) async throws {
        guard isAvailable else { throw CoachFirestoreError.unavailable }
        var payload = planJSON
        payload["coachUid"] = coachUid
        payload["coachName"] = coachName
        payload["updatedAt"] = FieldValue.serverTimestamp()
        payload["linkId"] = linkId
        try await mealPlanDoc(linkId: linkId).setData(payload, merge: true)
    }

    static func listenMealPlan(
        linkId: String,
        handler: @escaping ([String: Any]?) -> Void
    ) -> ListenerRegistration? {
        guard isAvailable else { return nil }
        return mealPlanDoc(linkId: linkId).addSnapshotListener { snap, _ in
            handler(snap?.data())
        }
    }

    // MARK: - Chat

    static func sendMessage(_ message: CoachChatMessage) async throws {
        guard isAvailable else { throw CoachFirestoreError.unavailable }
        var payload = try encode(message)
        // Campos explícitos para a Cloud Function de push.
        payload["senderUid"] = message.senderUid
        payload["senderName"] = message.senderName
        payload["text"] = message.text
        payload["linkId"] = message.linkId
        payload["createdAt"] = Timestamp(date: message.createdAt)
        try await messages(linkId: message.linkId).document(message.id).setData(payload, merge: true)
    }

    static func updateMessageReceipt(
        linkId: String,
        messageId: String,
        deliveredAt: Date? = nil,
        readAt: Date? = nil
    ) async throws {
        guard isAvailable else { throw CoachFirestoreError.unavailable }
        var patch: [String: Any] = [:]
        if let deliveredAt {
            patch["deliveredAt"] = Timestamp(date: deliveredAt)
        }
        if let readAt {
            patch["readAt"] = Timestamp(date: readAt)
        }
        guard !patch.isEmpty else { return }
        try await messages(linkId: linkId).document(messageId).setData(patch, merge: true)
    }

    static func listenMessages(
        linkId: String,
        handler: @escaping ([CoachChatMessage]) -> Void
    ) -> ListenerRegistration? {
        guard isAvailable else { return nil }
        return messages(linkId: linkId)
            .order(by: "createdAt", descending: false)
            .limit(toLast: 100)
            .addSnapshotListener { snap, _ in
                let items = (snap?.documents ?? []).compactMap { try? decode(CoachChatMessage.self, from: $0.data()) }
                handler(items)
            }
    }
}
