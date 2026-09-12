import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Foundation
import UIKit

/// Backend do Pulse: metadados em Firestore + mídia opcional no Storage.
/// Só envia/lê se `isCloudSyncEffective` (Labs local ou `pulseCloudSyncEnabled` remoto; default OFF).
/// Sempre pull-based (`getDocuments` / `getDocument`) — nunca `addSnapshotListener`.
enum PulseFirestoreService {
    static var isAvailable: Bool { FirebaseBootstrap.isConfigured }

    private static var db: Firestore { Firestore.firestore() }
    private static var storage: Storage { Storage.storage() }

    private static func posts() -> CollectionReference { db.collection("pulsePosts") }
    private static func reports() -> CollectionReference { db.collection("pulseReports") }
    private static func profiles() -> CollectionReference { db.collection("pulseProfiles") }
    private static func follows() -> CollectionReference { db.collection("pulseFollows") }
    private static func stories() -> CollectionReference { db.collection("pulseStories") }
    private static func blocks() -> CollectionReference { db.collection("pulseBlocks") }

    private static func reactions(postId: String) -> CollectionReference {
        posts().document(postId).collection("reactions")
    }

    private static func comments(postId: String) -> CollectionReference {
        posts().document(postId).collection("comments")
    }

    // MARK: - Publish posts

    @discardableResult
    static func upsertPost(_ post: PulsePost, imageJPEG: Data? = nil) async -> String? {
        guard PulseExperimental.isCloudSyncEffective, isAvailable else { return nil }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return nil }
        guard post.authorId == uid || post.authorId == "local" else { return nil }

        var remoteURL = post.remoteMediaURL
        if let imageJPEG {
            remoteURL = (try? await uploadJPEG(data: imageJPEG, userId: uid, fileId: post.id))?.absoluteString ?? remoteURL
        }

        var payload = firestorePayload(for: post, authorId: uid, remoteMediaURL: remoteURL)
        payload["updatedAt"] = FieldValue.serverTimestamp()

