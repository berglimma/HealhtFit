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
            "hasBodyMeasurements": profile.bodyMeasurements.hasAnyValue,
            "updatedAt": Timestamp(date: profile.updatedAt),
            "createdAt": Timestamp(date: profile.createdAt),
        ]
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
        let country = CountryOption.resolvedCode(profile.countryCode)
        var data: [String: Any] = [
            "uid": profile.id,
            "name": name,
            "displayName": displayName,
            "nameLower": name.lowercased(),
            "displayNameLower": displayName.lowercased(),
            "countryCode": country,
            "updatedAt": Timestamp(date: .now),
        ]
        if let photoURL {
            data["photoURL"] = photoURL
        }
        try await directoryDocument(userId: profile.id).setData(data, merge: true)
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
            "nameLower": name.lowercased(),
            "displayNameLower": displayName.lowercased(),
            "updatedAt": Timestamp(date: .now),
        ]
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

    /// Busca por prefixo no nome do cadastro ou em “como você gostaria de ser chamado”.
    static func searchUsers(
        query: String,
        excludingUserId: String?,
        limit: Int = 20
    ) async throws -> [UserDirectoryEntry] {
        guard isAvailable else { return [] }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.count >= 2 else { return [] }

        let end = trimmed + "\u{f8ff}"
        async let byName = directoryCollection()
            .whereField("nameLower", isGreaterThanOrEqualTo: trimmed)
            .whereField("nameLower", isLessThan: end)
            .limit(to: limit)
            .getDocuments()
        async let byDisplay = directoryCollection()
            .whereField("displayNameLower", isGreaterThanOrEqualTo: trimmed)
            .whereField("displayNameLower", isLessThan: end)
            .limit(to: limit)
            .getDocuments()

        let nameSnap = try await byName
        let displaySnap = try await byDisplay
        var byUid: [String: UserDirectoryEntry] = [:]
        for doc in nameSnap.documents + displaySnap.documents {
            guard let entry = decodeDirectoryEntry(doc.data()) else { continue }
            if let excludingUserId, entry.uid == excludingUserId { continue }
            byUid[entry.uid] = entry
        }

        return Array(byUid.values)
            .sorted {
                $0.shownName.localizedCaseInsensitiveCompare($1.shownName) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
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
