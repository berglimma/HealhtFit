import Foundation

enum UserDataCleaner {
    /// Chaves globais de dados de usuário (não preferências de app como idioma).
    private static let knownKeys = [
        "healthfit_current_user",
        "healthfit_workout_sheets",
        "healthfit_session_history",
        "healthfit_active_session",
        "healthfit_active_exercise_records",
        "healthfit_active_exercise_index",
        "healthfit_active_minimized",
        "healthfit_exercise_timer_paused",
        "healthfit_exercise_last_progress_at",
        "healthfit_active_cardio_config",
        "healthfit_meal_plan",
        "healthfit_meal_reminders_enabled",
        "healthfit.nutrition.notif.supplementsEnabled",
        "healthfit.nutrition.notif.mealsEnabled",
        "healthfit.nutrition.notif.mealTimes",
        "healthfit.recommendedRotation.anchor",
        "healthfit.recommendedRotation.appliedCohort",
        "healthfit_shopping_list",
        "healthfit_custom_menu",
        "healthfit_shopping_purchase_stats",
        "healthfit_last_weekly_report_viewed",
        "healthfit_last_monthly_report_viewed",
        "healthfit_post_workout_checkin",
        "healthfit_assistant_unread",
        "healthfit_daily_morning_checkin",
        "healthfit_daily_evening_checkin",
        "healthfit_last_workout_completed_at",
        "healthfit_last_cardio_completed_at",
        "healthfit_last_meditation_completed_at",
        "healthfit_inactivity_notified_for_workout_at",
        "healthfit_inactivity_notified_for_cardio_at",
        "healthfit_inactivity_notified_for_meditation_at",
        "healthfit_app_usage_inactivity_notified_for_session",
        "healthfit_last_session_end_at",
        "healthfit_broken_icon_alert_sent_for_session",
        "healthfit_last_workout_share_card",
        "healthfit_last_duo_workout_share_card",
        "healthfit_active_duo_team_id",
        "healthfit_active_duo_team_name",
        "healthfit_active_duo_team_modalities",
        "healthfit_pending_supplement_ack",
        "healthfit_supplement_nudge_day",
        "healthfit_supplement_ack_notified_day",
        "healthfit_evening_nudge_shown_day",
        "healthfit_rest_seconds",
        "healthfit_max_rest_seconds",
        "healthfit_active_rest_state",
        "healthfit.climbing.gear.v1",
        "healthfit.climbing.gear.lastAlert.v1",
        "healthfit.bike.logbook.v1",
        "healthfit.bike.wear.v1",
        "healthfit.bike.totalKm.v1",
        "healthfit.road.hazards.v1",
        "healthfit.road.hazards.seedMeta.v1",
        "healthfit.calendar.eventIdsBySession",
        "healthfit.assistant.dailyMessageCount",
        "healthfit.assistant.dailyMessageDay",
        "healthfit.subscription.debugTier",
        "bodyEvolution.pendingAssistantMessage",
        "healthfit.pr.pending_assistant",
        "healthfit.externalWorkouts.processedUUIDs",
        "healthfit.externalWorkouts.pendingAssistantMessage",
        "healthfit.duoTeam.privacyConsent.v1",
    ]

    static func clearAllLocalData(uid: String, email: String) {
        removeKnownDefaultsKeys()
        removeProfileCache(uid: uid)
        removeWellnessEntries(email: email)
        removeProfileImages(uid: uid, email: email)
        removeLegacyProfileImage(email: email)
        removeBodyEvolutionLocalPhotos(uid: uid)
        removeScopedUserKeys(uid: uid)
    }

    private static func removeKnownDefaultsKeys() {
        for key in knownKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    /// Remove chaves já migradas para o namespace por uid (`healthfit.u.{uid}.*`).
    private static func removeScopedUserKeys(uid: String) {
        let prefix = UserScopedDefaults.prefix(for: uid)
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
    }

    private static func removeProfileCache(uid: String) {
        UserDefaults.standard.removeObject(forKey: "healthfit_profile_\(uid)")
        UserDefaults.standard.removeObject(forKey: "healthfit_profile_dirty_\(uid)")
    }

    private static func removeWellnessEntries(email: String) {
        let normalized = email.lowercased()
        let safeEmail = normalized.replacingOccurrences(of: "@", with: "_at_")
        UserDefaults.standard.removeObject(forKey: "healthfit_wellness_\(safeEmail)_today")
        UserDefaults.standard.removeObject(forKey: "healthfit_wellness_last_update_\(safeEmail)")
        UserDefaults.standard.removeObject(forKey: "healthfit_wellness_tracking_start_\(safeEmail)")
        UserDefaults.standard.removeObject(forKey: "healthfit_wellness_morning_checkin_handled_\(safeEmail)")
    }

    private static func removeProfileImages(uid: String, email: String) {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let safeUID = uid.replacingOccurrences(of: "/", with: "_")
        let uidURL = directory.appendingPathComponent("profile_\(safeUID).jpg")
        try? FileManager.default.removeItem(at: uidURL)
        let bgURL = directory.appendingPathComponent("profile_bg_\(safeUID).jpg")
        try? FileManager.default.removeItem(at: bgURL)
    }

    private static func removeLegacyProfileImage(email: String) {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let safeEmail = email.lowercased().replacingOccurrences(of: "@", with: "_at_")
        let url = directory.appendingPathComponent("profile_\(safeEmail).jpg")
        try? FileManager.default.removeItem(at: url)
    }

    private static func removeBodyEvolutionLocalPhotos(uid: String) {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = directory.appendingPathComponent("BodyEvolution/\(uid)")
        try? FileManager.default.removeItem(at: folder)
    }
}
