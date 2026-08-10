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
}

enum DuoInviteStatus: String, Codable, Equatable {
    case pending
    case accepted
    case declined
    case cancelled
    case expired
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
    var modality: DuoTeamModality
    var createdByUid: String
    var createdByName: String
    var members: [DuoTeamMember]
    var createdAt: Date
    var updatedAt: Date
    /// Confirma que o criador aceitou o aviso de privacidade (sem localização em tempo real).
    var privacyAcknowledged: Bool

    var memberCount: Int { members.count }

    var subtitle: String {
        "\(modality.rawValue) · \(memberCount) \(memberCount == 1 ? "pessoa" : "pessoas")"
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
        let base: String
        if callName.isEmpty || callName.caseInsensitiveCompare(name) == .orderedSame {
            base = name
        } else {
            base = "\(name) · “\(callName)”"
        }
        let flag = flagEmoji
        return flag == "🏳️" ? base : "\(flag) \(base)"
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

    /// Mensagens do chat de equipe expiram após 24 horas.
    var isExpired: Bool {
        Date().timeIntervalSince(createdAt) >= DuoTeamChatPolicy.messageTTL
    }
}

enum DuoTeamChatPolicy {
    static let messageTTL: TimeInterval = 24 * 60 * 60

    static let purposeNotice =
        "O chat é só para marcar atividades físicas. As mensagens expiram em 24 horas."
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

    O chat é exclusivo para marcar atividades físicas. As mensagens ficam disponíveis por 24 horas e depois expiram.

    Você precisa confirmar isso antes de continuar.
    """
}
