import Foundation

enum DuoTeamModality: String, CaseIterable, Codable, Identifiable, Hashable {
    case running = "Corrida"
    case walking = "Caminhada"
    case cycling = "Bike"
    case surfing = "Surf"
    case kitesurf = "Kitesurf"
    case strength = "Musculação"
    case mixed = "Mista"

    var id: String { rawValue }

    /// Modalidades escolhíveis na criação (sem “Mista”).
    static var selectableCases: [DuoTeamModality] {
        allCases.filter { $0 != .mixed }
    }

    var icon: String {
        switch self {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "bicycle"
        case .surfing: return "water.waves"
        case .kitesurf: return "wind"
        case .strength: return "dumbbell.fill"
        case .mixed: return "person.3.fill"
        }
    }

    /// Inferência da modalidade do treino a partir da sessão (título / flags).
    static func resolved(from session: WorkoutSession) -> DuoTeamModality? {
        if session.isKitesurfSession { return .kitesurf }
        if session.isSurfSession { return .surfing }
        if session.isOutdoorWalkingSession { return .walking }
        if session.isOutdoorCyclingSession { return .cycling }
        let title = session.workoutTitle.lowercased()
        if title.contains("kite") { return .kitesurf }
        if title.contains("surf") { return .surfing }
        if title.contains("caminhada") || title.contains("walk") { return .walking }
        if title.contains("bike") || title.contains("cicl") || title.contains("pedal")
            || title.contains("bicicleta") {
            return .cycling
        }
        if title.contains("corrida") || title.contains("run") { return .running }
        if title.hasPrefix("meditação") || title.hasPrefix("meditacao") { return nil }
        if session.isOutdoorGPSCardio { return .running }
        // Força / fichas / home / mobilidade.
        if WorkoutReportBuilder.isCardioSession(session) {
            return nil
        }
        return .strength
    }

    static func resolved(fromCardioExerciseName name: String) -> DuoTeamModality? {
        let lower = name.lowercased()
        if lower.contains("kite") { return .kitesurf }
        if lower.contains("surf") { return .surfing }
        if lower.contains("caminhada") { return .walking }
        if lower.contains("bike") || lower.contains("bicicleta") || lower.contains("mountain") {
            return .cycling
        }
        if lower.contains("corrida") { return .running }
        return nil
    }
}

enum DuoInviteStatus: String, Codable, Equatable {
    case pending
    case accepted
    case declined
    case cancelled
    case expired

    var displayLabel: String {
        switch self {
        case .pending: return "Pendente"
        case .accepted: return "Aceito"
        case .declined: return "Recusado"
                    case .cancelled: return "Retirado"
                    case .expired: return "Expirado"
        }
    }

    var accentColorName: String {
        switch self {
        case .pending: return "orange"
        case .accepted: return "green"
        case .declined, .cancelled, .expired: return "secondary"
        }
    }
}

enum DuoChatMessageKind: String, Codable, Equatable {
    case text
    case scheduleProposal
    case system
}

struct DuoTeamMember: Identifiable, Codable, Equatable, Hashable {
    var id: String { uid ?? phoneE164 ?? name }
    var uid: String?
    var name: String
    var phoneE164: String?
    /// ISO-3166 alpha-2 (bandeira).
    var countryCode: String?
    /// URL da foto de perfil sincronizada (Firebase Storage).
    var photoURL: String?
    var joinedAt: Date

    init(
        uid: String? = nil,
        name: String,
        phoneE164: String? = nil,
        countryCode: String? = nil,
        photoURL: String? = nil,
        joinedAt: Date = .now
    ) {
        self.uid = uid
        self.name = name
        self.phoneE164 = phoneE164
        self.countryCode = countryCode
        self.photoURL = photoURL
        self.joinedAt = joinedAt
    }

    var flagEmoji: String {
        CountryOption.flagEmoji(for: countryCode ?? "")
    }
}

