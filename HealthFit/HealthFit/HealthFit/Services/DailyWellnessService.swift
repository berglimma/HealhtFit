import Foundation
import Combine

@MainActor
final class DailyWellnessService: ObservableObject {
    static let shared = DailyWellnessService()

    @Published private(set) var todayEntry: DailyWellnessEntry = .empty()
    @Published var pendingSleepHours: Double = 7
    @Published var showSleepCheckIn = false

    private var userEmail: String?
    private let storagePrefix = "healthfit_wellness"

    private init() {}

    func configure(for user: UserProfile?) {
        userEmail = user?.email
        loadTodayEntry()
        if user != nil, todayEntry.sleepHours == nil {
            pendingSleepHours = 7
            showSleepCheckIn = true
        }
    }

    func checkInOnAppOpen() {
        loadTodayEntry()
        guard userEmail != nil else { return }
        if todayEntry.sleepHours == nil {
            pendingSleepHours = 7
            showSleepCheckIn = true
        }
    }

    var needsSleepCheckIn: Bool {
        todayEntry.sleepHours == nil
    }

    var todaySleepHours: Double? {
        todayEntry.sleepHours
    }

    var todaySleepAssessment: SleepAssessment? {
        guard let hours = todayEntry.sleepHours else { return nil }
        return SleepAssessment.evaluate(hours: hours)
    }

    func logSleep(hours: Double) {
        var entry = currentTodayEntry()
        entry.sleepHours = max(0, min(hours, 14))
        todayEntry = entry
        save(entry)
        showSleepCheckIn = false
    }

    func updateWaterIntake(_ milliliters: Int) {
        var entry = currentTodayEntry()
        entry.waterIntakeMl = max(0, milliliters)
        todayEntry = entry
        save(entry)
    }

    func addWater(_ milliliters: Int) {
        updateWaterIntake(todayEntry.waterIntakeMl + milliliters)
    }

    func waterProgress(for user: UserProfile) -> Double {
        guard user.recommendedDailyWaterML > 0 else { return 0 }
        return min(Double(todayEntry.waterIntakeMl) / Double(user.recommendedDailyWaterML), 1.0)
    }

    func waterStatusMessage(for user: UserProfile) -> String {
        let goal = user.recommendedDailyWaterML
        let current = todayEntry.waterIntakeMl
        let remaining = max(goal - current, 0)

        if current >= goal {
            return "Meta de hidratação atingida! Continue se estiver treinando ou com calor."
        }
        if remaining >= 1000 {
            return String(format: "Faltam %.1f L para atingir sua meta de água hoje.", Double(remaining) / 1000)
        }
        return "Faltam \(remaining) ml para atingir sua meta de água hoje."
    }

    private func currentTodayEntry() -> DailyWellnessEntry {
        let today = DailyWellnessEntry.dayKey(for: .now)
        if todayEntry.dayKey == today {
            return todayEntry
        }
        return .empty()
    }

    private func loadTodayEntry() {
        guard let userEmail else {
            todayEntry = .empty()
            return
        }

        let key = storageKey(email: userEmail)
        guard let data = UserDefaults.standard.data(forKey: key),
              let stored = try? JSONDecoder().decode(DailyWellnessEntry.self, from: data),
              stored.dayKey == DailyWellnessEntry.dayKey(for: .now) else {
            todayEntry = .empty()
            return
        }
        todayEntry = stored
    }

    private func save(_ entry: DailyWellnessEntry) {
        guard let userEmail else { return }
        todayEntry = entry
        if let data = try? JSONEncoder().encode(entry) {
            UserDefaults.standard.set(data, forKey: storageKey(email: userEmail))
        }
    }

    private func storageKey(email: String) -> String {
        let safeEmail = email.lowercased().replacingOccurrences(of: "@", with: "_at_")
        return "\(storagePrefix)_\(safeEmail)_today"
    }
}
