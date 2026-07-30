import SwiftUI
import Foundation

enum Biotype: String, CaseIterable, Codable, Identifiable {
    case ectomorph = "Ectomorfo"
    case mesomorph = "Mesomorfo"
    case endomorph = "Endomorfo"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .ectomorph: return "Metabolismo acelerado, dificuldade em ganhar massa"
        case .mesomorph: return "Facilidade em ganhar músculo e perder gordura"
        case .endomorph: return "Tendência a acumular gordura, ganho de massa moderado"
        }
    }

    /// Como identificar o biotipo no espelho e no dia a dia.
    var identificationGuide: String {
        switch self {
        case .ectomorph:
            return "Corpo magro, ombros e quadris estreitos, pulsos e tornozelos finos. Ganha pouco peso mesmo comendo bastante."
        case .mesomorph:
            return "Ombros largos, cintura marcada e estrutura atlética. Ganha músculo e perde gordura com relativa facilidade."
        case .endomorph:
            return "Estrutura mais arredondada, acumula gordura com facilidade (cintura e quadril). Ganha peso mais rápido que os outros biotipos."
        }
    }

    var icon: String {
        switch self {
        case .ectomorph: return "figure.walk"
        case .mesomorph: return "figure.strengthtraining.traditional"
        case .endomorph: return "figure.arms.open"
        }
    }
    var color: Color {
        switch self {
        case .ectomorph:
            return .blue
        case .mesomorph:
            return .green
        case .endomorph:
            return .orange
        }
    }
}

enum FitnessGoal: String, CaseIterable, Codable, Identifiable {
    case muscleGain = "Ganho de Massa"
    case fatLoss = "Perda de Gordura"
    case maintenance = "Manutenção"
    case endurance = "Resistência"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .muscleGain: return "dumbbell.fill"
        case .fatLoss: return "flame.fill"
        case .maintenance: return "equal.circle.fill"
        case .endurance: return "heart.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .muscleGain:
            return .green

        case .fatLoss:
            return .red

        case .maintenance:
            return .blue

        case .endurance:
            return .orange
        }
    }
}

enum Gender: String, CaseIterable, Codable, Identifiable, Hashable {
    case male = "Masculino"
    case female = "Feminino"

    var id: String { rawValue }
}

/// Circunferências corporais em centímetros (valores opcionais).
struct BodyMeasurements: Codable, Equatable {
    var neckCm: Double?
    var shouldersCm: Double?
    var chestCm: Double?
    var rightArmCm: Double?
    var leftArmCm: Double?
    var waistCm: Double?
    var abdomenCm: Double?
    var hipCm: Double?
    var rightThighCm: Double?
    var leftThighCm: Double?
    var rightCalfCm: Double?
    var leftCalfCm: Double?
    var measuredAt: Date?

    static let empty = BodyMeasurements()
    static let comparisonIntervalDays = 30

    var hasAnyValue: Bool {
        labeledValues.contains { $0.value != nil }
    }

    var labeledValues: [(label: String, value: Double?)] {
        [
            ("Pescoço", neckCm),
            ("Ombros", shouldersCm),
            ("Peito", chestCm),
            ("Braço direito", rightArmCm),
            ("Braço esquerdo", leftArmCm),
            ("Cintura", waistCm),
            ("Abdômen", abdomenCm),
            ("Quadril", hipCm),
            ("Coxa direita", rightThighCm),
            ("Coxa esquerda", leftThighCm),
            ("Panturrilha direita", rightCalfCm),
            ("Panturrilha esquerda", leftCalfCm)
        ]
    }

    func reportLines(dateFormatter: DateFormatter) -> [String] {
        guard hasAnyValue else { return [] }

        var lines = ["", "Medidas corporais:"]
        if let measuredAt {
            lines.append("Atualizado em: \(dateFormatter.string(from: measuredAt))")
        }

        for (label, value) in labeledValues {
            guard let value else { continue }
            lines.append("\(label): \(Self.formatCm(value))")
        }
        return lines
    }

    static func formatCm(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) cm"
            : String(format: "%.1f cm", value)
    }

    static func formatDelta(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        let formatted = value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
        return "\(sign)\(formatted) cm"
    }

    /// Compara medidas anteriores com as atuais e retorna apenas as que variaram.
    static func changes(
        from previous: BodyMeasurements,
        to current: BodyMeasurements
    ) -> [BodyMeasurementChange] {
        zip(previous.labeledValues, current.labeledValues).compactMap { prev, curr in
            guard prev.label == curr.label,
                  let before = prev.value,
                  let after = curr.value else { return nil }
            let delta = after - before
            guard abs(delta) >= 0.05 else { return nil }
            return BodyMeasurementChange(
                label: prev.label,
                previous: before,
                current: after,
                delta: delta
            )
        }
    }

    static func daysBetween(_ from: Date, _ to: Date = .now) -> Int {
        Calendar.current.dateComponents([.day], from: from, to: to).day ?? 0
    }

    /// True quando a medição anterior tem pelo menos 30 dias.
    static func isEligibleForPeriodComparison(
        previous: BodyMeasurements,
        referenceDate: Date = .now
    ) -> Bool {
        guard let measuredAt = previous.measuredAt, previous.hasAnyValue else { return false }
        return daysBetween(measuredAt, referenceDate) >= comparisonIntervalDays
    }
}

