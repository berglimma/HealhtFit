import Foundation

/// Resumo gerado pelo IAssistente para o profissional (não é diagnóstico).
struct ProfessionalReviewSnapshot: Codable, Equatable, Identifiable {
    var id: String
    var linkId: String
    var studentUid: String
    var studentName: String
    var generatedAt: Date
    var windowDays: Int

    var mealAdherencePercent: Int
    var averageProteinGramsPerDay: Int
    var proteinGoalGramsPerDay: Int
    var averageSleepHours: Double
    var workoutsCompleted: Int
    var workoutsExpected: Int
    var weightDeltaKg30d: Double?
    var waistDeltaCm: Double?
    var reviewPoints: [String]
    /// Metas textuais do profissional (quando houver).
    var professionalGoals: [String]
    var dataSources: [String]

    var sleepFormatted: String {
        let totalMinutes = Int((averageSleepHours * 60).rounded())
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return "\(h)h \(String(format: "%02d", m))min"
    }

    var weightDeltaLabel: String {
        guard let d = weightDeltaKg30d else { return "—" }
        let sign = d > 0 ? "+" : (d < 0 ? "−" : "")
        return "\(sign)\(String(format: "%.1f", abs(d))) kg em 30 dias"
    }

    var waistDeltaLabel: String {
        guard let d = waistDeltaCm else { return "—" }
        let sign = d > 0 ? "+" : (d < 0 ? "−" : "")
        return "\(sign)\(String(format: "%.1f", abs(d)).replacingOccurrences(of: ".", with: ",")) cm"
    }

    static func empty(linkId: String, studentUid: String, studentName: String) -> ProfessionalReviewSnapshot {
        ProfessionalReviewSnapshot(
            id: "review-\(linkId)",
            linkId: linkId,
            studentUid: studentUid,
            studentName: studentName,
            generatedAt: .now,
            windowDays: 7,
            mealAdherencePercent: 0,
            averageProteinGramsPerDay: 0,
            proteinGoalGramsPerDay: 0,
            averageSleepHours: 0,
            workoutsCompleted: 0,
            workoutsExpected: 7,
            weightDeltaKg30d: nil,
            waistDeltaCm: nil,
            reviewPoints: ["Ainda sem dados suficientes para revisão."],
            professionalGoals: [],
            dataSources: []
        )
    }
}

/// Foto nutricional do dia — visualização única pelo nutricionista.
struct DailyMealPhotoShare: Identifiable, Codable, Equatable {
    var id: String
    var linkId: String
    var studentUid: String
    var studentName: String
    var dayKey: String
    var mealLabel: String
    var note: String
    var storagePath: String
    var downloadURL: String?
    var createdAt: Date
    var viewedAt: Date?
    var viewedByUid: String?

    var isViewed: Bool { viewedAt != nil }

    static func dayKey(for date: Date = .now) -> String {
        DailyWellnessEntry.dayKey(for: date)
    }
}

/// Agregados de atendimento para relatório do profissional.
struct ConsultationAttendanceReport: Equatable {
    var periodStart: Date
    var periodEnd: Date
    var totalBookings: Int
    var confirmed: Int
    var completed: Int
    var cancelled: Int
    var proposed: Int
    var byWeekday: [WeekdayCount]
    var byDay: [DayCount]
    var recent: [ConsultationBooking]

    struct WeekdayCount: Identifiable, Equatable {
        var id: Int { weekday }
        var weekday: Int
        var label: String
        var count: Int
    }

    struct DayCount: Identifiable, Equatable {
        var id: String { dayKey }
        var dayKey: String
        var date: Date
        var count: Int
    }

    var showRatePercent: Int {
        let denom = max(confirmed + completed + cancelled, 1)
        return Int((Double(completed) / Double(denom) * 100).rounded())
    }
}
