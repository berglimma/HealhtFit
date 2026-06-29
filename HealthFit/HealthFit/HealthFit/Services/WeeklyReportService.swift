import Foundation
import Combine

@MainActor
final class WeeklyReportService: ObservableObject {
    static let shared = WeeklyReportService()

    private let lastViewedKey = "healthfit_last_weekly_report_viewed"

    @Published private(set) var lastViewedAt: Date?

    private init() {
        lastViewedAt = UserDefaults.standard.object(forKey: lastViewedKey) as? Date
    }

    var isReportAvailable: Bool {
        guard let lastViewedAt else { return true }
        return Date.now.timeIntervalSince(lastViewedAt) >= reportInterval
    }

    var daysUntilNextReport: Int {
        guard let lastViewedAt else { return 0 }
        let remaining = reportInterval - Date.now.timeIntervalSince(lastViewedAt)
        return max(0, Int(ceil(remaining / 86_400)))
    }

    var nextReportDate: Date? {
        guard let lastViewedAt else { return nil }
        return lastViewedAt.addingTimeInterval(reportInterval)
    }

    func markReportViewed() {
        lastViewedAt = .now
        UserDefaults.standard.set(lastViewedAt, forKey: lastViewedKey)
    }

    func buildReport(
        sessions: [WorkoutSession],
        goal: FitnessGoal
    ) -> WeeklyProgressReport {
        WeeklyProgressAnalyzer.buildReport(sessions: sessions, goal: goal)
    }

    private var reportInterval: TimeInterval {
        7 * 24 * 60 * 60
    }
}