struct BodyMeasurementChange: Identifiable, Equatable, Codable {
    let label: String
    let previous: Double
    let current: Double
    let delta: Double

    var id: String { label }

    var directionLabel: String {
        if delta > 0 { return "Aumentou" }
        if delta < 0 { return "Diminuiu" }
        return "Estável"
    }
}

struct BodyMeasurementComparison: Equatable {
    let previous: BodyMeasurements
    let current: BodyMeasurements
    let changes: [BodyMeasurementChange]
    let periodDays: Int

    var hasChanges: Bool { !changes.isEmpty }

    static func make(
        previous: BodyMeasurements,
        current: BodyMeasurements
    ) -> BodyMeasurementComparison? {
        guard previous.hasAnyValue, current.hasAnyValue else { return nil }
        let days: Int = {
            if let from = previous.measuredAt, let to = current.measuredAt {
                return BodyMeasurements.daysBetween(from, to)
            }
            if let from = previous.measuredAt {
                return BodyMeasurements.daysBetween(from)
            }
            return BodyMeasurements.comparisonIntervalDays
        }()

        return BodyMeasurementComparison(
            previous: previous,
            current: current,
            changes: BodyMeasurements.changes(from: previous, to: current),
            periodDays: max(days, 0)
        )
    }

    func reportLines(dateFormatter: DateFormatter) -> [String] {
        var lines = [
            "",
            "Comparativo de medidas (\(periodDays) dia(s)):"
        ]

        if let from = previous.measuredAt, let to = current.measuredAt {
            lines.append("De \(dateFormatter.string(from: from)) até \(dateFormatter.string(from: to))")
        }

        if changes.isEmpty {
            lines.append("Nenhuma medida variou no período.")
            return lines
        }

        lines.append("Medidas que variaram:")
        for change in changes {
            lines.append(
                "• \(change.label): \(BodyMeasurements.formatCm(change.previous)) → \(BodyMeasurements.formatCm(change.current)) (\(BodyMeasurements.formatDelta(change.delta)))"
            )
        }
        return lines
    }
}

