import Combine
import Foundation

/// Preferências de lembretes de suplementos e refeições (horários habituais).
@MainActor
final class NutritionNotificationPreferences: ObservableObject {
    static let shared = NutritionNotificationPreferences()

    private let supplementKey = "healthfit.nutrition.notif.supplementsEnabled"
    private let mealEnabledKey = "healthfit.nutrition.notif.mealsEnabled"
    private let mealTimesKey = "healthfit.nutrition.notif.mealTimes"
    private var isHydrating = true

    @Published var supplementRemindersEnabled: Bool {
        didSet {
            guard !isHydrating else { return }
            UserDefaults.standard.set(supplementRemindersEnabled, forKey: supplementKey)
            NotificationService.shared.refreshSupplementRemindersFromPreferences()
            CrossDeviceSyncCoordinator.pushPreferencesNow()
        }
    }

    @Published var mealRemindersEnabled: Bool {
        didSet {
            guard !isHydrating else { return }
            UserDefaults.standard.set(mealRemindersEnabled, forKey: mealEnabledKey)
            NotificationService.shared.refreshMealRemindersFromPreferences()
            CrossDeviceSyncCoordinator.pushPreferencesNow()
        }
    }

    /// Minutos desde meia-noite por `MealType.rawValue`.
    @Published private(set) var mealMinutesFromMidnight: [String: Int] {
        didSet {
            guard !isHydrating else { return }
            if let data = try? JSONEncoder().encode(mealMinutesFromMidnight) {
                UserDefaults.standard.set(data, forKey: mealTimesKey)
            }
            if mealRemindersEnabled {
                NotificationService.shared.refreshMealRemindersFromPreferences()
            }
            CrossDeviceSyncCoordinator.pushPreferencesNow()
        }
    }

    private init() {
        if UserDefaults.standard.object(forKey: supplementKey) == nil {
            // Mantém comportamento anterior (lembretes ativos) até o usuário desligar.
            supplementRemindersEnabled = true
        } else {
            supplementRemindersEnabled = UserDefaults.standard.bool(forKey: supplementKey)
        }

        if UserDefaults.standard.object(forKey: mealEnabledKey) == nil {
            // Migra quem já recebia lembretes via cardápio.
            mealRemindersEnabled = UserDefaults.standard.bool(forKey: "healthfit_meal_reminders_enabled")
        } else {
            mealRemindersEnabled = UserDefaults.standard.bool(forKey: mealEnabledKey)
        }

        if let data = UserDefaults.standard.data(forKey: mealTimesKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            mealMinutesFromMidnight = decoded
        } else {
            mealMinutesFromMidnight = Self.defaultMealMinutes()
        }

        isHydrating = false
    }

    static func defaultMealMinutes() -> [String: Int] {
        Dictionary(uniqueKeysWithValues: MealType.allCases.map { meal in
            let clock = MealReminderConfiguration.defaultMealClock(for: meal)
            return (meal.rawValue, clock.hour * 60 + clock.minute)
        })
    }

    func mealClock(for mealType: MealType) -> (hour: Int, minute: Int) {
        let total = mealMinutesFromMidnight[mealType.rawValue]
            ?? (Self.defaultMealMinutes()[mealType.rawValue] ?? 0)
        let clamped = max(0, min(total, 23 * 60 + 59))
        return (clamped / 60, clamped % 60)
    }

    func mealDate(for mealType: MealType, reference: Date = .now) -> Date {
        let clock = mealClock(for: mealType)
        var components = Calendar.current.dateComponents([.year, .month, .day], from: reference)
        components.hour = clock.hour
        components.minute = clock.minute
        components.second = 0
        return Calendar.current.date(from: components) ?? reference
    }

    func setMealTime(for mealType: MealType, date: Date) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        var updated = mealMinutesFromMidnight
        updated[mealType.rawValue] = hour * 60 + minute
        mealMinutesFromMidnight = updated
    }

    func formattedMealTime(for mealType: MealType) -> String {
        let clock = mealClock(for: mealType)
        return String(format: "%02d:%02d", clock.hour, clock.minute)
    }

    func resetToDefaults() {
        mealMinutesFromMidnight = Self.defaultMealMinutes()
    }

    func applyFromCloud(supplements: Bool, meals: Bool, mealTimes: [String: Int]) {
        isHydrating = true
        supplementRemindersEnabled = supplements
        mealRemindersEnabled = meals
        mealMinutesFromMidnight = mealTimes.isEmpty ? Self.defaultMealMinutes() : mealTimes
        UserDefaults.standard.set(supplementRemindersEnabled, forKey: supplementKey)
        UserDefaults.standard.set(mealRemindersEnabled, forKey: mealEnabledKey)
        if let data = try? JSONEncoder().encode(mealMinutesFromMidnight) {
            UserDefaults.standard.set(data, forKey: mealTimesKey)
        }
        isHydrating = false
        NotificationService.shared.refreshSupplementRemindersFromPreferences()
        NotificationService.shared.refreshMealRemindersFromPreferences()
    }
}
