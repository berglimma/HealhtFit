import Foundation

enum UserDataCleaner {
    private static let knownKeys = [
        "healthfit_current_user",
        "healthfit_workout_sheets",
        "healthfit_session_history",
        "healthfit_meal_plan",
        "healthfit_shopping_list",
        "healthfit_custom_menu",
        "healthfit_shopping_purchase_stats",
        "healthfit_last_weekly_report_viewed",
        "healthfit_post_workout_checkin",
        "healthfit_assistant_unread",
        "healthfit_daily_morning_checkin",
        "healthfit_daily_evening_checkin",
        "healthfit_last_workout_completed_at",
        "healthfit_inactivity_notified_for_workout_at",
        "healthfit_app_usage_inactivity_notified_for_session",
        "healthfit_last_session_end_at",
        "healthfit_broken_icon_alert_sent_for_session",
    ]

    static func clearAllLocalData(uid: String, email: String) {
        removeKnownDefaultsKeys()
        removeProfileCache(uid: uid)
        removeWellnessEntries(email: email)
        removeProfileImages(uid: uid, email: email)
        removeLegacyProfileImage(email: email)
    }

    private static func removeKnownDefaultsKeys() {
        for key in knownKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private static func removeProfileCache(uid: String) {
        UserDefaults.standard.removeObject(forKey: "healthfit_profile_\(uid)")
    }

    private static func removeWellnessEntries(email: String) {
        let normalized = email.lowercased()
        let safeEmail = normalized.replacingOccurrences(of: "@", with: "_at_")
        UserDefaults.standard.removeObject(forKey: "healthfit_wellness_\(safeEmail)_today")
    }

    private static func removeProfileImages(uid: String, email: String) {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let safeUID = uid.replacingOccurrences(of: "/", with: "_")
        let uidURL = directory.appendingPathComponent("profile_\(safeUID).jpg")
        try? FileManager.default.removeItem(at: uidURL)
    }

    private static func removeLegacyProfileImage(email: String) {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let safeEmail = email.lowercased().replacingOccurrences(of: "@", with: "_at_")
        let url = directory.appendingPathComponent("profile_\(safeEmail).jpg")
        try? FileManager.default.removeItem(at: url)
    }
}
