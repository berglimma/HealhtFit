import Foundation

// MARK: - Anamnese

struct NutritionAnamnesis: Codable, Equatable, Hashable {
    var chiefComplaint: String
    var medicalHistory: String
    var medications: String
    var allergies: String
    var surgeries: String
    var familyHistory: String
    var digestiveIssues: String
    var waterIntakeLiters: Double
    var alcoholUse: String
    var smoking: String
    var physicalActivity: String
    var stressLevel: Int
    var sleepHours: Double
    var bowelFunction: String
    var menstrualNotes: String
    var foodAversions: String
    var eatingOutFrequency: String
    var supplementsInUse: String
    var previousDiets: String
    var notes: String
    var updatedAt: Date
    var lastUpdatedByUid: String?
    var lastUpdatedByName: String?

    static let empty = NutritionAnamnesis(
        chiefComplaint: "",
        medicalHistory: "",
        medications: "",
        allergies: "",
        surgeries: "",
        familyHistory: "",
        digestiveIssues: "",
        waterIntakeLiters: 2,
        alcoholUse: "",
        smoking: "Não",
        physicalActivity: "",
        stressLevel: 5,
        sleepHours: 7,
        bowelFunction: "",
        menstrualNotes: "",
        foodAversions: "",
        eatingOutFrequency: "",
        supplementsInUse: "",
        previousDiets: "",
        notes: "",
        updatedAt: .distantPast,
        lastUpdatedByUid: nil,
        lastUpdatedByName: nil
    )

    var completionPercent: Int {
        let fields: [String] = [
            chiefComplaint, medicalHistory, medications, allergies, surgeries,
            familyHistory, digestiveIssues, alcoholUse, smoking, physicalActivity,
            bowelFunction, foodAversions, eatingOutFrequency, previousDiets
        ]
        let filled = fields.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        return Int((Double(filled) / Double(fields.count) * 100).rounded())
    }
}

// MARK: - Questionnaires

enum NutritionQuestionnaireKind: String, CaseIterable, Codable, Identifiable, Hashable {
    case healthGeneral
    case metabolicTracking
    case eatingPattern
    case sleepType
    case hydrationHabits
    case emotionalEating

    var id: String { rawValue }

    var title: String {
        switch self {
        case .healthGeneral: return "Questionário de saúde"
        case .metabolicTracking: return "Rastreamento metabólico"
        case .eatingPattern: return "Padrão alimentar"
        case .sleepType: return "Tipo de sono"
        case .hydrationHabits: return "Hidratação e hábitos"
        case .emotionalEating: return "Fome emocional"
        }
    }

    var icon: String {
        switch self {
        case .healthGeneral: return "heart.text.square.fill"
        case .metabolicTracking: return "flame.fill"
        case .eatingPattern: return "fork.knife"
        case .sleepType: return "moon.zzz.fill"
        case .hydrationHabits: return "drop.fill"
        case .emotionalEating: return "brain.head.profile"
        }
    }

    var detail: String {
        switch self {
        case .healthGeneral: return "Histórico clínico, sintomas e medicamentos."
        case .metabolicTracking: return "Energia, fome, retenção e sinais metabólicos."
        case .eatingPattern: return "Horários, porções e frequência de refeições."
        case .sleepType: return "Qualidade, duração e rotina de sono."
        case .hydrationHabits: return "Água, café, álcool e líquidos no dia."
        case .emotionalEating: return "Gatilhos emocionais e compulsão alimentar."
        }
    }

