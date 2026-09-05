import Foundation

// MARK: - Privacy (separado do Duo)

enum CoachPrivacy {
    static let clearNotice = """
    O HealthFit Coach conecta aluno e profissional (personal / nutricionista) dentro do mesmo app.

    • O profissional pode ver e prescrever treinos de musculação e/ou cardápio do aluno vinculado.
    • Relatórios de adesão (treinos concluídos) podem ser compartilhados com o coach.
    • Chat 1:1 só existe com vínculo ativo — não é o Duo nem localização em tempo real.
    • Mensagens do chat ficam disponíveis por 48 horas e depois são apagadas do app.
    • Cópias de registro (logs) das mensagens são mantidas por até 6 meses para segurança e conformidade legal.
    • Cardio e demais modalidades do aluno continuam privados e livres.
    • O aluno precisa do plano Fit ou superior para receber fichas, dietas e chat.
    """

    static let shortLabel = "Vínculo profissional para fichas, dietas e chat (sem mapa ao vivo)."
}

/// Política do chat Coach (personal / nutri).
enum CoachChatPolicy {
    /// Mensagens visíveis no app por 48 horas.
    static let messageTTL: TimeInterval = 48 * 60 * 60
    /// Retenção dos registros/logs de mensagens (meses).
    static let registryRetentionMonths = 6

    static let purposeNotice =
        "Mensagens do chat ficam 48 horas e depois são apagadas. Registros de segurança são mantidos conforme a política."

    static func expiresAt(from createdAt: Date = .now) -> Date {
        createdAt.addingTimeInterval(messageTTL)
    }

    static func registryExpiresAt(from createdAt: Date = .now) -> Date {
        Calendar.current.date(byAdding: .month, value: registryRetentionMonths, to: createdAt)
            ?? createdAt.addingTimeInterval(TimeInterval(registryRetentionMonths) * 30 * 24 * 3600)
    }
}

enum CoachPreferences {
    static let consentKey = "healthFitCoach.consent.v1"

    static var hasConsent: Bool {
        UserDefaults.standard.bool(forKey: consentKey)
    }

    static func grantConsent() {
        UserDefaults.standard.set(true, forKey: consentKey)
    }
}

// MARK: - Profession & status

enum CoachProfession: String, CaseIterable, Codable, Identifiable, Hashable {
    case personal
    case nutritionist

    var id: String { rawValue }

    var title: String {
        switch self {
        case .personal: return "Personal trainer"
        case .nutritionist: return "Nutricionista"
        }
    }

    var credentialLabel: String {
        switch self {
        case .personal: return "CREF"
        case .nutritionist: return "CRN"
        }
    }

    var icon: String {
        switch self {
        case .personal: return "figure.strengthtraining.traditional"
        case .nutritionist: return "leaf.fill"
        }
    }
}

enum CoachLinkStatus: String, Codable, Equatable {
    case pending
    case active
    case ended
    case blockedPlan

    var displayLabel: String {
        switch self {
        case .pending: return "Pendente"
        case .active: return "Ativo"
        case .ended: return "Encerrado"
        case .blockedPlan: return "Aguardando plano Fit+"
        }
    }
}

enum CoachInviteStatus: String, Codable, Equatable {
    case pending
    case accepted
    case declined
    case cancelled
    case expired
}

// MARK: - Professional profile

struct CoachProfessionalProfile: Identifiable, Codable, Equatable, Hashable {
    var id: String { uid }
    var uid: String
    var displayName: String
    var email: String
    var photoURL: String?
    var professions: [CoachProfession]
    var cref: String?
    var crn: String?
    var city: String
    var stateCode: String
    var bio: String
    var specialties: [String]
    var isDirectoryVisible: Bool
    var maxStudents: Int
    var privacyAcknowledged: Bool
    var createdAt: Date
    var updatedAt: Date

    static let defaultMaxStudents = 25

    var credentialSummary: String {
        var parts: [String] = []
        if let cref, !cref.isEmpty { parts.append("CREF \(cref)") }
        if let crn, !crn.isEmpty { parts.append("CRN \(crn)") }
        return parts.isEmpty ? "Credencial pendente" : parts.joined(separator: " · ")
    }

    var locationLabel: String {
        let cityTrim = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let stateTrim = stateCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if cityTrim.isEmpty && stateTrim.isEmpty { return "Local não informado" }
        if stateTrim.isEmpty { return cityTrim }
        if cityTrim.isEmpty { return stateTrim }
        return "\(cityTrim) / \(stateTrim)"
    }

    /// Formação / áreas de atuação (ex.: Personal trainer · Nutricionista).
    var formationSummary: String {
        let titles = professions.map(\.title)
        return titles.isEmpty ? "Profissional" : titles.joined(separator: " · ")
    }