struct UserProfile: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var displayName: String
    var email: String
    var personalTrainerName: String
    var personalTrainerEmail: String
    /// Usuário declarou que possui personal trainer (libera edição dos campos).
    var usesPersonalTrainer: Bool
    var nutritionistName: String
    var nutritionistEmail: String
    /// Usuário declarou que possui nutricionista (libera edição dos campos).
    var usesNutritionist: Bool
    var biotype: Biotype
    var goal: FitnessGoal
    var gender: Gender
    var weight: Double
    var height: Double
    var age: Int
    var caloricDeficit: Int
    var bodyMeasurements: BodyMeasurements
    /// Snapshot da medição anterior (usado no comparativo de 30 dias).
    var previousBodyMeasurements: BodyMeasurements?
    var createdAt: Date
    /// Última alteração local/remota — usado para não sobrescrever dados novos com Firestore antigo.
    var updatedAt: Date

    static let maxCaloricDeficit = 3_000

    init(
        id: String = UUID().uuidString,
        name: String,
        email: String,
        displayName: String = "",
        personalTrainerName: String = "",
        personalTrainerEmail: String = "",
        usesPersonalTrainer: Bool = false,
        nutritionistName: String = "",
        nutritionistEmail: String = "",
        usesNutritionist: Bool = false,
        biotype: Biotype = .mesomorph,
        goal: FitnessGoal = .muscleGain,
        gender: Gender = .male,
        weight: Double = 75,
        height: Double = 175,
        age: Int = 28,
        caloricDeficit: Int = 400,
        bodyMeasurements: BodyMeasurements = .empty,
        previousBodyMeasurements: BodyMeasurements? = nil,
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.email = email
        self.personalTrainerName = personalTrainerName
        self.personalTrainerEmail = personalTrainerEmail
        self.usesPersonalTrainer = usesPersonalTrainer
        self.nutritionistName = nutritionistName
        self.nutritionistEmail = nutritionistEmail
        self.usesNutritionist = usesNutritionist
        self.biotype = biotype
        self.goal = goal
        self.gender = gender
        self.weight = weight
        self.height = height
        self.age = age
        self.caloricDeficit = caloricDeficit
        self.bodyMeasurements = bodyMeasurements
        self.previousBodyMeasurements = previousBodyMeasurements
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        email = try container.decode(String.self, forKey: .email)
        personalTrainerName = try container.decodeIfPresent(String.self, forKey: .personalTrainerName) ?? ""
        personalTrainerEmail = try container.decodeIfPresent(String.self, forKey: .personalTrainerEmail) ?? ""
        nutritionistName = try container.decodeIfPresent(String.self, forKey: .nutritionistName) ?? ""
        nutritionistEmail = try container.decodeIfPresent(String.self, forKey: .nutritionistEmail) ?? ""
        // Migração: se já havia e-mail cadastrado, assume que o usuário possui o profissional.
        usesPersonalTrainer = try container.decodeIfPresent(Bool.self, forKey: .usesPersonalTrainer)
            ?? !personalTrainerEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        usesNutritionist = try container.decodeIfPresent(Bool.self, forKey: .usesNutritionist)
            ?? !nutritionistEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        biotype = try container.decode(Biotype.self, forKey: .biotype)
        goal = try container.decode(FitnessGoal.self, forKey: .goal)
        gender = try container.decodeIfPresent(Gender.self, forKey: .gender) ?? .male
        weight = try container.decode(Double.self, forKey: .weight)
        height = try container.decode(Double.self, forKey: .height)
        age = try container.decode(Int.self, forKey: .age)
        caloricDeficit = try container.decodeIfPresent(Int.self, forKey: .caloricDeficit) ?? 400
        bodyMeasurements = try container.decodeIfPresent(BodyMeasurements.self, forKey: .bodyMeasurements) ?? .empty
        previousBodyMeasurements = try container.decodeIfPresent(BodyMeasurements.self, forKey: .previousBodyMeasurements)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, displayName, email, personalTrainerName, personalTrainerEmail, usesPersonalTrainer
        case nutritionistName, nutritionistEmail, usesNutritionist
        case biotype, goal, gender, weight, height, age, caloricDeficit
        case bodyMeasurements, previousBodyMeasurements, createdAt, updatedAt
    }

    var latestMeasurementComparison: BodyMeasurementComparison? {
        guard let previous = previousBodyMeasurements else { return nil }
        return BodyMeasurementComparison.make(previous: previous, current: bodyMeasurements)
    }

    var hasPersonalTrainer: Bool {
        usesPersonalTrainer
            && !personalTrainerEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasNutritionist: Bool {
        usesNutritionist
            && !nutritionistEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Nome usado em saudações e mensagens do app.
    var greetingName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return name.components(separatedBy: " ").first ?? name
    }

    /// Nome exibido no perfil e cabeçalhos.
    var shownName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? name : trimmed
    }

    /// Taxa Metabólica Basal (Mifflin-St Jeor)
    var basalMetabolicRate: Int {
        let base = (10 * weight) + (6.25 * height) - (5 * Double(age))
        let bmr = gender == .male ? base + 5 : base - 161
        return max(Int(bmr.rounded()), 1000)
    }

    /// Gasto calórico diário estimado (TDEE) sem ajuste de objetivo
    var estimatedTDEE: Int {
        var tdee = Double(basalMetabolicRate) * 1.55

        switch biotype {
        case .ectomorph: tdee *= 1.10
        case .endomorph: tdee *= 0.90
        case .mesomorph: break
        }

        return max(Int(tdee.rounded()), 1200)
    }

    /// Meta calórica diária considerando objetivo e déficit configurado
    var dailyCalorieTarget: Int {
        switch goal {
        case .fatLoss:
            return max(estimatedTDEE - caloricDeficit, 1200)
        case .muscleGain:
            return estimatedTDEE + 400
        case .endurance:
            return estimatedTDEE + 200
        case .maintenance:
            return max(estimatedTDEE - caloricDeficit, 1200)
        }
    }

    /// Déficit efetivo aplicado sobre o TDEE
    var effectiveCaloricDeficit: Int {
        max(estimatedTDEE - dailyCalorieTarget, 0)
    }

    /// Estimativa de perda de peso semanal (1 kg ≈ 7.700 kcal)
    var estimatedWeeklyWeightLoss: Double {
        guard effectiveCaloricDeficit > 0 else { return 0 }
        return (Double(effectiveCaloricDeficit) * 7.0) / 7_700.0
    }

    var bmi: Double {
        let heightM = height / 100
        guard heightM > 0 else { return 0 }
        return weight / (heightM * heightM)
    }
}
