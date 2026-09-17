import Foundation
import SwiftUI

enum SleepAssessment: Equatable {
    case unregulated
    case needsMore
    case ideal
    case aboveRecommended

    var title: String {
        switch self {
        case .unregulated: return L10n.tr("wellness.sleep.unregulated.title")
        case .needsMore: return L10n.tr("wellness.sleep.needs_more.title")
        case .ideal: return L10n.tr("wellness.sleep.ideal.title")
        case .aboveRecommended: return L10n.tr("wellness.sleep.above.title")
        }
    }

    var message: String {
        switch self {
        case .unregulated: return L10n.tr("wellness.sleep.unregulated.message")
        case .needsMore: return L10n.tr("wellness.sleep.needs_more.message")
        case .ideal: return L10n.tr("wellness.sleep.ideal.message")
        case .aboveRecommended: return L10n.tr("wellness.sleep.above.message")
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

enum WellnessSleepSource: String, Codable, Equatable {
    case manual
    /// Sono lido do app Saúde (Apple Watch / iPhone Sleep).
    case appleHealth
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
    /// Origem do sono (manual ou Apple Saúde / Watch).
    var sleepSource: WellnessSleepSource?
    /// Início real do sono (HealthKit), quando disponível.
    var sleepBedtime: Date?
    /// Despertar real (HealthKit), quando disponível.
    var sleepWakeTime: Date?
    /// Fases (horas) vindas do Apple Watch / Saúde.
    var sleepDeepHours: Double?
    var sleepREMHours: Double?
    var sleepCoreHours: Double?
    /// Nome da fonte no Saúde (ex.: Apple Watch).
    var sleepHealthSourceName: String?
    /// Última vez que a água foi registrada neste dia.
    var waterUpdatedAt: Date?
    /// Dia de descanso declarado pelo usuário (pode marcar a qualquer hora).
    var isRestDay: Bool
    /// Quando o descanso foi marcado (merge na nuvem).
    var restDayMarkedAt: Date?

    static func empty(for date: Date = .now) -> DailyWellnessEntry {
        empty(forDayKey: dayKey(for: date))
    }

    static func empty(forDayKey dayKey: String) -> DailyWellnessEntry {
        DailyWellnessEntry(
            dayKey: dayKey,
            sleepHours: nil,
            waterIntakeMl: 0,
            energyDrinksCount: 0,
            preWorkoutCount: 0,
            supplementIntakes: [],
            supplementsUpdatedAt: nil,
            sleepUpdatedAt: nil,
            sleepSource: nil,
            sleepBedtime: nil,
            sleepWakeTime: nil,
            sleepDeepHours: nil,
            sleepREMHours: nil,
            sleepCoreHours: nil,
            sleepHealthSourceName: nil,
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
        sleepSource: WellnessSleepSource? = nil,
        sleepBedtime: Date? = nil,
        sleepWakeTime: Date? = nil,
        sleepDeepHours: Double? = nil,
        sleepREMHours: Double? = nil,
        sleepCoreHours: Double? = nil,
        sleepHealthSourceName: String? = nil,
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
        self.sleepSource = sleepSource
        self.sleepBedtime = sleepBedtime
        self.sleepWakeTime = sleepWakeTime
        self.sleepDeepHours = sleepDeepHours
        self.sleepREMHours = sleepREMHours
        self.sleepCoreHours = sleepCoreHours
        self.sleepHealthSourceName = sleepHealthSourceName
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
        sleepSource = try container.decodeIfPresent(WellnessSleepSource.self, forKey: .sleepSource)
        sleepBedtime = try container.decodeIfPresent(Date.self, forKey: .sleepBedtime)
        sleepWakeTime = try container.decodeIfPresent(Date.self, forKey: .sleepWakeTime)
        sleepDeepHours = try container.decodeIfPresent(Double.self, forKey: .sleepDeepHours)
        sleepREMHours = try container.decodeIfPresent(Double.self, forKey: .sleepREMHours)
        sleepCoreHours = try container.decodeIfPresent(Double.self, forKey: .sleepCoreHours)
        sleepHealthSourceName = try container.decodeIfPresent(String.self, forKey: .sleepHealthSourceName)
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
        try container.encodeIfPresent(sleepSource, forKey: .sleepSource)
        try container.encodeIfPresent(sleepBedtime, forKey: .sleepBedtime)
        try container.encodeIfPresent(sleepWakeTime, forKey: .sleepWakeTime)
        try container.encodeIfPresent(sleepDeepHours, forKey: .sleepDeepHours)
        try container.encodeIfPresent(sleepREMHours, forKey: .sleepREMHours)
        try container.encodeIfPresent(sleepCoreHours, forKey: .sleepCoreHours)
        try container.encodeIfPresent(sleepHealthSourceName, forKey: .sleepHealthSourceName)
        try container.encodeIfPresent(waterUpdatedAt, forKey: .waterUpdatedAt)
        try container.encode(isRestDay, forKey: .isRestDay)
        try container.encodeIfPresent(restDayMarkedAt, forKey: .restDayMarkedAt)
    }

    private enum CodingKeys: String, CodingKey {
        case dayKey, sleepHours, waterIntakeMl, energyDrinksCount, preWorkoutCount
        case supplementIntakes, supplementsUpdatedAt, sleepUpdatedAt, sleepSource
        case sleepBedtime, sleepWakeTime, sleepDeepHours, sleepREMHours, sleepCoreHours
        case sleepHealthSourceName, waterUpdatedAt
        case isRestDay, restDayMarkedAt
    }

    var sleepSourceLabel: String? {
        switch sleepSource {
        case .appleHealth:
            if let name = sleepHealthSourceName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                return "Via \(name)"
            }
            return "Via Apple Watch / Saúde"
        case .manual:
            return "Registro manual"
        case nil:
            return nil
        }
    }
}

extension UserProfile {
    /// Meta diária efetiva: valor definido pelo personal, senão 35 ml/kg (mín. 1,5 L, teto 10 L).
    var recommendedDailyWaterML: Int {
        if let custom = customDailyWaterML {
            return min(max(custom, 500), WaterServing.maxDailyIntakeML)
        }
        let raw = max(Int((weight * 35).rounded()), 1500)
        return min(raw, WaterServing.maxDailyIntakeML)
    }

    /// Sugestão automática por peso (ignora override do personal).
    var weightBasedDailyWaterML: Int {
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