struct DuoTeam: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    /// Modalidades ativas do grupo (1…N). `modality` legado espelha a primeira.
    var modalities: [DuoTeamModality]
    var createdByUid: String
    var createdByName: String
    var members: [DuoTeamMember]
    var createdAt: Date
    var updatedAt: Date
    /// Confirma que o criador aceitou o aviso de privacidade (sem localização em tempo real).
    var privacyAcknowledged: Bool
    /// Foto opcional da capa do grupo (Firebase Storage).
    var photoURL: String?

    var memberCount: Int { members.count }

    /// Compat / display: primeira modalidade (ou Mista se várias).
    var modality: DuoTeamModality {
        get {
            let effective = effectiveModalities
            if effective.count == 1 { return effective[0] }
            if effective.isEmpty { return .mixed }
            return .mixed
        }
        set {
            if modalities.isEmpty {
                modalities = [newValue]
            } else {
                modalities[0] = newValue
            }
        }
    }

    /// Modalidades que realmente contam no ranking/modo equipe.
    /// Legado só com “Mista” → todas as selecionáveis.
    var effectiveModalities: [DuoTeamModality] {
        let cleaned = modalities.filter { $0 != .mixed }
        if cleaned.isEmpty { return DuoTeamModality.selectableCases }
        // Mantém ordem e remove duplicatas.
        var seen = Set<DuoTeamModality>()
        return cleaned.filter { seen.insert($0).inserted }
    }

    var modalitiesLabel: String {
        let list = effectiveModalities
        if list.count == DuoTeamModality.selectableCases.count {
            return "Todas"
        }
        if list.isEmpty { return DuoTeamModality.mixed.rawValue }
        return list.map(\.rawValue).joined(separator: ", ")
    }

    var subtitle: String {
        "\(modalitiesLabel) · \(memberCount) \(memberCount == 1 ? "pessoa" : "pessoas")"
    }

    init(
        id: String,
        name: String,
        modalities: [DuoTeamModality],
        createdByUid: String,
        createdByName: String,
        members: [DuoTeamMember],
        createdAt: Date,
        updatedAt: Date,
        privacyAcknowledged: Bool,
        photoURL: String? = nil
    ) {
        self.id = id
        self.name = name
        let cleaned = modalities.filter { $0 != .mixed }
        self.modalities = cleaned.isEmpty ? [.mixed] : cleaned
        self.createdByUid = createdByUid
        self.createdByName = createdByName
        self.members = members
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.privacyAcknowledged = privacyAcknowledged
        self.photoURL = photoURL
    }

    /// Compat com código antigo que passava uma modalidade.
    init(
        id: String,
        name: String,
        modality: DuoTeamModality,
        createdByUid: String,
        createdByName: String,
        members: [DuoTeamMember],
        createdAt: Date,
        updatedAt: Date,
        privacyAcknowledged: Bool,
        photoURL: String? = nil
    ) {
        self.init(
            id: id,
            name: name,
            modalities: modality == .mixed ? [.mixed] : [modality],
            createdByUid: createdByUid,
            createdByName: createdByName,
            members: members,
            createdAt: createdAt,
            updatedAt: updatedAt,
            privacyAcknowledged: privacyAcknowledged,
            photoURL: photoURL
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        createdByUid = try container.decode(String.self, forKey: .createdByUid)
        createdByName = try container.decode(String.self, forKey: .createdByName)
        members = try container.decode([DuoTeamMember].self, forKey: .members)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        privacyAcknowledged = try container.decodeIfPresent(Bool.self, forKey: .privacyAcknowledged) ?? true
        photoURL = try container.decodeIfPresent(String.self, forKey: .photoURL)

        if let multi = try container.decodeIfPresent([DuoTeamModality].self, forKey: .modalities),
           !multi.isEmpty {
            modalities = multi
        } else if let single = try container.decodeIfPresent(DuoTeamModality.self, forKey: .modality) {
            modalities = [single]
        } else {
            modalities = [.mixed]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(modalities, forKey: .modalities)
        try container.encode(modality, forKey: .modality)
        try container.encode(createdByUid, forKey: .createdByUid)
        try container.encode(createdByName, forKey: .createdByName)
        try container.encode(members, forKey: .members)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(privacyAcknowledged, forKey: .privacyAcknowledged)
        try container.encodeIfPresent(photoURL, forKey: .photoURL)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, modalities, modality, createdByUid, createdByName
        case members, createdAt, updatedAt, privacyAcknowledged, photoURL
    }

    func allows(_ sessionModality: DuoTeamModality?) -> Bool {
        guard let sessionModality else { return false }
        return effectiveModalities.contains(sessionModality)
    }

    func allows(session: WorkoutSession) -> Bool {
        allows(DuoTeamModality.resolved(from: session))
    }
}

struct DuoTeamInvite: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var teamId: String
    var teamName: String
    var modality: DuoTeamModality
    var code: String
    var fromUid: String
    var fromName: String
    var toName: String
    var toPhoneE164: String
    /// E-mail do convidado (convite por Mail).
    var toEmail: String?
    /// UID do convidado quando encontrado pelo cadastro no HealthFit.
    var toUid: String?
    var status: DuoInviteStatus
    var createdAt: Date
    var expiresAt: Date

    var isExpired: Bool {
        status == .expired || Date() > expiresAt
    }
}

