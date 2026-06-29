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

struct DailyWellnessEntry: Codable, Equatable {
    var dayKey: String
    var sleepHours: Double?
    var waterIntakeMl: Int

    static func empty(for date: Date = .now) -> DailyWellnessEntry {
        DailyWellnessEntry(
            dayKey: Self.dayKey(for: date),
            sleepHours: nil,
            waterIntakeMl: 0
        )
    }

    static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

extension UserProfile {
    /// Recomendação: 35 ml de água por kg de peso corporal por dia.
    var recommendedDailyWaterML: Int {
        max(Int((weight * 35).rounded()), 1500)
    }

    var recommendedDailyWaterLiters: Double {
        Double(recommendedDailyWaterML) / 1000.0
    }

    var recommendedWaterGlasses: Int {
        max(recommendedDailyWaterML / 250, 6)
    }
}