    /// Credencial principal por profissão (CREF e/ou CRN).
    var credentialLines: [String] {
        var lines: [String] = []
        if professions.contains(.personal), let cref, !cref.isEmpty {
            lines.append("CREF \(cref)")
        }
        if professions.contains(.nutritionist), let crn, !crn.isEmpty {
            lines.append("CRN \(crn)")
        }
        return lines
    }

    init(
        uid: String,
        displayName: String,
        email: String,
        photoURL: String? = nil,
        professions: [CoachProfession],
        cref: String? = nil,
        crn: String? = nil,
        city: String = "",
        stateCode: String = "",
        bio: String = "",
        specialties: [String] = [],
        isDirectoryVisible: Bool = false,
        maxStudents: Int = Self.defaultMaxStudents,
        privacyAcknowledged: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.uid = uid
        self.displayName = displayName
        self.email = email
        self.photoURL = photoURL
        self.professions = professions
        self.cref = cref
        self.crn = crn
        self.city = city
        self.stateCode = stateCode
        self.bio = bio
        self.specialties = specialties
        self.isDirectoryVisible = isDirectoryVisible
        self.maxStudents = maxStudents
        self.privacyAcknowledged = privacyAcknowledged
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Link & invite

struct CoachLink: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var coachUid: String
    var coachName: String
    var coachPhotoURL: String?
    var studentUid: String
    var studentName: String
    var studentPhotoURL: String?
    var profession: CoachProfession
    var status: CoachLinkStatus
    var memberUids: [String]
    var createdAt: Date
    var updatedAt: Date
    var activatedAt: Date?

    var isActiveLike: Bool {
        status == .active || status == .blockedPlan
    }
}

struct CoachInvite: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var code: String
    var fromUid: String
    var fromName: String
    var toUid: String?
    var toName: String?
    var toEmail: String?
    var profession: CoachProfession
    var status: CoachInviteStatus
    var linkId: String?
    var createdAt: Date
    var expiresAt: Date
}

// MARK: - Chat

struct CoachChatMessage: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var linkId: String
    var senderUid: String
    var senderName: String
    var text: String
    var createdAt: Date
    /// Quando a mensagem some do chat ativo (padrão: createdAt + 48h).
    var expiresAt: Date?
    /// Destinatário recebeu no aparelho (listener / app aberto).
    var deliveredAt: Date?
    /// Destinatário abriu o chat e leu.
    var readAt: Date?

    static let maxLength = 2_000
    /// Marca mensagens Coach em collection group / Functions.
    static let channel = "coachChat"

    enum ReceiptStatus: Equatable {
        case sent
        case delivered
        case read
    }

    var receiptStatus: ReceiptStatus {
        if readAt != nil { return .read }
        if deliveredAt != nil { return .delivered }
        return .sent
    }

    var effectiveExpiresAt: Date {
        expiresAt ?? createdAt.addingTimeInterval(CoachChatPolicy.messageTTL)
    }

    var isExpired: Bool {
        Date() >= effectiveExpiresAt
    }

    init(
        id: String,
        linkId: String,
        senderUid: String,
        senderName: String,
        text: String,
        createdAt: Date,
        expiresAt: Date? = nil,
        deliveredAt: Date? = nil,
        readAt: Date? = nil
    ) {
        self.id = id
        self.linkId = linkId
        self.senderUid = senderUid
        self.senderName = senderName
        self.text = text
        self.createdAt = createdAt
        self.expiresAt = expiresAt ?? CoachChatPolicy.expiresAt(from: createdAt)
        self.deliveredAt = deliveredAt
        self.readAt = readAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        linkId = try container.decode(String.self, forKey: .linkId)
        senderUid = try container.decode(String.self, forKey: .senderUid)
        senderName = try container.decode(String.self, forKey: .senderName)
        text = try container.decode(String.self, forKey: .text)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        deliveredAt = try container.decodeIfPresent(Date.self, forKey: .deliveredAt)
        readAt = try container.decodeIfPresent(Date.self, forKey: .readAt)
    }
}

// MARK: - Assigned workout envelope

struct CoachAssignedWorkout: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var linkId: String
    var coachUid: String
    var coachName: String
    var studentUid: String
    var sheet: WorkoutSheet
    var publishedAt: Date
    var updatedAt: Date
    var isActive: Bool
}

// MARK: - Helpers

enum CoachCodeGenerator {
    static func makeInviteCode(length: Int = 6) -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<length).map { _ in alphabet.randomElement()! })
    }

    static func makeLinkId(coachUid: String, studentUid: String, profession: CoachProfession) -> String {
        "\(coachUid)_\(studentUid)_\(profession.rawValue)"
    }
}
