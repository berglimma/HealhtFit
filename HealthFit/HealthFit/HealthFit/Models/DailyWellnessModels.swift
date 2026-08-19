import Foundation
import SwiftUI

enum SleepAssessment: Equatable {
    case unregulated
    case needsMore
    case ideal
    case aboveRecommended

    var title: String {
        switch self {
        case .unregulated: return "Sono não regulado"
        case .needsMore: return "Precisa dormir mais"
        case .ideal: return "Sono ideal"
        case .aboveRecommended: return "Sono prolongado"
        }
    }

    var message: String {
        switch self {
        case .unregulated:
            return "Você dormiu menos de 5 horas. Seu sono não está regulado — priorize descanso para recuperar melhor dos treinos."
        case .needsMore:
            return "Você precisa dormir um pouco mais. O ideal é entre 7 e 9 horas por noite."
        case .ideal:
            return "Seu sono está ideal! Manter entre 7 e 9 horas ajuda na recuperação muscular e no bem-estar."
        case .aboveRecommended:
            return "Você dormiu mais de 9 horas. Descanso extra pode ajudar na recuperação."
        }
    }

    var icon: String {
        switch self {
        case .unregulated: return "moon.zzz.fill"
        case .needsMore: return "bed.double.fill"
        case .ideal: return "checkmark.circle.fill"
        case .aboveRecommended: return "moon.stars.fill"
        }
    }

    var color: Color {
        switch self {
        case .unregulated: return .red
        case .needsMore: return .orange
        case .ideal: return AppTheme.accent
        case .aboveRecommended: return .blue
        }
    }

    static func evaluate(hours: Double) -> SleepAssessment {
        switch hours {
        case ..<5: return .unregulated
        case 5..<7: return .needsMore
        case 7...9: return .ideal
        default: return .aboveRecommended
        }
    }
}

enum WaterServing {
    static let glassML = 250
    static let bottleML = 500
    /// Hard ceiling for daily water goal and logged intake (10 L).
    static let maxDailyIntakeML = 10_000
}

struct DailyWellnessEntry: Codable, Equatable {
    var dayKey: String
    var sleepHours: Double?
    var waterIntakeMl: Int
    var energyDrinksCount: Int
    var preWorkoutCount: Int
    /// Suplementos ingeridos neste dia.
    var supplementIntakes: [SupplementIntakeEntry]
    /// Última alteração na lista de suplementos (para merge na nuvem).
    var supplementsUpdatedAt: Date?
    /// Última vez que o sono foi registrado neste dia.
    var sleepUpdatedAt: Date?
    /// Última vez que a água foi registrada neste dia.
    var waterUpdatedAt: Date?
    /// Dia de descanso declarado pelo usuário (pode marcar a qualquer hora).
    var isRestDay: Bool
    /// Quando o descanso foi marcado (merge na nuvem).
    var restDayMarkedAt: Date?

    static func empty(for date: Date = .now) -> DailyWellnessEntry {
        DailyWellnessEntry(
            dayKey: Self.dayKey(for: date),
            sleepHours: nil,
            waterIntakeMl: 0,
            energyDrinksCount: 0,
            preWorkoutCount: 0,
            supplementIntakes: [],
            supplementsUpdatedAt: nil,
            sleepUpdatedAt: nil,
            waterUpdatedAt: nil,
            isRestDay: false,
            restDayMarkedAt: nil
        )
    }

    static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    init(
        dayKey: String,
        sleepHours: Double? = nil,
        waterIntakeMl: Int = 0,
        energyDrinksCount: Int = 0,
        preWorkoutCount: Int = 0,
        supplementIntakes: [SupplementIntakeEntry] = [],
        supplementsUpdatedAt: Date? = nil,
        sleepUpdatedAt: Date? = nil,
        waterUpdatedAt: Date? = nil,
        isRestDay: Bool = false,
        restDayMarkedAt: Date? = nil
    ) {
        self.dayKey = dayKey
        self.sleepHours = sleepHours
        self.waterIntakeMl = waterIntakeMl
        self.energyDrinksCount = max(0, energyDrinksCount)
        self.preWorkoutCount = max(0, preWorkoutCount)
        self.supplementIntakes = supplementIntakes
        self.supplementsUpdatedAt = supplementsUpdatedAt
        self.sleepUpdatedAt = sleepUpdatedAt
        self.waterUpdatedAt = waterUpdatedAt
        self.isRestDay = isRestDay
        self.restDayMarkedAt = restDayMarkedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dayKey = try container.decode(String.self, forKey: .dayKey)
        sleepHours = try container.decodeIfPresent(Double.self, forKey: .sleepHours)
        waterIntakeMl = try container.decodeIfPresent(Int.self, forKey: .waterIntakeMl) ?? 0
        energyDrinksCount = max(0, try container.decodeIfPresent(Int.self, forKey: .energyDrinksCount) ?? 0)
        preWorkoutCount = max(0, try container.decodeIfPresent(Int.self, forKey: .preWorkoutCount) ?? 0)
        supplementIntakes = try container.decodeIfPresent([SupplementIntakeEntry].self, forKey: .supplementIntakes) ?? []
        supplementsUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .supplementsUpdatedAt)
        sleepUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .sleepUpdatedAt)
        waterUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .waterUpdatedAt)
        isRestDay = try container.decodeIfPresent(Bool.self, forKey: .isRestDay) ?? false
        restDayMarkedAt = try container.decodeIfPresent(Date.self, forKey: .restDayMarkedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dayKey, forKey: .dayKey)
        try container.encodeIfPresent(sleepHours, forKey: .sleepHours)
        try container.encode(waterIntakeMl, forKey: .waterIntakeMl)
        try container.encode(energyDrinksCount, forKey: .energyDrinksCount)
        try container.encode(preWorkoutCount, forKey: .preWorkoutCount)
        try container.encode(supplementIntakes, forKey: .supplementIntakes)
        try container.encodeIfPresent(supplementsUpdatedAt, forKey: .supplementsUpdatedAt)
        try container.encodeIfPresent(sleepUpdatedAt, forKey: .sleepUpdatedAt)
        try container.encodeIfPresent(waterUpdatedAt, forKey: .waterUpdatedAt)
        try container.encode(isRestDay, forKey: .isRestDay)
        try container.encodeIfPresent(restDayMarkedAt, forKey: .restDayMarkedAt)
    }

    private enum CodingKeys: String, CodingKey {
        case dayKey, sleepHours, waterIntakeMl, energyDrinksCount, preWorkoutCount
        case supplementIntakes, supplementsUpdatedAt, sleepUpdatedAt, waterUpdatedAt
        case isRestDay, restDayMarkedAt
    }
}

extension UserProfile {
    /// Recomendação: 35 ml de água por kg de peso corporal por dia (teto 10 L).
    var recommendedDailyWaterML: Int {
        let raw = max(Int((weight * 35).rounded()), 1500)
        return min(raw, WaterServing.maxDailyIntakeML)
    }

    var recommendedDailyWaterLiters: Double {
        Double(recommendedDailyWaterML) / 1000.0
    }

    var recommendedWaterGlasses: Int {
        max(recommendedDailyWaterML / WaterServing.glassML, 6)
    }

    var recommendedWaterBottles: Int {
        max(Int(ceil(Double(recommendedDailyWaterML) / Double(WaterServing.bottleML))), 3)
    }
}
