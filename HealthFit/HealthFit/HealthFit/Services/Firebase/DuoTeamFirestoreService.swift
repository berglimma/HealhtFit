import FirebaseFirestore
import Foundation

enum DuoTeamFirestoreError: LocalizedError {
    case unavailable
    case encodeFailed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Firebase indisponível. Não foi possível salvar a equipe no banco."
        case .encodeFailed:
            return "Falha ao preparar os dados da equipe."
        }
    }
}

enum DuoTeamFirestoreService {
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

    private static func teamsCollection() -> CollectionReference {
        db.collection("duoTeams")
    }

    private static func invitesCollection() -> CollectionReference {
        db.collection("duoInvites")
    }

    private static func membershipDoc(userId: String, teamId: String) -> DocumentReference {
        db.collection("users").document(userId).collection("duoMemberships").document(teamId)
    }

    private static func messagesCollection(teamId: String) -> CollectionReference {
        teamsCollection().document(teamId).collection("messages")
    }

    // MARK: - Teams

    /// Persiste a equipe em `duoTeams/{id}` e o vínculo em `users/{uid}/duoMemberships/{teamId}`.
    static func saveTeam(_ team: DuoTeam) async throws {
        guard isAvailable else { throw DuoTeamFirestoreError.unavailable }
        let payload = try encoder.encode(team)
        guard let json = String(data: payload, encoding: .utf8) else {
            throw DuoTeamFirestoreError.encodeFailed
        }
        let memberUids = team.members.compactMap(\.uid)
        let memberSummaries: [[String: Any]] = team.members.map { member in
            var row: [String: Any] = [
                "name": member.name,
                "joinedAt": Timestamp(date: member.joinedAt),
            ]
            if let uid = member.uid { row["uid"] = uid }
            if let country = member.countryCode { row["countryCode"] = country }
            if let photo = member.photoURL { row["photoURL"] = photo }
            if let phone = member.phoneE164 { row["phoneE164"] = phone }
            return row
        }

        var teamData: [String: Any] = [
            "payload": json,
            "name": team.name,
            "modality": team.modality.rawValue,
            "modalities": team.effectiveModalities.map(\.rawValue),
            "createdByUid": team.createdByUid,
            "createdByName": team.createdByName,
            "memberUids": memberUids,
            "memberCount": team.memberCount,
            "members": memberSummaries,
            "updatedAt": Timestamp(date: team.updatedAt),
            "createdAt": Timestamp(date: team.createdAt),
            "privacyAcknowledged": true,
        ]
        if let photoURL = team.photoURL, !photoURL.isEmpty {
            teamData["photoURL"] = photoURL
        } else {
            teamData["photoURL"] = FieldValue.delete()
        }
        try await teamsCollection().document(team.id).setData(teamData, merge: true)

        for member in team.members {
            guard let uid = member.uid else { continue }
            try await membershipDoc(userId: uid, teamId: team.id).setData([
                "teamId": team.id,
                "teamName": team.name,
                "modality": team.modality.rawValue,
                "modalities": team.effectiveModalities.map(\.rawValue),
                "createdByUid": team.createdByUid,
                "memberCount": team.memberCount,
                "updatedAt": Timestamp(date: .now),
                "joinedAt": Timestamp(date: member.joinedAt),
            ], merge: true)
        }
    }

    /// Atualiza só o documento da equipe (sem reescrever memberships de outros).
    /// Usado ao sair do grupo — evita falha de permissão após o próprio uid sair de `memberUids`.
    static func updateTeamDocumentOnly(_ team: DuoTeam) async throws {
        guard isAvailable else { throw DuoTeamFirestoreError.unavailable }
        let payload = try encoder.encode(team)
        guard let json = String(data: payload, encoding: .utf8) else {
            throw DuoTeamFirestoreError.encodeFailed
        }
        let memberUids = team.members.compactMap(\.uid)
        let memberSummaries: [[String: Any]] = team.members.map { member in
            var row: [String: Any] = [
                "name": member.name,
                "joinedAt": Timestamp(date: member.joinedAt),
            ]
            if let uid = member.uid { row["uid"] = uid }
            if let country = member.countryCode { row["countryCode"] = country }
            if let photo = member.photoURL { row["photoURL"] = photo }
            if let phone = member.phoneE164 { row["phoneE164"] = phone }
            return row
        }

        var teamData: [String: Any] = [
            "payload": json,
            "name": team.name,
            "modality": team.modality.rawValue,
            "modalities": team.effectiveModalities.map(\.rawValue),
            "createdByUid": team.createdByUid,
            "createdByName": team.createdByName,
            "memberUids": memberUids,
            "memberCount": team.memberCount,
            "members": memberSummaries,
            "updatedAt": Timestamp(date: team.updatedAt),
            "createdAt": Timestamp(date: team.createdAt),
            "privacyAcknowledged": true,
        ]
        if let photoURL = team.photoURL, !photoURL.isEmpty {
            teamData["photoURL"] = photoURL
        } else {
            teamData["photoURL"] = FieldValue.delete()
        }
        try await teamsCollection().document(team.id).setData(teamData, merge: true)
    }