    var questions: [NutritionQuestion] {
        switch self {
        case .healthGeneral:
            return [
                .init(id: "q1", prompt: "Possui alguma condição de saúde já acompanhada por um médico?"),
                .init(id: "q2", prompt: "Usa medicamentos contínuos? Quais?"),
                .init(id: "q3", prompt: "Tem alergias alimentares ou medicamentosas?"),
                .init(id: "q4", prompt: "Já fez exames recentes (glicemia, lipídios, TSH)?"),
                .init(id: "q5", prompt: "Há sintomas gastrointestinais frequentes?")
            ]
        case .metabolicTracking:
            return [
                .init(id: "m1", prompt: "Como está sua energia ao longo do dia?"),
                .init(id: "m2", prompt: "Sente fome excessiva ou queda de energia após comer?"),
                .init(id: "m3", prompt: "Há retenção de líquido ou inchaço?"),
                .init(id: "m4", prompt: "Como está o funcionamento intestinal?"),
                .init(id: "m5", prompt: "Percebe sudorese, palpitações ou frio nas extremidades?")
            ]
        case .eatingPattern:
            return [
                .init(id: "e1", prompt: "Quantas refeições faz por dia?"),
                .init(id: "e2", prompt: "Costuma pular café da manhã ou jantar?"),
                .init(id: "e3", prompt: "Come fora de casa com que frequência?"),
                .init(id: "e4", prompt: "Há horários irregulares de alimentação?"),
                .init(id: "e5", prompt: "Consome doces ou ultraprocessados com que frequência?")
            ]
        case .sleepType:
            return [
                .init(id: "s1", prompt: "Quantas horas dorme por noite, em média?"),
                .init(id: "s2", prompt: "Tem dificuldade para dormir ou acordar?"),
                .init(id: "s3", prompt: "Usa telas perto da hora de dormir?"),
                .init(id: "s4", prompt: "Acorda descansado na maior parte dos dias?"),
                .init(id: "s5", prompt: "Ronca ou suspeita de apneia do sono?")
            ]
        case .hydrationHabits:
            return [
                .init(id: "h1", prompt: "Quantos litros de água bebe por dia?"),
                .init(id: "h2", prompt: "Quantas xícaras de café/chá com cafeína?"),
                .init(id: "h3", prompt: "Consome bebidas alcoólicas? Com que frequência?"),
                .init(id: "h4", prompt: "Bebe refrigerante ou suco industrializado?"),
                .init(id: "h5", prompt: "Sente sede com frequência ao longo do dia?")
            ]
        case .emotionalEating:
            return [
                .init(id: "x1", prompt: "Come por ansiedade, estresse ou tédio?"),
                .init(id: "x2", prompt: "Há episódios de compulsão alimentar?"),
                .init(id: "x3", prompt: "Come à noite sem fome física?"),
                .init(id: "x4", prompt: "Associa comida a recompensa ou conforto?"),
                .init(id: "x5", prompt: "Já tentou estratégias para lidar com gatilhos emocionais?")
            ]
        }
    }
}

struct NutritionQuestion: Identifiable, Hashable {
    let id: String
    let prompt: String
}

struct NutritionQuestionnaireResponse: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var kindRaw: String
    var answers: [String: String]
    var updatedAt: Date
    var completedByUid: String?
    var completedByName: String?

    var kind: NutritionQuestionnaireKind {
        get { NutritionQuestionnaireKind(rawValue: kindRaw) ?? .healthGeneral }
        set { kindRaw = newValue.rawValue }
    }

    var answeredCount: Int {
        answers.values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    var isComplete: Bool {
        answeredCount >= kind.questions.count
    }

    static func blank(kind: NutritionQuestionnaireKind) -> NutritionQuestionnaireResponse {
        NutritionQuestionnaireResponse(
            id: UUID(),
            kindRaw: kind.rawValue,
            answers: [:],
            updatedAt: .now,
            completedByUid: nil,
            completedByName: nil
        )
    }
}

// MARK: - Goals

enum NutritionGoalStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case completed
    case paused

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active: return "Ativa"
        case .completed: return "Concluída"
        case .paused: return "Pausada"
        }
    }
}

enum NutritionGoalAuthor: String, Codable {
    case student
    case coach
}

struct NutritionGoal: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var title: String
    var detail: String
    var targetDate: Date?
    var statusRaw: String
    var authorRaw: String
    var syncedWithCoach: Bool
    var createdAt: Date
    var updatedAt: Date

    var status: NutritionGoalStatus {
        get { NutritionGoalStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var author: NutritionGoalAuthor {
        get { NutritionGoalAuthor(rawValue: authorRaw) ?? .student }
        set { authorRaw = newValue.rawValue }
    }

    static func make(
        title: String,
        detail: String,
        targetDate: Date?,
        author: NutritionGoalAuthor,
        synced: Bool
    ) -> NutritionGoal {
        let now = Date()
        return NutritionGoal(
            id: UUID(),
            title: title,
            detail: detail,
            targetDate: targetDate,
            statusRaw: NutritionGoalStatus.active.rawValue,
            authorRaw: author.rawValue,
            syncedWithCoach: synced,
            createdAt: now,
            updatedAt: now
        )
    }
}

// MARK: - Check-in

struct NutritionCheckIn: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var date: Date
    var weightKg: Double?
    var adherence: Int
    var hunger: Int
    var energy: Int
    var notes: String
    var createdAt: Date

    static func make(
        weightKg: Double?,
        adherence: Int,
        hunger: Int,
        energy: Int,
        notes: String
    ) -> NutritionCheckIn {
        let now = Date()
        return NutritionCheckIn(
            id: UUID(),
            date: Calendar.current.startOfDay(for: now),
            weightKg: weightKg,
            adherence: adherence,
            hunger: hunger,
            energy: energy,
            notes: notes,
            createdAt: now
        )
    }
}

// MARK: - Bundle (sync payload)

struct NutritionCareBundle: Codable, Equatable {
    var anamnesis: NutritionAnamnesis
    var questionnaires: [NutritionQuestionnaireResponse]
    var goals: [NutritionGoal]
    var checkIns: [NutritionCheckIn]
    var updatedAt: Date

    static let empty = NutritionCareBundle(
        anamnesis: .empty,
        questionnaires: [],
        goals: [],
        checkIns: [],
        updatedAt: .distantPast
    )
}