struct DuoInviteShareCopy: Equatable {
    var smsBody: String
    var emailSubject: String
    var emailBody: String
    var shareText: String
}

/// Aviso na caixa de entrada do usuário (ex.: foi adicionado a um grupo).
struct DuoInboxNotification: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var kind: String
    var title: String
    var body: String
    var teamId: String
    var teamName: String
    var fromUid: String
    var fromName: String
    var createdAt: Date
    var delivered: Bool
}

/// Desempenho compartilhado com a equipe para o ranking (sem localização).
struct DuoMemberPerformance: Identifiable, Codable, Equatable, Hashable {
    var uid: String
    var displayName: String
    var sessionsLast7Days: Int
    var sessionsLast30Days: Int
    var minutesLast7Days: Int
    var minutesLast30Days: Int
    var caloriesLast7Days: Int
    var caloriesLast30Days: Int
    var lastWorkoutAt: Date?
    var updatedAt: Date

    var id: String { uid }

    /// Pontuação do ranking (7 dias): treinos + tempo + calorias.
    var rankingScore7d: Int {
        sessionsLast7Days * 100 + minutesLast7Days + caloriesLast7Days / 10
    }
}

struct DuoTeamRankingRow: Identifiable, Equatable, Hashable {
    var rank: Int
    var performance: DuoMemberPerformance
    var id: String { performance.uid }
}

struct DuoTeamReport: Equatable {
    var teamId: String
    var teamName: String
    var modality: DuoTeamModality
    var periodLabel: String
    var rows: [DuoTeamRankingRow]
    var teamSessions7d: Int
    var teamMinutes7d: Int
    var teamCalories7d: Int
}

/// Resultado público da busca por nome / “como você gostaria de ser chamado”.
struct UserDirectoryEntry: Identifiable, Codable, Equatable, Hashable {
    var uid: String
    var name: String
    var displayName: String
    var countryCode: String?
    var photoURL: String?

    var id: String { uid }

    var shownName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? name : trimmed
    }

    var flagEmoji: String {
        CountryOption.flagEmoji(for: countryCode ?? "")
    }

    var detailLine: String {
        let callName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if callName.isEmpty || callName.caseInsensitiveCompare(name) == .orderedSame {
            return name
        }
        return "\(name) · “\(callName)”"
    }
}

struct DuoChatMessage: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var teamId: String
    var senderUid: String
    var senderName: String
    var text: String
    var kind: DuoChatMessageKind
    var createdAt: Date
    /// Quando `kind == .scheduleProposal`.
    var proposedAt: Date?

    var isSchedule: Bool { kind == .scheduleProposal }

    /// Mensagens do chat de equipe expiram após 12 horas.
    var isExpired: Bool {
        Date().timeIntervalSince(createdAt) >= DuoTeamChatPolicy.messageTTL
    }
}

enum DuoTeamChatPolicy {
    static let messageTTL: TimeInterval = 12 * 60 * 60

    static let purposeNotice =
        "O chat é só para marcar atividades físicas. As mensagens expiram em 12 horas."
}

enum DuoTeamPrivacy {
    static let consentKey = "healthfit.duoTeam.privacyConsent.v1"
    static let consentVersion = 1

    static var hasAcknowledged: Bool {
        UserDefaults.standard.bool(forKey: consentKey)
    }

    static func acknowledge() {
        UserDefaults.standard.set(true, forKey: consentKey)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: consentKey)
    }

    static let clearNotice = """
    Por segurança, o HealthFit NÃO usa localização em tempo real nem mostra um mapa ao vivo de onde você ou outros usuários estão.

    Treino em dupla/equipe serve para convidar parceiros, combinar horários no chat e acompanhar a evolução juntos — sem expor sua posição.

    O chat é exclusivo para marcar atividades físicas. As mensagens ficam disponíveis por 12 horas e depois expiram.

    Você precisa confirmar isso antes de continuar.
    """
}