        do {
            try await posts().document(post.id.uuidString).setData(payload, merge: true)
            return remoteURL
        } catch {
            print("[Pulse] Falha ao gravar post na nuvem: \(error.localizedDescription)")
            return nil
        }
    }

    static func deletePost(id: UUID) async {
        guard PulseExperimental.isCloudSyncEffective, isAvailable else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let snap = try await posts().document(id.uuidString).getDocument()
            guard snap.data()?["authorId"] as? String == uid else { return }
            try await posts().document(id.uuidString).delete()
            try? await storage.reference(withPath: mediaPath(userId: uid, fileId: id)).delete()
        } catch {
            print("[Pulse] Falha ao apagar post remoto: \(error.localizedDescription)")
        }
    }

    static func reportPost(postId: UUID, reporterId: String, reason: String = "user_report") async {
        guard PulseExperimental.isCloudSyncEffective, isAvailable else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        // Sempre o UID autenticado — alinhado às security rules.
        _ = reporterId
        try? await reports().document().setData([
            "postId": postId.uuidString,
            "reporterId": uid,
            "reason": reason,
            "createdAt": FieldValue.serverTimestamp(),
            "appVersion": AppInfo.appVersion,
        ])
    }

    // MARK: - Fetch posts

    /// Posts ativos (não expirados) mais recentes.
    static func fetchActivePosts(limit: Int = 40) async -> [PulsePost] {
        guard PulseExperimental.isCloudSyncEffective, isAvailable else { return [] }
        do {
            let snap = try await posts()
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            let now = Date()
            return snap.documents.compactMap { doc -> PulsePost? in
                guard let post = decodePost(doc.data(), documentId: doc.documentID) else { return nil }
                guard post.expiresAt > now, !post.isHidden else { return nil }
                return post
            }
        } catch {
            print("[Pulse] Falha ao buscar posts: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Profiles

    static func upsertProfile(_ person: PulsePerson) async {
        guard PulseExperimental.isCloudSyncEffective, isAvailable else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        guard person.id == uid else { return }

        var data: [String: Any] = [
            "id": uid,
            "displayName": person.displayName,
            "emailHint": person.emailHint,
            "countryCode": person.countryCode,
            "state": person.state,
            "city": person.city,
            "bio": String(person.bio.prefix(PulseExperimental.maxBioCharacters)),
            "communityFocus": person.communityFocus.rawValue,
            "notifyOnPosts": person.notifyOnPosts,
            "updatedAt": FieldValue.serverTimestamp(),
            "source": PulseExperimental.cloudSourceTag,
        ]

        do {
            let ref = profiles().document(uid)
            let existing = try await ref.getDocument()
            if existing.exists != true {
                data["createdAt"] = FieldValue.serverTimestamp()
            }
            try await ref.setData(data, merge: true)
        } catch {
            print("[Pulse] Falha ao gravar perfil: \(error.localizedDescription)")
        }
    }

    static func fetchProfiles(limit: Int = 80) async -> [PulsePerson] {
        guard PulseExperimental.isCloudSyncEffective, isAvailable else { return [] }
        do {
            let snap = try await profiles()
                .order(by: "displayName")
                .limit(to: limit)
                .getDocuments()
            return snap.documents.compactMap { decodePerson($0.data(), documentId: $0.documentID) }
        } catch {
            print("[Pulse] Falha ao buscar perfis: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Follows

    /// Status cloud: `pending` | `accepted` (mapeado de `requested` / `following`).
    /// Criação exige auth == from; aceite (`accepted`) também pode ser feito pelo toUserId.
    static func upsertFollow(from fromUserId: String, to toUserId: String, status: PulseFollowStatus) async {
        guard PulseExperimental.isCloudSyncEffective, isAvailable else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        guard fromUserId != toUserId else { return }
        guard let cloudStatus = cloudFollowStatus(from: status) else { return }

        let isCreator = fromUserId == uid
        let isTargetAccepting = toUserId == uid && cloudStatus == "accepted"
        guard isCreator || isTargetAccepting else { return }

        let followId = "\(fromUserId)_\(toUserId)"
        var data: [String: Any] = [
            "fromUserId": fromUserId,
            "toUserId": toUserId,
            "status": cloudStatus,
            "updatedAt": FieldValue.serverTimestamp(),
            "source": PulseExperimental.cloudSourceTag,
        ]

        do {
            let ref = follows().document(followId)
            if isCreator {
                data["createdAt"] = FieldValue.serverTimestamp()
                try await ref.setData(data, merge: true)
            } else {
                // Aceite pelo destinatário: só atualiza status (rules exigem from/to imutáveis).
                try await ref.updateData([
                    "status": cloudStatus,
                    "updatedAt": FieldValue.serverTimestamp(),
                ])
            }
        } catch {
            print("[Pulse] Falha ao gravar follow: \(error.localizedDescription)")
        }
    }

    static func fetchFollows(for userId: String) async -> [PulseFollowRelation] {
        guard PulseExperimental.isCloudSyncEffective, isAvailable else { return [] }
        guard Auth.auth().currentUser?.uid != nil else { return [] }

        do {
            async let outgoing = follows()
                .whereField("fromUserId", isEqualTo: userId)
                .limit(to: 100)
                .getDocuments()
            async let incoming = follows()
                .whereField("toUserId", isEqualTo: userId)
                .limit(to: 100)
                .getDocuments()

            let (outSnap, inSnap) = try await (outgoing, incoming)
            var seen = Set<String>()
            var result: [PulseFollowRelation] = []
            for doc in outSnap.documents + inSnap.documents {
                guard seen.insert(doc.documentID).inserted else { continue }
                if let relation = decodeFollow(doc.data(), documentId: doc.documentID) {
                    result.append(relation)
                }
            }
            return result
        } catch {
            print("[Pulse] Falha ao buscar follows: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Stories

    @discardableResult
    static func upsertStory(_ story: PulseStory, imageJPEG: Data? = nil) async -> String? {
        guard PulseExperimental.isCloudSyncEffective, isAvailable else { return nil }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return nil }
        guard story.authorId == uid || story.authorId == "local" else { return nil }

        var remoteURL = story.remoteMediaURL
        if let imageJPEG {
            remoteURL = (try? await uploadJPEG(data: imageJPEG, userId: uid, fileId: story.id))?.absoluteString ?? remoteURL
        }

        let expiresAt = story.expiresAt > story.createdAt
            ? story.expiresAt
            : story.createdAt.addingTimeInterval(PulseExperimental.storyLifetime)

        var data: [String: Any] = [
            "id": story.id.uuidString,
            "authorId": uid,
            "authorName": story.authorName,
            "createdAt": Timestamp(date: story.createdAt),
            "expiresAt": Timestamp(date: expiresAt),
            "source": PulseExperimental.cloudSourceTag,
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        if let remoteURL { data["remoteMediaURL"] = remoteURL }
        if let placeholder = story.systemImagePlaceholder { data["systemImagePlaceholder"] = placeholder }
        if let music = story.music, let encoded = try? JSONEncoder().encode(music),
           let obj = try? JSONSerialization.jsonObject(with: encoded) {
            data["music"] = obj
        }
        if !story.textOverlays.isEmpty,
           let encoded = try? JSONEncoder().encode(story.textOverlays),
           let obj = try? JSONSerialization.jsonObject(with: encoded) {
            data["textOverlays"] = obj
        }

        do {
            try await stories().document(story.id.uuidString).setData(data, merge: true)
            return remoteURL
        } catch {
            print("[Pulse] Falha ao gravar story: \(error.localizedDescription)")
            return nil
        }
    }

    static func fetchActiveStories(limit: Int = 40) async -> [PulseStory] {
        guard PulseExperimental.isCloudSyncEffective, isAvailable else { return [] }
        do {
            let snap = try await stories()
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            let now = Date()
            return snap.documents.compactMap { doc -> PulseStory? in
                guard let story = decodeStory(doc.data(), documentId: doc.documentID) else { return nil }
                guard story.expiresAt > now else { return nil }
                return story
            }
        } catch {
            print("[Pulse] Falha ao buscar stories: \(error.localizedDescription)")
            return []
        }
    }

    static func deleteStory(id: UUID) async {
        guard PulseExperimental.isCloudSyncEffective, isAvailable else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let ref = stories().document(id.uuidString)
            let snap = try await ref.getDocument()
            guard snap.data()?["authorId"] as? String == uid else { return }
            try await ref.delete()
            try? await storage.reference(withPath: mediaPath(userId: uid, fileId: id)).delete()
        } catch {
            print("[Pulse] Falha ao apagar story remoto: \(error.localizedDescription)")
        }
    }

    // MARK: - Reactions

    static func setReaction(postId: UUID, userId: String, emoji: String) async {
        guard PulseExperimental.isCloudSyncEffective, isAvailable else { return }
        guard let uid = Auth.auth().currentUser?.uid, uid == userId else { return }
        let trimmed = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let data: [String: Any] = [
            "userId": uid,
            "emoji": String(trimmed.prefix(16)),
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        do {
            try await reactions(postId: postId.uuidString).document(uid).setData(data, merge: true)
        } catch {
            print("[Pulse] Falha ao gravar reação: \(error.localizedDescription)")
        }
    }

    static func clearReaction(postId: UUID, userId: String) async {
        guard PulseExperimental.isCloudSyncEffective, isAvailable else { return }
        guard let uid = Auth.auth().currentUser?.uid, uid == userId else { return }
        do {
            try await reactions(postId: postId.uuidString).document(uid).delete()
        } catch {
            print("[Pulse] Falha ao remover reação: \(error.localizedDescription)")
        }
    }

    static func fetchReactions(postId: UUID) async -> [PulseReactionEvent] {
        guard PulseExperimental.isCloudSyncEffective, isAvailable else { return [] }
        do {
            let snap = try await reactions(postId: postId.uuidString)
                .limit(to: 200)
                .getDocuments()
            return snap.documents.compactMap { decodeReaction($0.data(), documentId: $0.documentID) }
        } catch {
            print("[Pulse] Falha ao buscar reações: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Comments

    @discardableResult
    static func addComment(postId: UUID, comment: PulseComment) async -> Bool {
        guard PulseExperimental.isCloudSyncEffective, isAvailable else { return false }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return false }
        guard comment.authorId == uid else { return false }
        let text = comment.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }

        let data: [String: Any] = [
            "id": comment.id.uuidString,
            "authorId": uid,
            "authorName": comment.authorName,
            "text": String(text.prefix(500)),
            "createdAt": Timestamp(date: comment.createdAt),
        ]
        do {
            try await comments(postId: postId.uuidString).document(comment.id.uuidString).setData(data)
            return true
        } catch {
            print("[Pulse] Falha ao gravar comentário: \(error.localizedDescription)")
            return false
        }
    }

    static func fetchComments(postId: UUID, limit: Int = 50) async -> [PulseComment] {
        guard PulseExperimental.isCloudSyncEffective, isAvailable else { return [] }
        do {
            let snap = try await comments(postId: postId.uuidString)
                .order(by: "createdAt", descending: false)
                .limit(to: limit)
                .getDocuments()
            return snap.documents.compactMap { decodeComment($0.data(), documentId: $0.documentID) }
        } catch {
            print("[Pulse] Falha ao buscar comentários: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Blocks

    static func upsertBlock(blockerId: String, blockedId: String) async {
        guard PulseExperimental.isCloudSyncEffective, isAvailable else { return }
        guard let uid = Auth.auth().currentUser?.uid, uid == blockerId else { return }
        guard blockerId != blockedId else { return }

        let blockId = "\(blockerId)_\(blockedId)"
        do {
            try await blocks().document(blockId).setData([
                "blockerId": blockerId,
                "blockedId": blockedId,
                "createdAt": FieldValue.serverTimestamp(),
                "source": PulseExperimental.cloudSourceTag,
            ], merge: true)
        } catch {
            print("[Pulse] Falha ao gravar bloqueio: \(error.localizedDescription)")
        }
    }

    static func blockCurrentUserTarget(_ blockedId: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        await upsertBlock(blockerId: uid, blockedId: blockedId)
    }

    static func fetchBlocks(for blockerId: String? = nil) async -> [(blockerId: String, blockedId: String)] {
        guard PulseExperimental.isCloudSyncEffective, isAvailable else { return [] }
        guard let uid = Auth.auth().currentUser?.uid else { return [] }
        let owner = blockerId ?? uid
        guard owner == uid else { return [] }

        do {
            let snap = try await blocks()
                .whereField("blockerId", isEqualTo: owner)
                .limit(to: 200)
                .getDocuments()
            return snap.documents.compactMap { doc in
                let data = doc.data()
                guard let blocker = data["blockerId"] as? String,
                      let blocked = data["blockedId"] as? String else { return nil }
                return (blocker, blocked)
            }
        } catch {
            print("[Pulse] Falha ao buscar bloqueios: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Moderation

    /// Listagem de denúncias — rules só permitem reporter ou moderador.
    static func fetchReports(limit: Int = 50) async -> [PulseCloudReport] {
        guard PulseExperimental.isCloudSyncEffective, isAvailable else { return [] }
        guard Auth.auth().currentUser != nil else { return [] }

        do {
            let snap = try await reports()
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            return snap.documents.compactMap { doc in
                let data = doc.data()
                guard let postId = data["postId"] as? String,
                      let reporterId = data["reporterId"] as? String,
                      let reason = data["reason"] as? String else { return nil }
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                return PulseCloudReport(
                    id: doc.documentID,
                    postId: postId,
                    reporterId: reporterId,
                    reason: reason,
                    createdAt: createdAt
                )
            }
        } catch {
            print("[Pulse] Falha ao buscar reports: \(error.localizedDescription)")
            return []
        }
    }

    static func moderateHidePost(postId: UUID, hidden: Bool) async {
        guard PulseExperimental.isCloudSyncEffective, isAvailable else { return }
        guard Auth.auth().currentUser != nil else { return }
        do {
            try await posts().document(postId.uuidString).updateData([
                "isHidden": hidden,
                "updatedAt": FieldValue.serverTimestamp(),
            ])
        } catch {
            print("[Pulse] Falha ao ocultar post (mod): \(error.localizedDescription)")
        }
    }

    static func moderateDeletePost(postId: UUID) async {
        guard PulseExperimental.isCloudSyncEffective, isAvailable else { return }
        guard Auth.auth().currentUser != nil else { return }
        do {
            try await posts().document(postId.uuidString).delete()
        } catch {
            print("[Pulse] Falha ao apagar post (mod): \(error.localizedDescription)")
        }
    }

    // MARK: - Account deletion

    /// Remove dados Pulse do utilizador na nuvem. Corre **mesmo com sync OFF** (exclusão de conta).
    /// Relatórios (`pulseReports`) ficam para moderação — o autor não pode apagá-los pelas rules.
    static func deleteAllUserData(userId: String) async throws {
        guard isAvailable else { return }
        guard Auth.auth().currentUser?.uid == userId, !userId.isEmpty else { return }

        // Posts do autor (+ subcoleções) — paginado.
        while true {
            let snap = try await posts()
                .whereField("authorId", isEqualTo: userId)
                .limit(to: 40)
                .getDocuments()
            if snap.documents.isEmpty { break }
            for doc in snap.documents {
                try await deleteSubcollection(reactions(postId: doc.documentID))
                try await deleteSubcollection(comments(postId: doc.documentID))
                try await doc.reference.delete()
            }
            if snap.documents.count < 40 { break }
        }

        while true {
            let snap = try await stories()
                .whereField("authorId", isEqualTo: userId)
                .limit(to: 40)
                .getDocuments()
            if snap.documents.isEmpty { break }
            for doc in snap.documents {
                try await doc.reference.delete()
            }
            if snap.documents.count < 40 { break }
        }

        try? await profiles().document(userId).delete()

        for field in ["fromUserId", "toUserId"] {
            while true {
                let snap = try await follows()
                    .whereField(field, isEqualTo: userId)
                    .limit(to: 80)
                    .getDocuments()
                if snap.documents.isEmpty { break }
                for doc in snap.documents {
                    try await doc.reference.delete()
                }
                if snap.documents.count < 80 { break }
            }
        }

        while true {
            let snap = try await blocks()
                .whereField("blockerId", isEqualTo: userId)
                .limit(to: 80)
                .getDocuments()
            if snap.documents.isEmpty { break }
            for doc in snap.documents {
                try await doc.reference.delete()
            }
            if snap.documents.count < 80 { break }
        }

        // Reações/comentários em posts de outros (best-effort; pode exigir índice).
        try? await deleteCollectionGroupDocuments(
            collectionId: "reactions",
            field: "userId",
            equals: userId
        )
        try? await deleteCollectionGroupDocuments(
            collectionId: "comments",
            field: "authorId",
            equals: userId
        )

        try? await deleteAllStorageMedia(userId: userId)
    }

    // MARK: - Private helpers

    private static func deleteSubcollection(_ collection: CollectionReference) async throws {
        while true {
            let snap = try await collection.limit(to: 80).getDocuments()
            if snap.documents.isEmpty { break }
            for doc in snap.documents {
                try await doc.reference.delete()
            }
            if snap.documents.count < 80 { break }
        }
    }

    private static func deleteCollectionGroupDocuments(
        collectionId: String,
        field: String,
        equals value: String
    ) async throws {
        while true {
            let snap = try await db.collectionGroup(collectionId)
                .whereField(field, isEqualTo: value)
                .limit(to: 80)
                .getDocuments()
            if snap.documents.isEmpty { break }
            for doc in snap.documents {
                try await doc.reference.delete()
            }
            if snap.documents.count < 80 { break }
        }
    }

    private static func deleteAllStorageMedia(userId: String) async throws {
        let folder = storage.reference(withPath: "pulse/\(userId)")
        let listed = try await folder.listAll()
        for item in listed.items {
            try? await item.delete()
        }
        for prefix in listed.prefixes {
            let nested = try await prefix.listAll()
            for item in nested.items {
                try? await item.delete()
            }
        }
    }

    private static func mediaPath(userId: String, fileId: UUID) -> String {
        "pulse/\(userId)/\(fileId.uuidString).jpg"
    }

    private static func uploadJPEG(data: Data, userId: String, fileId: UUID) async throws -> URL {
        let reference = storage.reference(withPath: mediaPath(userId: userId, fileId: fileId))
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await reference.putDataAsync(data, metadata: metadata)
        return try await reference.downloadURL()
    }

    /// Mapeia status local → cloud (`pending` / `accepted`).
    private static func cloudFollowStatus(from status: PulseFollowStatus) -> String? {
        switch status {
        case .requested: return "pending"
        case .following: return "accepted"
        case .none, .incoming: return nil
        }
    }

    private static func localFollowStatus(from cloud: String) -> PulseFollowStatus {
        switch cloud {
        case "accepted": return .following
        case "pending": return .requested
        default: return .none
        }
    }

    private static func firestorePayload(
        for post: PulsePost,
        authorId: String,
        remoteMediaURL: String?
    ) -> [String: Any] {
        let expiresAt = post.expiresAt > post.createdAt
            ? post.expiresAt
            : post.createdAt.addingTimeInterval(PulseExperimental.postLifetime)
        var data: [String: Any] = [
            "id": post.id.uuidString,
            "authorId": authorId,
            "authorName": post.authorName,
            "authorCountryCode": post.authorCountryCode,
            "caption": post.caption,
            "mediaKind": post.mediaKind.rawValue,
            "community": post.community.rawValue,
            "createdAt": Timestamp(date: post.createdAt),
            "expiresAt": Timestamp(date: expiresAt),
            "isHidden": post.isHidden,
            "reportCount": post.reportCount,
            "source": PulseExperimental.cloudSourceTag,
        ]
        if let remoteMediaURL { data["remoteMediaURL"] = remoteMediaURL }
        if let placeholder = post.systemImagePlaceholder { data["systemImagePlaceholder"] = placeholder }
        if let meta = post.workoutMeta, let encoded = try? JSONEncoder().encode(meta),
           let obj = try? JSONSerialization.jsonObject(with: encoded) {
            data["workoutMeta"] = obj
        }
        if let music = post.music, let encoded = try? JSONEncoder().encode(music),
           let obj = try? JSONSerialization.jsonObject(with: encoded) {
            data["music"] = obj
        }
        return data
    }

    private static func decodePost(_ data: [String: Any], documentId: String) -> PulsePost? {
        let id = UUID(uuidString: (data["id"] as? String) ?? documentId) ?? UUID()
        guard let authorId = data["authorId"] as? String,
              let authorName = data["authorName"] as? String,
              let caption = data["caption"] as? String else { return nil }

        let mediaKind = PulseMediaKind(rawValue: data["mediaKind"] as? String ?? "photo") ?? .photo
        let community = PulseCommunity(storageKey: data["community"] as? String ?? "musculacao") ?? .musculacao
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue()
            ?? createdAt.addingTimeInterval(PulseExperimental.postLifetime)

        var workoutMeta: PulseWorkoutMeta?
        if let raw = data["workoutMeta"],
           let json = try? JSONSerialization.data(withJSONObject: raw) {
            workoutMeta = try? JSONDecoder().decode(PulseWorkoutMeta.self, from: json)
        }
        var music: PulseMusicAttachment?
        if let raw = data["music"],
           let json = try? JSONSerialization.data(withJSONObject: raw) {
            music = try? JSONDecoder().decode(PulseMusicAttachment.self, from: json)
        }

        // Reações/comentários vivem em subcoleções — parent fica vazio (merge no cliente se necessário).
        return PulsePost(
            id: id,
            authorId: authorId,
            authorName: authorName,
            authorCountryCode: data["authorCountryCode"] as? String ?? "BR",
            caption: caption,
            mediaKind: mediaKind,
            mediaFileName: nil,
            remoteMediaURL: data["remoteMediaURL"] as? String,
            systemImagePlaceholder: data["systemImagePlaceholder"] as? String,
            community: community,
            workoutMeta: workoutMeta,
            music: music,
            createdAt: createdAt,
            expiresAt: expiresAt,
            reactions: [],
            comments: [],
            isHidden: data["isHidden"] as? Bool ?? false,
            reportCount: data["reportCount"] as? Int ?? 0
        )
    }

    private static func decodePerson(_ data: [String: Any], documentId: String) -> PulsePerson? {
        let id = (data["id"] as? String) ?? documentId
        guard let displayName = data["displayName"] as? String else { return nil }
        let community = PulseCommunity(storageKey: data["communityFocus"] as? String ?? "musculacao") ?? .musculacao
        return PulsePerson(
            id: id,
            displayName: displayName,
            emailHint: data["emailHint"] as? String ?? "",
            countryCode: data["countryCode"] as? String ?? "BR",
            state: data["state"] as? String ?? "",
            city: data["city"] as? String ?? "",
            bio: data["bio"] as? String ?? "",
            communityFocus: community,
            notifyOnPosts: data["notifyOnPosts"] as? Bool ?? true
        )
    }

    private static func decodeFollow(_ data: [String: Any], documentId: String) -> PulseFollowRelation? {
        guard let fromUserId = data["fromUserId"] as? String,
              let toUserId = data["toUserId"] as? String else { return nil }
        let cloudStatus = data["status"] as? String ?? "pending"
        let status = localFollowStatus(from: cloudStatus)
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let id = UUID(uuidString: documentId) ?? UUID()
        return PulseFollowRelation(
            id: id,
            fromUserId: fromUserId,
            toUserId: toUserId,
            status: status,
            createdAt: createdAt,
            notifyPosts: data["notifyPosts"] as? Bool ?? true
        )
    }

    private static func decodeStory(_ data: [String: Any], documentId: String) -> PulseStory? {
        let id = UUID(uuidString: (data["id"] as? String) ?? documentId) ?? UUID()
        guard let authorId = data["authorId"] as? String,
              let authorName = data["authorName"] as? String else { return nil }
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue()
            ?? createdAt.addingTimeInterval(PulseExperimental.storyLifetime)

        var music: PulseMusicAttachment?
        if let raw = data["music"],
           let json = try? JSONSerialization.data(withJSONObject: raw) {
            music = try? JSONDecoder().decode(PulseMusicAttachment.self, from: json)
        }
        var overlays: [PulseStoryTextOverlay] = []
        if let raw = data["textOverlays"],
           let json = try? JSONSerialization.data(withJSONObject: raw) {
            overlays = (try? JSONDecoder().decode([PulseStoryTextOverlay].self, from: json)) ?? []
        }

        return PulseStory(
            id: id,
            authorId: authorId,
            authorName: authorName,
            mediaFileName: nil,
            remoteMediaURL: data["remoteMediaURL"] as? String,
            systemImagePlaceholder: data["systemImagePlaceholder"] as? String,
            createdAt: createdAt,
            expiresAt: expiresAt,
            isViewed: false,
            reactions: [],
            music: music,
            textOverlays: overlays
        )
    }

    private static func decodeReaction(_ data: [String: Any], documentId: String) -> PulseReactionEvent? {
        let userId = (data["userId"] as? String) ?? documentId
        let emoji = data["emoji"] as? String ?? "heart"
        let kind = emoji == "💚" || emoji == "heart" ? "heart" : emoji
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        return PulseReactionEvent(
            userId: userId,
            userName: data["userName"] as? String ?? "",
            kind: kind,
            createdAt: createdAt
        )
    }

    private static func decodeComment(_ data: [String: Any], documentId: String) -> PulseComment? {
        let id = UUID(uuidString: (data["id"] as? String) ?? documentId) ?? UUID()
        guard let authorId = data["authorId"] as? String,
              let authorName = data["authorName"] as? String,
              let text = data["text"] as? String else { return nil }
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        return PulseComment(
            id: id,
            authorId: authorId,
            authorName: authorName,
            text: text,
            createdAt: createdAt
        )
    }
}

private extension StorageReference {
    func putDataAsync(_ data: Data, metadata: StorageMetadata?) async throws -> StorageMetadata {
        try await withCheckedThrowingContinuation { continuation in
            putData(data, metadata: metadata) { meta, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let meta {
                    continuation.resume(returning: meta)
                } else {
                    continuation.resume(throwing: NSError(domain: "PulseStorage", code: -1))
                }
            }
        }
    }
}
