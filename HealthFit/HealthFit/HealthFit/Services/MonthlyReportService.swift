import Foundation
import Combine

@MainActor
final class MonthlyReportService: ObservableObject {
    static let shared = MonthlyReportService()

    private let lastViewedKey = "healthfit_last_monthly_report_viewed"

    @Published private(set) var lastViewedAt: Date?
    @Published private(set) var recentWellnessEntries: [DailyWellnessEntry] = []
    @Published private(set) var isLoadingWellness = false

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

    func markReportViewed() {
        lastViewedAt = .now
        UserDefaults.standard.set(lastViewedAt, forKey: lastViewedKey)
        CrossDeviceSyncCoordinator.pushPreferencesNow()
    }

    func reset() {
        lastViewedAt = nil
        recentWellnessEntries = []
        UserDefaults.standard.removeObject(forKey: lastViewedKey)
    }

    func applyFromCloud(lastViewedAt: Date?) {
        self.lastViewedAt = lastViewedAt
        if let lastViewedAt {
            UserDefaults.standard.set(lastViewedAt, forKey: lastViewedKey)
        } else {
            UserDefaults.standard.removeObject(forKey: lastViewedKey)
        }
    }

    func buildReport(
        sessions: [WorkoutSession],
        wellnessEntries: [DailyWellnessEntry],
        profile: UserProfile?,
        weeklyPlan: [DailyMealPlan],
        goal: FitnessGoal
    ) -> MonthlyProgressReport {
        MonthlyProgressAnalyzer.buildReport(
            sessions: sessions,
            wellnessEntries: wellnessEntries,
            bodyMeasurements: profile?.bodyMeasurements,
            previousBodyMeasurements: profile?.previousBodyMeasurements,
            weeklyPlan: weeklyPlan,
            goal: goal
        )
    }

    /// Carrega histórico de wellness (sono/suplementos) da nuvem para o relatório mensal.
    func loadWellnessHistory(userId: String?, todayEntry: DailyWellnessEntry) async {
        isLoadingWellness = true
        defer { isLoadingWellness = false }

        var entries: [DailyWellnessEntry] = []
        if let userId, DailyWellnessFirestoreService.isAvailable {
            do {
                entries = try await DailyWellnessFirestoreService.fetchRecentEntries(
                    userId: userId,
                    limit: MonthlyProgressAnalyzer.reportDays + 5
                )
            } catch {
                print("[HealthFit] Falha ao carregar wellness para relatório mensal: \(error.localizedDescription)")
            }
        }

        // Garante o dia atual (cache local) mesmo sem nuvem.
        if todayEntry.dayKey == DailyWellnessEntry.dayKey(for: .now) {
            if let index = entries.firstIndex(where: { $0.dayKey == todayEntry.dayKey }) {
                entries[index] = mergePreferringRicher(local: todayEntry, remote: entries[index])
            } else {
                entries.insert(todayEntry, at: 0)
            }
        }

        recentWellnessEntries = entries
    }

    func cacheWellnessEntries(_ entries: [DailyWellnessEntry]) {
        recentWellnessEntries = entries
    }

    private func mergePreferringRicher(
        local: DailyWellnessEntry,
        remote: DailyWellnessEntry
    ) -> DailyWellnessEntry {
        var merged = remote
        if (local.sleepUpdatedAt ?? .distantPast) >= (remote.sleepUpdatedAt ?? .distantPast),
           local.sleepHours != nil {
            merged.sleepHours = local.sleepHours
            merged.sleepUpdatedAt = local.sleepUpdatedAt
        }
        if (local.supplementsUpdatedAt ?? .distantPast) >= (remote.supplementsUpdatedAt ?? .distantPast) {
            merged.supplementIntakes = local.supplementIntakes
            merged.supplementsUpdatedAt = local.supplementsUpdatedAt
        }
        if local.waterIntakeMl >= remote.waterIntakeMl {
            merged.waterIntakeMl = local.waterIntakeMl
            merged.waterUpdatedAt = local.waterUpdatedAt
        }
        return merged
    }

    private var reportInterval: TimeInterval {
        30 * 24 * 60 * 60
    }
}
