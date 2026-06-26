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

    var icon: String {
        switch self {
        case .ectomorph: return "figure.walk"
        case .mesomorph: return "figure.strengthtraining.traditional"
        case .endomorph: return "figure.arms.open"
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
}

enum Gender: String, CaseIterable, Codable, Identifiable {
    case male = "Masculino"
    case female = "Feminino"

    var id: String { rawValue }
}

struct UserProfile: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var email: String
    var biotype: Biotype
    var goal: FitnessGoal
    var gender: Gender
    var weight: Double
    var height: Double
    var age: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        email: String,
        biotype: Biotype = .mesomorph,
        goal: FitnessGoal = .muscleGain,
        gender: Gender = .male,
        weight: Double = 75,
        height: Double = 175,
        age: Int = 28,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.biotype = biotype
        self.goal = goal
        self.gender = gender
        self.weight = weight
        self.height = height
        self.age = age
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decode(String.self, forKey: .email)
        biotype = try container.decode(Biotype.self, forKey: .biotype)
        goal = try container.decode(FitnessGoal.self, forKey: .goal)
        gender = try container.decodeIfPresent(Gender.self, forKey: .gender) ?? .male
        weight = try container.decode(Double.self, forKey: .weight)
        height = try container.decode(Double.self, forKey: .height)
        age = try container.decode(Int.self, forKey: .age)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, email, biotype, goal, gender, weight, height, age, createdAt
    }

    /// Taxa Metabólica Basal (Mifflin-St Jeor)
    var basalMetabolicRate: Int {
        let base = (10 * weight) + (6.25 * height) - (5 * Double(age))
        let bmr = gender == .male ? base + 5 : base - 161
        return max(Int(bmr.rounded()), 1000)
    }

    /// Gasto calórico diário estimado com atividade moderada e ajuste por biotipo/objetivo
    var dailyCalorieTarget: Int {
        var tdee = Double(basalMetabolicRate) * 1.55

        switch biotype {
        case .ectomorph: tdee *= 1.10
        case .endomorph: tdee *= 0.90
        case .mesomorph: break
        }

        switch goal {
        case .muscleGain: tdee += 400
        case .fatLoss: tdee -= 400
        case .endurance: tdee += 200
        case .maintenance: break
        }

        return max(Int(tdee.rounded()), 1200)
    }

    var bmi: Double {
        let heightM = height / 100
        guard heightM > 0 else { return 0 }
        return weight / (heightM * heightM)
    }
}