    static func fetchTeam(id: String) async throws -> DuoTeam? {
        guard isAvailable else { return nil }
        let snap = try await teamsCollection().document(id).getDocument()
        guard snap.exists else { return nil }
        return decode(DuoTeam.self, from: snap.data())
    }

    static func fetchTeams(forUserId userId: String) async throws -> [DuoTeam] {
        guard isAvailable else { return [] }
        let memberships = try await db.collection("users").document(userId)
            .collection("duoMemberships")
            .getDocuments()
        var teams: [DuoTeam] = []
        for doc in memberships.documents {
            do {
                if let team = try await fetchTeam(id: doc.documentID) {
                    teams.append(team)
                }
            } catch {
                // Permissão/índice em um grupo não derruba a lista inteira.
                print("[HealthFit] DuoTeam fetch \(doc.documentID): \(error.localizedDescription)")
            }
        }
        return teams.sorted { $0.updatedAt > $1.updatedAt }
    }

    static func removeMembership(userId: String, teamId: String) async throws {
        guard isAvailable else { return }
        try await membershipDoc(userId: userId, teamId: teamId).delete()
    }

    static func deleteTeam(id: String) async throws {
        guard isAvailable else { return }
        try await teamsCollection().document(id).delete()
    }

    // MARK: - Invites

    static func saveInvite(_ invite: DuoTeamInvite) async throws {
        guard isAvailable else { return }
        let payload = try encoder.encode(invite)
        guard let json = String(data: payload, encoding: .utf8) else { return }
        let code = invite.code.uppercased()
        var data: [String: Any] = [
            "payload": json,
            "code": code,
            "teamId": invite.teamId,
            "fromUid": invite.fromUid,
            "toPhoneE164": invite.toPhoneE164,
            "status": invite.status.rawValue,
            "createdAt": Timestamp(date: invite.createdAt),
            "expiresAt": Timestamp(date: invite.expiresAt),
        ]
        if let toUid = invite.toUid {
            data["toUid"] = toUid
        }
        if let toEmail = invite.toEmail {
            data["toEmail"] = toEmail
        }
        try await invitesCollection().document(invite.id).setData(data, merge: true)
        // Índice por código — quem aceita/recusa pode não ser o fromUid; não pode falhar o aceite.
        do {
            try await db.collection("duoInviteCodes").document(code).setData([
                "inviteId": invite.id,
                "code": code,
                "teamId": invite.teamId,
                "fromUid": invite.fromUid,
                "status": invite.status.rawValue,
                "expiresAt": Timestamp(date: invite.expiresAt),
                "updatedAt": Timestamp(date: .now),
            ], merge: true)
        } catch {
            print("[HealthFit] Duo invite code index: \(error.localizedDescription)")
        }
    }

    /// Cria/atualiza só o vínculo do próprio usuário (seguro no aceite de convite).
    static func upsertOwnMembership(userId: String, team: DuoTeam) async throws {
        guard isAvailable else { throw DuoTeamFirestoreError.unavailable }
        guard let member = team.members.first(where: { $0.uid == userId }) else {
            throw DuoTeamFirestoreError.encodeFailed
        }
        try await membershipDoc(userId: userId, teamId: team.id).setData([
            "teamId": team.id,
            "teamName": team.name,
            "modality": team.modality.rawValue,
            "modalities": team.effectiveModalities.map(\.rawValue),
            "createdByUid": team.createdByUid,
            "memberCount": team.memberCount,
            "updatedAt": Timestamp(date: .now),
            "joinedAt": Timestamp(date: member.joinedAt),
        ], merge: true)
    }

    private static func pendingInviteDoc(userId: String, inviteId: String) -> DocumentReference {
        db.collection("users").document(userId).collection("duoPendingInvites").document(inviteId)
    }

    static func savePendingInvite(forUserId userId: String, invite: DuoTeamInvite) async throws {
        guard isAvailable else { return }
        let payload = try encoder.encode(invite)
        guard let json = String(data: payload, encoding: .utf8) else { return }
        try await pendingInviteDoc(userId: userId, inviteId: invite.id).setData([
            "payload": json,
            "fromUid": invite.fromUid,
            "teamId": invite.teamId,
            "teamName": invite.teamName,
            "code": invite.code.uppercased(),
            "status": invite.status.rawValue,
            "createdAt": Timestamp(date: invite.createdAt),
            "expiresAt": Timestamp(date: invite.expiresAt),
        ], merge: true)
    }

