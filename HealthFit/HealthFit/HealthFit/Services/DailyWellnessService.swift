import Foundation
import Combine
import SwiftUI

enum WellnessHealthIconStatus: Equatable {
    case green
    case yellow
    case red

    var title: String {
        switch self {
        case .green: return "Ícone saudável"
        case .yellow: return "Ícone amarelo — atualize hoje"
        case .red: return "Ícone vermelho — 24h sem atualizar"
        }
    }

    var message: String {
        switch self {
        case .green:
            return "Parabéns, mantenha o foco em sua saúde"
        case .yellow:
            return "Atualize água e sono durante o dia para manter o ícone verde."
        case .red:
            return "Passou mais de 24 horas sem atualizar água e sono. Registre agora em Sono e Hidratação."
        }
    }

    var glowColor: Color {
        switch self {
        case .green: return AppTheme.accent
        case .yellow: return .yellow
        case .red: return .red
        }
    }
}

@MainActor
final class DailyWellnessService: ObservableObject {
    static let shared = DailyWellnessService()
    static let staleUpdateThreshold: TimeInterval = 24 * 60 * 60

    @Published private(set) var todayEntry: DailyWellnessEntry = .empty()
    @Published var pendingSleepHours: Double = 7
    @Published var showSleepCheckIn = false

    private var userEmail: String?
    private let storagePrefix = "healthfit_wellness"
    private let lastUpdatePrefix = "healthfit_wellness_last_update"
    private let trackingStartPrefix = "healthfit_wellness_tracking_start"

    private init() {}

    func configure(for user: UserProfile?) {
        userEmail = user?.email
        if user != nil {
            ensureTrackingStarted()
        }
        loadTodayEntry()
        if user != nil, todayEntry.sleepHours == nil {
            pendingSleepHours = 7
            showSleepCheckIn = true
        }
    }

    func clearAllLocalData() {
        if let userEmail {
            UserDefaults.standard.removeObject(forKey: storageKey(email: userEmail))
            UserDefaults.standard.removeObject(forKey: lastUpdateKey(email: userEmail))
            UserDefaults.standard.removeObject(forKey: trackingStartKey(email: userEmail))
        }
        userEmail = nil
        todayEntry = .empty()
        pendingSleepHours = 7
        showSleepCheckIn = false
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

    /// Última atualização de água ou sono (persiste entre dias).
    var lastWaterOrSleepUpdateAt: Date? {
        guard let userEmail else { return nil }
        return UserDefaults.standard.object(forKey: lastUpdateKey(email: userEmail)) as? Date
    }

    private var trackingStartedAt: Date? {
        guard let userEmail else { return nil }
        return UserDefaults.standard.object(forKey: trackingStartKey(email: userEmail)) as? Date
    }

    var hasLoggedSleepToday: Bool {
        todayEntry.sleepHours != nil
    }

    var hasLoggedWaterToday: Bool {
        todayEntry.waterIntakeMl > 0
    }

    func healthIconStatus(referenceDate: Date = .now) -> WellnessHealthIconStatus {
        let anchor = lastWaterOrSleepUpdateAt ?? trackingStartedAt
        if let anchor, referenceDate.timeIntervalSince(anchor) >= Self.staleUpdateThreshold {
            return .red
        }

        if hasLoggedSleepToday && hasLoggedWaterToday {
            return .green
        }

        return .yellow
    }

    func healthIconDetailMessage(referenceDate: Date = .now) -> String {
        let status = healthIconStatus(referenceDate: referenceDate)
        switch status {
        case .green:
            return status.message
        case .red:
            var parts: [String] = [status.message]
            if !hasLoggedSleepToday { parts.append("Sono de hoje ainda não registrado.") }
            if !hasLoggedWaterToday { parts.append("Água de hoje ainda não registrada.") }
            return parts.joined(separator: " ")
        case .yellow:
            var reasons: [String] = []
            if !hasLoggedSleepToday { reasons.append("sono") }
            if !hasLoggedWaterToday { reasons.append("água") }
            if reasons.isEmpty {
                return status.message
            }
            let missing = reasons.joined(separator: " e ")
            return "Ícone amarelo porque você ainda não atualizou \(missing) hoje. Registre em Sono e Hidratação."
        }
    }

    func logSleep(hours: Double) {
        var entry = currentTodayEntry()
        entry.sleepHours = max(0, min(hours, 14))
        entry.sleepUpdatedAt = .now
        todayEntry = entry
        save(entry)
        markWaterOrSleepUpdated()
        showSleepCheckIn = false
    }

    func updateWaterIntake(_ milliliters: Int) {
        var entry = currentTodayEntry()
        let clamped = min(max(0, milliliters), WaterServing.maxDailyIntakeML)
        entry.waterIntakeMl = clamped
        if clamped > 0 {
            entry.waterUpdatedAt = .now
            markWaterOrSleepUpdated()
        }
        todayEntry = entry
        save(entry)
    }

    func addWater(_ milliliters: Int) {
        updateWaterIntake(min(todayEntry.waterIntakeMl + milliliters, WaterServing.maxDailyIntakeML))
    }

    func updateEnergyDrinksCount(_ count: Int) {
        var entry = currentTodayEntry()
        entry.energyDrinksCount = max(0, count)
        todayEntry = entry
        save(entry)
    }

    func updatePreWorkoutCount(_ count: Int) {
        var entry = currentTodayEntry()
        entry.preWorkoutCount = max(0, count)
        todayEntry = entry
        save(entry)
    }

    func applyPreWorkoutFromWorkouts(_ sessions: [WorkoutSession]) {
        let usedToday = WorkoutReportBuilder.todayPreWorkoutEntries(from: sessions)
            .filter(\.tookPreWorkout)
            .count
        var entry = currentTodayEntry()
        guard usedToday > entry.preWorkoutCount else { return }
        entry.preWorkoutCount = usedToday
        todayEntry = entry
        save(entry)
    }

    var tookPreWorkoutAndEnergyDrinkToday: Bool {
        todayEntry.preWorkoutCount > 0 && todayEntry.energyDrinksCount > 0
    }

    func waterProgress(for user: UserProfile) -> Double {
        guard user.recommendedDailyWaterML > 0 else { return 0 }
        return min(Double(todayEntry.waterIntakeMl) / Double(user.recommendedDailyWaterML), 1.0)
    }

    func hasMetWaterGoal(for user: UserProfile) -> Bool {
        todayEntry.waterIntakeMl >= user.recommendedDailyWaterML
    }

    func waterStatusMessage(for user: UserProfile) -> String {
        if hasMetWaterGoal(for: user) {
            return "Excelente hidratação!"
        }
        return "Você precisa hidratar-se melhor."
    }

    private func markWaterOrSleepUpdated(at date: Date = .now) {
        guard let userEmail else { return }
        UserDefaults.standard.set(date, forKey: lastUpdateKey(email: userEmail))
        objectWillChange.send()
    }

    private func ensureTrackingStarted(at date: Date = .now) {
        guard let userEmail else { return }
        let key = trackingStartKey(email: userEmail)
        guard UserDefaults.standard.object(forKey: key) == nil else { return }
        UserDefaults.standard.set(date, forKey: key)
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

    private func lastUpdateKey(email: String) -> String {
        let safeEmail = email.lowercased().replacingOccurrences(of: "@", with: "_at_")
        return "\(lastUpdatePrefix)_\(safeEmail)"
    }

    private func trackingStartKey(email: String) -> String {
        let safeEmail = email.lowercased().replacingOccurrences(of: "@", with: "_at_")
        return "\(trackingStartPrefix)_\(safeEmail)"
    }
}
