import Foundation

/// Orquestra pull/push de preferências, bike, escalada, treino ativo e fundo do perfil.
@MainActor
enum CrossDeviceSyncCoordinator {
    private static let prefsUpdatedAtKey = "healthfit.prefs.cloud_updated_at"
    private static let bikeUpdatedAtKey = "healthfit.bike.cloud_updated_at"
    private static let climbingUpdatedAtKey = "healthfit.climbing.cloud_updated_at"
    private static var lastActiveCloudPushAt: Date?
    private static let activePushMinInterval: TimeInterval = 20

    static func syncAll(
        userId: String,
        workoutStore: WorkoutStore,
        timerService: RestTimerService
    ) async {
        guard CrossDeviceSyncFirestoreService.isAvailable else { return }
        await syncPreferences(userId: userId, timerService: timerService)
        await syncBike(userId: userId)
        await ClimbingGearService.shared.syncFromCloud(userId: userId)
        await workoutStore.syncActiveWorkoutFromCloud(userId: userId)
    }

    // MARK: - Preferences

    static func pushPreferencesNow(
        timerService: RestTimerService? = nil,
        forceUpdatedAt: Date = .now
    ) {
        guard let userId = currentUserId(), CrossDeviceSyncFirestoreService.isAvailable else { return }
        let snapshot = makePreferencesSnapshot(timerService: timerService, updatedAt: forceUpdatedAt)
        UserDefaults.standard.set(forceUpdatedAt.timeIntervalSince1970, forKey: prefsUpdatedAtKey)
        Task {
            try? await CrossDeviceSyncFirestoreService.savePreferences(snapshot, userId: userId)
        }
    }

    private static func syncPreferences(userId: String, timerService: RestTimerService) async {
        let localUpdated = date(forKey: prefsUpdatedAtKey)
        let remote = try? await CrossDeviceSyncFirestoreService.fetchPreferences(userId: userId)

        if let remote, remote.updatedAt > localUpdated {
            applyPreferences(remote, timerService: timerService)
            UserDefaults.standard.set(remote.updatedAt.timeIntervalSince1970, forKey: prefsUpdatedAtKey)
            return
        }

        let snapshot = makePreferencesSnapshot(timerService: timerService, updatedAt: max(localUpdated, .now))
        UserDefaults.standard.set(snapshot.updatedAt.timeIntervalSince1970, forKey: prefsUpdatedAtKey)
        try? await CrossDeviceSyncFirestoreService.savePreferences(snapshot, userId: userId)
    }

    private static func makePreferencesSnapshot(
        timerService: RestTimerService?,
        updatedAt: Date
    ) -> UIPreferencesCloudSnapshot {
        let rest = timerService?.configuredRestSeconds
            ?? (UserDefaults.standard.object(forKey: "healthfit_rest_seconds") as? Int ?? 60)
        let maxRest = timerService?.maxRestSeconds
            ?? (UserDefaults.standard.object(forKey: "healthfit_max_rest_seconds") as? Int ?? 120)
        let restNotif: Bool = {
            if let timerService { return timerService.notificationEnabled }
            if UserDefaults.standard.object(forKey: "healthfit_rest_notifications") != nil {
                return UserDefaults.standard.bool(forKey: "healthfit_rest_notifications")
            }
            return true
        }()

        let nutrition = NutritionNotificationPreferences.shared
        return UIPreferencesCloudSnapshot(
            language: AppLanguageStore.shared.language.rawValue,
            restSeconds: rest,
            maxRestSeconds: maxRest,
            restNotifications: restNotif,
            supplementRemindersEnabled: nutrition.supplementRemindersEnabled,
            mealRemindersEnabled: nutrition.mealRemindersEnabled,
            mealMinutesFromMidnight: nutrition.mealMinutesFromMidnight,
            lastWeeklyReportViewed: WeeklyReportService.shared.lastViewedAt,
            lastMonthlyReportViewed: MonthlyReportService.shared.lastViewedAt,
            updatedAt: updatedAt
        )
    }

    private static func applyPreferences(_ remote: UIPreferencesCloudSnapshot, timerService: RestTimerService) {
        if let code = remote.language, let lang = AppLanguage(rawValue: code) {
            AppLanguageStore.shared.applyFromCloud(lang)
        }
        timerService.applyCloudConfiguration(
            restSeconds: remote.restSeconds,
            maxRest: remote.maxRestSeconds,
            notifications: remote.restNotifications
        )
        NutritionNotificationPreferences.shared.applyFromCloud(
            supplements: remote.supplementRemindersEnabled,
            meals: remote.mealRemindersEnabled,
            mealTimes: remote.mealMinutesFromMidnight
        )
        WeeklyReportService.shared.applyFromCloud(lastViewedAt: remote.lastWeeklyReportViewed)
        MonthlyReportService.shared.applyFromCloud(lastViewedAt: remote.lastMonthlyReportViewed)
    }

    // MARK: - Bike

    static func pushBikeNow() {
        guard let userId = currentUserId(), CrossDeviceSyncFirestoreService.isAvailable else { return }
        let now = Date()
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: bikeUpdatedAtKey)
        let snapshot = BikeMaintenanceService.shared.makeCloudSnapshot(updatedAt: now)
        Task {
            try? await CrossDeviceSyncFirestoreService.saveBike(snapshot, userId: userId)
        }
    }

    private static func syncBike(userId: String) async {
        let localUpdated = date(forKey: bikeUpdatedAtKey)
        let remote = try? await CrossDeviceSyncFirestoreService.fetchBike(userId: userId)
        if let remote, remote.updatedAt > localUpdated {
            BikeMaintenanceService.shared.applyCloudSnapshot(remote)
            UserDefaults.standard.set(remote.updatedAt.timeIntervalSince1970, forKey: bikeUpdatedAtKey)
            return
        }
        let now = max(localUpdated, Date())
        let snapshot = BikeMaintenanceService.shared.makeCloudSnapshot(updatedAt: now)
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: bikeUpdatedAtKey)
        try? await CrossDeviceSyncFirestoreService.saveBike(snapshot, userId: userId)
    }

    // MARK: - Active workout throttle helper

    static func shouldPushActiveWorkout(force: Bool) -> Bool {
        if force { return true }
        guard let last = lastActiveCloudPushAt else { return true }
        return Date().timeIntervalSince(last) >= activePushMinInterval
    }

    static func markActiveWorkoutPushed() {
        lastActiveCloudPushAt = .now
    }

    // MARK: - Helpers

    private static func currentUserId() -> String? {
        FirebaseAuthProvider.currentUser?.uid
    }

    private static func date(forKey key: String) -> Date {
        let interval = UserDefaults.standard.double(forKey: key)
        guard interval > 0 else { return .distantPast }
        return Date(timeIntervalSince1970: interval)
    }
}