    static func fetchPendingInvites(forUserId userId: String) async throws -> [DuoTeamInvite] {
        guard isAvailable else { return [] }
        // Sem orderBy composto — evita erro de índice; ordena no cliente.
        let snap = try await db.collection("users").document(userId)
            .collection("duoPendingInvites")
            .limit(to: 40)
            .getDocuments()
        return snap.documents
            .compactMap { decode(DuoTeamInvite.self, from: $0.data()) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    static func deletePendingInvite(forUserId userId: String, inviteId: String) async throws {
        guard isAvailable else { return }
        try await pendingInviteDoc(userId: userId, inviteId: inviteId).delete()
    }

    static func fetchInvite(id: String) async throws -> DuoTeamInvite? {
        guard isAvailable else { return nil }
        let snap = try await invitesCollection().document(id).getDocument()
        return decode(DuoTeamInvite.self, from: snap.data())
    }

    static func fetchInvite(code: String) async throws -> DuoTeamInvite? {
        guard isAvailable else { return nil }
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let codeSnap = try await db.collection("duoInviteCodes").document(normalized).getDocument()
        if let inviteId = codeSnap.data()?["inviteId"] as? String,
           let invite = try await fetchInvite(id: inviteId) {
            return invite
        }
        // Fallback legado (convites antigos sem duoInviteCodes).
        let snap = try await invitesCollection()
            .whereField("code", isEqualTo: normalized)
            .whereField("status", isEqualTo: DuoInviteStatus.pending.rawValue)
            .limit(to: 1)
            .getDocuments()
        return decode(DuoTeamInvite.self, from: snap.documents.first?.data())
    }

    static func saveJoinAccess(forUserId userId: String, teamId: String, invite: DuoTeamInvite) async throws {
        guard isAvailable else { return }
        try await db.collection("users").document(userId)
            .collection("duoJoinAccess").document(teamId)
            .setData([
                "teamId": teamId,
                "inviteId": invite.id,
                "fromUid": invite.fromUid,
                "code": invite.code.uppercased(),
                "expiresAt": Timestamp(date: invite.expiresAt),
                "createdAt": Timestamp(date: .now),
            ], merge: true)
    }

    static func deleteJoinAccess(forUserId userId: String, teamId: String) async throws {
        guard isAvailable else { return }
        try await db.collection("users").document(userId)
            .collection("duoJoinAccess").document(teamId)
            .delete()
    }

    static func fetchInvitesSent(byUserId userId: String) async throws -> [DuoTeamInvite] {
        guard isAvailable else { return [] }
        // where + orderBy exige índice composto; ordenamos no app.
        let snap = try await invitesCollection()
            .whereField("fromUid", isEqualTo: userId)
            .limit(to: 40)
            .getDocuments()
        return snap.documents
            .compactMap { decode(DuoTeamInvite.self, from: $0.data()) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Inbox notifications (adicionado ao grupo, etc.)

    private static func notificationDoc(userId: String, id: String) -> DocumentReference {
        db.collection("users").document(userId).collection("duoNotifications").document(id)
    }

    static func saveInboxNotification(
        forUserId userId: String,
        notification: DuoInboxNotification
    ) async throws {
        guard isAvailable else { return }
        let payload = try encoder.encode(notification)
        guard let json = String(data: payload, encoding: .utf8) else { return }
        try await notificationDoc(userId: userId, id: notification.id).setData([
            "payload": json,
            "fromUid": notification.fromUid,
            "teamId": notification.teamId,
            "kind": notification.kind,
            "delivered": notification.delivered,
            "createdAt": Timestamp(date: notification.createdAt),
        ], merge: true)
    }

    static func fetchUndeliveredNotifications(forUserId userId: String) async throws -> [DuoInboxNotification] {
        guard isAvailable else { return [] }
        let snap = try await db.collection("users").document(userId)
            .collection("duoNotifications")
            .whereField("delivered", isEqualTo: false)
            .limit(to: 30)
            .getDocuments()
        return snap.documents
            .compactMap { decode(DuoInboxNotification.self, from: $0.data()) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    static func markNotificationDelivered(forUserId userId: String, id: String) async throws {
        guard isAvailable else { return }
        if var note = try await fetchNotification(userId: userId, id: id) {
            note.delivered = true
            try await saveInboxNotification(forUserId: userId, notification: note)
        } else {
            try await notificationDoc(userId: userId, id: id).setData([
                "delivered": true,
            ], merge: true)
        }
    }

    private static func fetchNotification(userId: String, id: String) async throws -> DuoInboxNotification? {
        let snap = try await notificationDoc(userId: userId, id: id).getDocument()
        return decode(DuoInboxNotification.self, from: snap.data())
    }

    static func listenInboxNotifications(
        userId: String,
        onChange: @escaping @Sendable ([DuoInboxNotification]) -> Void
    ) -> ListenerRegistration? {
        guard isAvailable else { return nil }
        return db.collection("users").document(userId)
            .collection("duoNotifications")
            .whereField("delivered", isEqualTo: false)
            .limit(to: 30)
            .addSnapshotListener { snapshot, _ in
                let notes = snapshot?.documents.compactMap {
                    decode(DuoInboxNotification.self, from: $0.data())
                } ?? []
                onChange(notes)
            }
    }

    // MARK: - Messages

    static func saveMessage(_ message: DuoChatMessage) async throws {
        guard isAvailable else { return }
        let payload = try encoder.encode(message)
        guard let json = String(data: payload, encoding: .utf8) else { return }
        try await messagesCollection(teamId: message.teamId).document(message.id).setData([
            "payload": json,
            "senderUid": message.senderUid,
            "createdAt": Timestamp(date: message.createdAt),
            "kind": message.kind.rawValue,
        ], merge: true)
        try await teamsCollection().document(message.teamId).setData([
            "updatedAt": Timestamp(date: .now),
        ], merge: true)
    }

    static func fetchMessages(teamId: String, limit: Int = 80) async throws -> [DuoChatMessage] {
        guard isAvailable else { return [] }
        let snap = try await messagesCollection(teamId: teamId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return snap.documents
            .compactMap { decode(DuoChatMessage.self, from: $0.data()) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    static func listenMessages(
        teamId: String,
        onChange: @escaping @Sendable ([DuoChatMessage]) -> Void
    ) -> ListenerRegistration? {
        guard isAvailable else { return nil }
        return messagesCollection(teamId: teamId)
            .order(by: "createdAt", descending: false)
            .limit(to: 80)
            .addSnapshotListener { snapshot, _ in
                let messages = snapshot?.documents.compactMap { decode(DuoChatMessage.self, from: $0.data()) } ?? []
                onChange(messages)
            }
    }

    // MARK: - Performance / ranking

    private static func statsCollection(teamId: String) -> CollectionReference {
        teamsCollection().document(teamId).collection("memberStats")
    }

    static func saveMemberPerformance(_ stats: DuoMemberPerformance, teamId: String) async throws {
        guard isAvailable else { return }
        let payload = try encoder.encode(stats)
        guard let json = String(data: payload, encoding: .utf8) else { return }
        try await statsCollection(teamId: teamId).document(stats.uid).setData([
            "payload": json,
            "uid": stats.uid,
            "displayName": stats.displayName,
            "rankingScore7d": stats.rankingScore7d,
            "sessionsLast7Days": stats.sessionsLast7Days,
            "updatedAt": Timestamp(date: stats.updatedAt),
        ], merge: true)
    }

    static func fetchMemberPerformances(teamId: String) async throws -> [DuoMemberPerformance] {
        guard isAvailable else { return [] }
        let snap = try await statsCollection(teamId: teamId).getDocuments()
        return snap.documents.compactMap { decode(DuoMemberPerformance.self, from: $0.data()) }
    }

    static func deleteMemberPerformance(teamId: String, userId: String) async throws {
        guard isAvailable else { return }
        try await statsCollection(teamId: teamId).document(userId).delete()
    }

    static func deleteMessages(teamId: String, messageIds: [String]) async throws {
        guard isAvailable, !messageIds.isEmpty else { return }
        let batch = db.batch()
        for id in messageIds {
            batch.deleteDocument(messagesCollection(teamId: teamId).document(id))
        }
        try await batch.commit()
    }

    static func deleteAllUserData(userId: String) async throws {
        guard isAvailable else { return }
        let memberships = try await db.collection("users").document(userId)
            .collection("duoMemberships")
            .getDocuments()
        for doc in memberships.documents {
            try await doc.reference.delete()
        }
        let pending = try await db.collection("users").document(userId)
            .collection("duoPendingInvites")
            .getDocuments()
        for doc in pending.documents {
            try await doc.reference.delete()
        }
        let notifications = try await db.collection("users").document(userId)
            .collection("duoNotifications")
            .getDocuments()
        for doc in notifications.documents {
            try await doc.reference.delete()
        }
        let sent = try await invitesCollection().whereField("fromUid", isEqualTo: userId).getDocuments()
        for doc in sent.documents {
            try await doc.reference.delete()
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: [String: Any]?) -> T? {
        guard let data,
              let json = data["payload"] as? String,
              let payload = json.data(using: .utf8) else { return nil }
        return try? decoder.decode(T.self, from: payload)
    }
}
