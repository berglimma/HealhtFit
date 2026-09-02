import Foundation

/// Regras de acesso por plano fora da UI: qual feature cada modalidade exige
/// e o consumo diário de mensagens do IAssistente.
enum PlanAccessRules {
    /// Feature necessária para abrir a modalidade de cardio, ou `nil` se é livre.
    static func requiredFeature(for exercise: CardioExercise) -> AppFeature? {
        if exercise.name == "Corrida" {
            return .fullWorkouts
        }
        if exercise.isWaterSport || exercise.isRowing || exercise.isClimbing || exercise.isFight {
            return .advancedModalities
        }
        return nil
    }

    /// Diários, mapas, inventário e análises de evolução por modalidade.
    static let sportAnalytics: AppFeature = .advancedSportAnalytics
}

// MARK: - Cota diária do IAssistente

/// Conta as mensagens enviadas ao IAssistente no dia para aplicar o limite do plano.
enum AssistantUsageQuota {
    private static let countKey = "healthfit.assistant.dailyMessageCount"
    private static let dayKey = "healthfit.assistant.dailyMessageDay"

    /// Mensagens já enviadas hoje (zera sozinho na virada do dia).
    static var usedToday: Int {
        guard storedDay == currentDay else { return 0 }
        return UserDefaults.standard.integer(forKey: countKey)
    }

    static func remaining(for tier: PlanTier) -> Int? {
        guard let limit = tier.dailyAssistantMessageLimit else { return nil }
        return max(0, limit - usedToday)
    }

    static func canSend(tier: PlanTier) -> Bool {
        guard let remaining = remaining(for: tier) else { return true }
        return remaining > 0
    }

    static func registerSend() {
        let day = currentDay
        if storedDay != day {
            UserDefaults.standard.set(day, forKey: dayKey)
            UserDefaults.standard.set(0, forKey: countKey)
        }
        UserDefaults.standard.set(usedToday + 1, forKey: countKey)
    }

    private static var storedDay: String? {
        UserDefaults.standard.string(forKey: dayKey)
    }

    private static var currentDay: String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: Date())
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}
