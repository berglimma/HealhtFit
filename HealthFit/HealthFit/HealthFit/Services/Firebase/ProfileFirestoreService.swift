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

        var profile = profile
        profile.prepareMenstrualCycleForPersistence()

        let payload = try encoder.encode(profile)
        guard let json = String(data: payload, encoding: .utf8) else { return }

        var data: [String: Any] = [
            "profilePayload": json,
            "email": profile.email,
            "name": profile.name,
            "displayName": profile.displayName,
            "countryCode": CountryOption.resolvedCode(profile.countryCode),
            "weight": profile.weight,
            "height": profile.height,
            "age": profile.age,
            "gender": profile.gender.rawValue,
            "goal": profile.goal.rawValue,
            "biotype": profile.biotype.rawValue,
            "accountRole": profile.accountRole.rawValue,
            "hasBodyMeasurements": profile.bodyMeasurements.hasAnyValue,
            "updatedAt": Timestamp(date: profile.updatedAt),
            "createdAt": Timestamp(date: profile.createdAt),
        ]
        applyMenstrualCycleFields(from: profile, to: &data)
        if let dateOfBirth = profile.dateOfBirth {
            data["dateOfBirth"] = Timestamp(date: dateOfBirth)
        } else {
            data["dateOfBirth"] = FieldValue.delete()
        }

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
        try await syncUserDirectory(profile)
    }

    /// Ciclo menstrual só no documento da conta feminina — nunca no diretório público.
    private static func applyMenstrualCycleFields(from profile: UserProfile, to data: inout [String: Any]) {
        if profile.gender == .female {
            let cycle = profile.menstrualCycle.clamped()
            var cycleData: [String: Any] = [
                "tracksCycle": cycle.tracksCycle,
                "cycleLengthDays": cycle.cycleLengthDays,
                "periodLengthDays": cycle.periodLengthDays,
            ]
            if let start = cycle.lastPeriodStart {
                cycleData["lastPeriodStart"] = Timestamp(date: start)
            }
            data["menstrualCycle"] = cycleData
        } else {
            data["menstrualCycle"] = FieldValue.delete()
        }
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

    // MARK: - Diretório público (nome + como quer ser chamado)

    private static func directoryDocument(userId: String) -> DocumentReference {
        db.collection("userDirectory").document(userId)
    }

    /// Expõe nome, apelido, país e foto para busca / membros de dupla/equipe.
    static func syncUserDirectory(_ profile: UserProfile, photoURL: String? = nil) async throws {
        guard isAvailable else { return }
        let name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = profile.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let country = CountryOption.resolvedCode(profile.countryCode)
        var data: [String: Any] = [
            "uid": profile.id,
            "name": name,
            "displayName": displayName,
            "email": email,
            "nameLower": searchableText(name),
            "displayNameLower": searchableText(displayName),
            "emailLower": searchableText(email),
            "countryCode": country,
            "updatedAt": Timestamp(date: .now),
        ]
        if let photoURL, !photoURL.isEmpty {
            data["photoURL"] = photoURL
        } else if let existing = try? await fetchDirectoryEntry(userId: profile.id)?.photoURL,
                  !existing.isEmpty {
            data["photoURL"] = existing
        } else if let fromStorage = await ProfilePhotoStorageService.downloadURLIfExists(userId: profile.id) {
            data["photoURL"] = fromStorage
        }
        try await directoryDocument(userId: profile.id).setData(data, merge: true)
    }

    /// Normaliza texto para busca (minúsculas + sem acentos).
    static func searchableText(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
            .lowercased()
    }

    /// Nome / país / foto para membros da equipe (diretório, com fallback no doc do usuário).
    static func fetchMemberPublicProfile(userId: String) async throws -> UserDirectoryEntry? {
        guard isAvailable else { return nil }
        if var entry = try await fetchDirectoryEntry(userId: userId) {
            let code = normalizedCountry(entry.countryCode)
            if code == nil {
                entry.countryCode = try await fetchCountryCodeFromUserDoc(userId: userId)
                if let fixed = entry.countryCode {
                    // Repara o diretório para as próximas leituras.
                    try? await directoryDocument(userId: userId).setData([
                        "uid": userId,
                        "countryCode": fixed,
                        "updatedAt": Timestamp(date: .now),
                    ], merge: true)
                }
            } else {
                entry.countryCode = code
            }
            return entry
        }

        // Diretório ainda não existe: monta a partir do perfil.
        let snap = try await userDocument(userId: userId).getDocument()
        guard let data = snap.data() else { return nil }
        var country = normalizedCountry(data["countryCode"] as? String)
        if country == nil {
            country = try? await fetchCountryCodeFromUserDoc(userId: userId)
        }
        let name = (data["name"] as? String) ?? ""
        let displayName = (data["displayName"] as? String) ?? ""
        guard !name.isEmpty || !displayName.isEmpty || country != nil else { return nil }
        let entry = UserDirectoryEntry(
            uid: userId,
            name: name,
            displayName: displayName,
            countryCode: country,
            photoURL: data["photoURL"] as? String
        )
        var directoryData: [String: Any] = [
            "uid": userId,
            "name": name,
            "displayName": displayName,
            "nameLower": searchableText(name),
            "displayNameLower": searchableText(displayName),
            "updatedAt": Timestamp(date: .now),
        ]
        if let email = (data["email"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !email.isEmpty {
            directoryData["email"] = email
            directoryData["emailLower"] = searchableText(email)
        }
        if let country {
            directoryData["countryCode"] = country
        }
        try? await directoryDocument(userId: userId).setData(directoryData, merge: true)
        return entry
    }

    private static func fetchCountryCodeFromUserDoc(userId: String) async throws -> String? {
        let snap = try await userDocument(userId: userId).getDocument()
        guard let data = snap.data() else { return nil }
        if let top = normalizedCountry(data["countryCode"] as? String) {
            return top
        }
        if let json = data["profilePayload"] as? String,
           let payload = json.data(using: .utf8),
           let profile = try? decoder.decode(UserProfile.self, from: payload) {
            return normalizedCountry(profile.countryCode)
        }
        return nil
    }

    private static func normalizedCountry(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let resolved = CountryOption.resolvedCode(trimmed)
        return resolved.isEmpty ? nil : resolved
    }

    static func updateDirectoryPhotoURL(userId: String, photoURL: String?) async throws {
        guard isAvailable else { return }
        if let photoURL, !photoURL.isEmpty {
            try await directoryDocument(userId: userId).setData([
                "uid": userId,
                "photoURL": photoURL,
                "updatedAt": Timestamp(date: .now),
            ], merge: true)
        } else {
            try await directoryDocument(userId: userId).setData([
                "uid": userId,
                "photoURL": FieldValue.delete(),
                "updatedAt": Timestamp(date: .now),
            ], merge: true)
        }
    }

    static func fetchDirectoryEntry(userId: String) async throws -> UserDirectoryEntry? {
        guard isAvailable else { return nil }
        let snap = try await directoryDocument(userId: userId).getDocument()
        guard snap.exists, var data = snap.data() else { return nil }
        if data["uid"] == nil { data["uid"] = userId }
        return decodeDirectoryEntry(data)
    }

    static func deleteUserDirectory(userId: String) async throws {
        guard isAvailable else { return }
        try await directoryDocument(userId: userId).delete()
    }

    /// Busca no diretório por nome, apelido ou e-mail (contém, sem acento).
    /// Com base pequena, lista o diretório e filtra no cliente — mais confiável que só prefixo.
    static func searchUsers(
        query: String,
        excludingUserId: String?,
        limit: Int = 20
    ) async throws -> [UserDirectoryEntry] {
        guard isAvailable else { return [] }
        let needle = searchableText(query)
        guard needle.count >= 2 else { return [] }

        let snap = try await directoryCollection()
            .order(by: FieldPath.documentID())
            .limit(to: 300)
            .getDocuments()

        var matches: [UserDirectoryEntry] = []
        for doc in snap.documents {
            var data = doc.data()
            if data["uid"] == nil { data["uid"] = doc.documentID }
            guard let entry = decodeDirectoryEntry(data) else { continue }
            if let excludingUserId, entry.uid == excludingUserId { continue }

            let haystacks = [
                searchableText(entry.name),
                searchableText(entry.displayName),
                searchableText(data["email"] as? String ?? ""),
                searchableText(data["nameLower"] as? String ?? ""),
                searchableText(data["displayNameLower"] as? String ?? ""),
                searchableText(data["emailLower"] as? String ?? ""),
            ]
            guard haystacks.contains(where: { $0.contains(needle) }) else { continue }
            matches.append(entry)
        }

        let limited = Array(
            matches
                .sorted {
                    $0.shownName.localizedCaseInsensitiveCompare($1.shownName) == .orderedAscending
                }
                .prefix(limit)
        )

        // Garante foto + bandeira na busca (repara diretório incompleto).
        return await withTaskGroup(of: UserDirectoryEntry.self) { group in
            for entry in limited {
                group.addTask {
                    await enrichDirectoryEntryForSearch(entry)
                }
            }
            var enriched: [UserDirectoryEntry] = []
            for await item in group {
                enriched.append(item)
            }
            return enriched.sorted {
                $0.shownName.localizedCaseInsensitiveCompare($1.shownName) == .orderedAscending
            }
        }
    }

    /// Completa `photoURL` / `countryCode` ausentes e republica no diretório.
    private static func enrichDirectoryEntryForSearch(_ entry: UserDirectoryEntry) async -> UserDirectoryEntry {
        var updated = entry
        var patch: [String: Any] = [:]

        if updated.countryCode == nil {
            if let code = try? await fetchCountryCodeFromUserDoc(userId: entry.uid) {
                updated.countryCode = code
                patch["countryCode"] = code
            }
        }

        if updated.photoURL == nil {
            if let fromUser = try? await fetchPhotoURLFromUserDoc(userId: entry.uid) {
                updated.photoURL = fromUser
                patch["photoURL"] = fromUser
            } else if let fromStorage = await ProfilePhotoStorageService.downloadURLIfExists(userId: entry.uid) {
                updated.photoURL = fromStorage
                patch["photoURL"] = fromStorage
            }
        }

        if !patch.isEmpty {
            patch["uid"] = entry.uid
            patch["updatedAt"] = Timestamp(date: .now)
            try? await directoryDocument(userId: entry.uid).setData(patch, merge: true)
        }
        return updated
    }

    private static func fetchPhotoURLFromUserDoc(userId: String) async throws -> String? {
        let snap = try await userDocument(userId: userId).getDocument()
        guard let data = snap.data() else { return nil }
        if let photo = data["photoURL"] as? String, !photo.isEmpty {
            return photo
        }
        return nil
    }

    private static func directoryCollection() -> CollectionReference {
        db.collection("userDirectory")
    }

    private static func decodeDirectoryEntry(_ data: [String: Any]) -> UserDirectoryEntry? {
        guard let uid = data["uid"] as? String else { return nil }
        let photo = data["photoURL"] as? String
        return UserDirectoryEntry(
            uid: uid,
            name: data["name"] as? String ?? "",
            displayName: data["displayName"] as? String ?? "",
            countryCode: normalizedCountry(data["countryCode"] as? String),
            photoURL: (photo?.isEmpty == false) ? photo : nil
        )
    }
}
