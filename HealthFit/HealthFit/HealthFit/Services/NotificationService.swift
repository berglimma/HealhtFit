import Foundation
import UserNotifications

enum WaterReminderConfiguration {
    static let intervalHours = 3
    static let startHour = 8
    static let endHour = 21

    static func reminderHours(
        startHour: Int = startHour,
        endHour: Int = endHour,
        intervalHours: Int = intervalHours
    ) -> [Int] {
        guard intervalHours > 0, startHour <= endHour else { return [] }

        var hours: [Int] = []
        var hour = startHour
        while hour <= endHour {
            hours.append(hour)
            hour += intervalHours
        }
        return hours
    }
}

enum DailyAssistantCheckInConfiguration {
    static let hour = 9
}

enum DailyEveningAssistantCheckInConfiguration {
    static let hour = 21
}

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let lastWorkoutKey = "healthfit_last_workout_completed_at"
    private let inactivityNotifiedKey = "healthfit_inactivity_notified_for_workout_at"
    private let inactivityReminderIdentifier = "workout_inactivity_48h"
    private let appUsageInactivityNotifiedKey = "healthfit_app_usage_inactivity_notified_for_session"
    private let appUsageInactivityReminderIdentifier = "app_usage_inactivity_48h"
    private let waterReminderIdentifierPrefix = "water_reminder_"
    private let dailyAssistantCheckInIdentifier = "daily_assistant_checkin_9am"
    private let dailyEveningAssistantCheckInIdentifier = "daily_assistant_checkin_9pm"

    static let inactivityThreshold: TimeInterval = 48 * 60 * 60

    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current().delegate = AppNotificationCenterDelegate.shared
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            Task { @MainActor in
                self.refreshRecurringNotifications()
            }
        }
    }

    func refreshRecurringNotifications() {
        scheduleDailyMotivationNotifications()
        scheduleDailyAssistantCheckIn()
        scheduleDailyEveningAssistantCheckIn()
        scheduleWaterReminders()
    }

    func scheduleDailyAssistantCheckIn(
        hour: Int = DailyAssistantCheckInConfiguration.hour,
        minute: Int = 0
    ) {
        cancelDailyAssistantCheckIn()

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        scheduleOnPhone(
            title: "Como você está se sentindo? ☀️",
            body: "Bom dia! O assistente quer saber como você começou o dia — meditação, treino e cardio.",
            category: "DAILY_ASSISTANT_CHECKIN",
            identifier: dailyAssistantCheckInIdentifier,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
    }

    func cancelDailyAssistantCheckIn() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [dailyAssistantCheckInIdentifier]
        )
    }

    func scheduleDailyEveningAssistantCheckIn(
        hour: Int = DailyEveningAssistantCheckInConfiguration.hour,
        minute: Int = 0
    ) {
        cancelDailyEveningAssistantCheckIn()

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        scheduleOnPhone(
            title: "Como foi seu dia? 🌙",
            body: "Boa noite! O assistente quer saber como foi seu dia e te ajudar a descansar bem.",
            category: "DAILY_EVENING_ASSISTANT_CHECKIN",
            identifier: dailyEveningAssistantCheckInIdentifier,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
    }

    func cancelDailyEveningAssistantCheckIn() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [dailyEveningAssistantCheckInIdentifier]
        )
    }

    func setAppIconBadgeCount(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count) { error in
            if let error {
                print("[HealthFit] Falha ao atualizar badge do ícone: \(error.localizedDescription)")
            }
        }
    }

    func scheduleWaterReminders(
        startHour: Int = WaterReminderConfiguration.startHour,
        endHour: Int = WaterReminderConfiguration.endHour,
        intervalHours: Int = WaterReminderConfiguration.intervalHours,
        minute: Int = 0
    ) {
        cancelWaterReminders()

        for hour in WaterReminderConfiguration.reminderHours(
            startHour: startHour,
            endHour: endHour,
            intervalHours: intervalHours
        ) {
            var components = DateComponents()
            components.hour = hour
            components.minute = minute

            let title = "Hora de beber água! 💧"
            let body = MotivationMessages.waterReminderMessage(forHour: hour)
            let identifier = "\(waterReminderIdentifierPrefix)\(hour)"

            scheduleOnPhone(
                title: title,
                body: body,
                category: "WATER_REMINDER",
                identifier: identifier,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
        }
    }

    func cancelWaterReminders() {
        let hours = WaterReminderConfiguration.reminderHours()
        let identifiers = hours.map { "\(waterReminderIdentifierPrefix)\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func scheduleDailyMotivationNotifications(hour: Int = 8, minute: Int = 0) {
        cancelDailyMotivationNotifications()

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        var watchEntries: [[String: Any]] = []

        for dayOffset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = hour
            components.minute = minute

            guard let scheduledDate = calendar.date(from: components), scheduledDate > .now else { continue }

            let title = "Hora de treinar! 💪"
            let body = MotivationMessages.dailyMessage(for: day)
            let identifier = "daily_motivation_\(dayOffset)"

            scheduleOnPhone(
                title: title,
                body: body,
                category: "DAILY_MOTIVATION",
                identifier: identifier,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )

            watchEntries.append([
                "identifier": identifier,
                "title": title,
                "body": body,
                "year": components.year ?? 0,
                "month": components.month ?? 0,
                "day": components.day ?? 0,
                "hour": hour,
                "minute": minute
            ])
        }

        WatchConnectivityManager.shared.syncDailyMotivationToWatch(entries: watchEntries)
    }

    func cancelDailyMotivationNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests
                .filter { $0.identifier.hasPrefix("daily_motivation") }
                .map(\.identifier)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
        WatchConnectivityManager.shared.cancelDailyMotivationOnWatch()
    }

    func deliverWorkoutStartNotification(workoutTitle: String, athleteName: String) {
        deliverImmediately(
            title: "Treino iniciado! 🔥",
            body: MotivationMessages.workoutStartMessage(workoutTitle: workoutTitle, athleteName: athleteName),
            category: "WORKOUT_START",
            identifier: "workout_start_\(UUID().uuidString)"
        )
    }

    func deliverWorkoutEndNotification(session: WorkoutSession, athleteName: String) {
        deliverImmediately(
            title: "Treino finalizado! 🏆",
            body: MotivationMessages.workoutEndMessage(session: session, athleteName: athleteName),
            category: "WORKOUT_END",
            identifier: "workout_end_\(UUID().uuidString)"
        )
    }

    func deliverRestOvertimeNotification(exerciseName: String) {
        deliverRestCompleteNotification(exerciseName: exerciseName)
    }

    func deliverRestCompleteNotification(exerciseName: String) {
        deliverImmediately(
            title: Self.restCompleteTitle,
            body: Self.restCompleteBody(exerciseName: exerciseName),
            category: "REST_COMPLETE",
            identifier: "rest_complete_\(UUID().uuidString)",
            exerciseName: exerciseName,
            immediate: true
        )
    }

    func scheduleRestEndReminder(after seconds: TimeInterval, exerciseName: String) {
        let title = Self.restCompleteTitle
        let body = Self.restCompleteBody(exerciseName: exerciseName)
        let identifier = "rest_reminder_\(UUID().uuidString)"

        scheduleOnPhone(
            title: title,
            body: body,
            category: "REST_COMPLETE",
            identifier: identifier,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(seconds, 1), repeats: false)
        )

        WatchConnectivityManager.shared.deliverNotificationToWatch(
            title: title,
            body: body,
            category: "REST_COMPLETE",
            identifier: identifier,
            exerciseName: exerciseName
        )
    }

    func scheduleRestReminder(after seconds: TimeInterval, exerciseName: String) {
        scheduleRestEndReminder(after: seconds, exerciseName: exerciseName)
    }

    func cancelRestReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rest_reminder"])
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.filter { $0.identifier.hasPrefix("rest_reminder") }.map(\.identifier)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    func scheduleWorkoutComplete(title: String) {
        deliverImmediately(
            title: "Treino Concluído! 💪",
            body: "Parabéns! Você finalizou \(title). Ótimo trabalho!",
            category: "WORKOUT_COMPLETE",
            identifier: "workout_complete_\(UUID().uuidString)"
        )
    }

    func schedulePostWorkoutCheckIn(sessionId: UUID, workoutTitle: String, fireDate: Date) {
        cancelPostWorkoutCheckIn(sessionId: sessionId)

        let title = "Como você está se sentindo? 💬"
        let body = "Já passaram 90 minutos desde \"\(workoutTitle)\". O assistente quer saber como está sua recuperação."
        let identifier = postWorkoutCheckInIdentifier(sessionId)
        let interval = fireDate.timeIntervalSinceNow

        guard interval > 0 else { return }

        scheduleOnPhone(
            title: title,
            body: body,
            category: "POST_WORKOUT_CHECKIN",
            identifier: identifier,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
    }

    func cancelPostWorkoutCheckIn(sessionId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [postWorkoutCheckInIdentifier(sessionId)]
        )
    }

    private func postWorkoutCheckInIdentifier(_ sessionId: UUID) -> String {
        "post_workout_checkin_\(sessionId.uuidString)"
    }

    func recordWorkoutCompleted(at date: Date = .now) {
        UserDefaults.standard.set(date, forKey: lastWorkoutKey)
        UserDefaults.standard.removeObject(forKey: inactivityNotifiedKey)
        refreshWorkoutInactivityReminder(lastWorkoutAt: date)
    }

    func refreshWorkoutInactivityReminder(lastWorkoutAt: Date?, accountCreatedAt: Date? = nil) {
        cancelWorkoutInactivityReminder()

        let referenceDate = lastWorkoutAt ?? accountCreatedAt
        guard let referenceDate else { return }

        let fireDate = referenceDate.addingTimeInterval(Self.inactivityThreshold)
        let title = "Hora de voltar a treinar!"
        let body = MotivationMessages.inactivityMessage()

        if fireDate <= .now {
            Task {
                await deliverInactivityReminderIfNeeded(
                    referenceWorkoutAt: referenceDate,
                    title: title,
                    body: body
                )
            }
        } else {
            let interval = fireDate.timeIntervalSinceNow
            scheduleOnPhone(
                title: title,
                body: body,
                category: "WORKOUT_INACTIVITY",
                identifier: inactivityReminderIdentifier,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            )
            syncInactivityReminderToWatch(fireDate: fireDate, title: title, body: body)
        }
    }

    func cancelWorkoutInactivityReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [inactivityReminderIdentifier]
        )
        WatchConnectivityManager.shared.cancelInactivityReminderOnWatch()
    }

    func refreshAppUsageInactivityReminder(lastSessionEndAt: Date) {
        cancelAppUsageInactivityReminder()

        let fireDate = lastSessionEndAt.addingTimeInterval(AppIconInactivityService.brokenThreshold)
        let title = "Volte às atividades físicas! 💔"
        let body = MotivationMessages.appUsageInactivityMessage()

        if fireDate <= .now {
            Task {
                await deliverAppUsageInactivityAlertIfNeeded(referenceSessionEnd: lastSessionEndAt)
            }
        } else {
            let interval = fireDate.timeIntervalSinceNow
            scheduleOnPhone(
                title: title,
                body: body,
                category: "APP_USAGE_INACTIVITY",
                identifier: appUsageInactivityReminderIdentifier,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            )
        }
    }

    func cancelAppUsageInactivityReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [appUsageInactivityReminderIdentifier]
        )
    }

    func deliverAppUsageInactivityAlertIfNeeded(referenceSessionEnd: Date) async {
        let notifiedFor = UserDefaults.standard.object(forKey: appUsageInactivityNotifiedKey) as? Date
        guard notifiedFor != referenceSessionEnd else { return }

        let title = "Volte às atividades físicas! 💔"
        let body = MotivationMessages.appUsageInactivityMessage()

        deliverImmediately(
            title: title,
            body: body,
            category: "APP_USAGE_INACTIVITY",
            identifier: "app_usage_inactivity_\(UUID().uuidString)"
        )
        UserDefaults.standard.set(referenceSessionEnd, forKey: appUsageInactivityNotifiedKey)
    }

    var lastRecordedWorkoutAt: Date? {
        UserDefaults.standard.object(forKey: lastWorkoutKey) as? Date
    }

    func migrateLastWorkoutDateIfNeeded(_ date: Date) {
        guard lastRecordedWorkoutAt == nil else { return }
        UserDefaults.standard.set(date, forKey: lastWorkoutKey)
    }

    private func deliverInactivityReminderIfNeeded(
        referenceWorkoutAt: Date,
        title: String,
        body: String
    ) async {
        let notifiedFor = UserDefaults.standard.object(forKey: inactivityNotifiedKey) as? Date
        guard notifiedFor != referenceWorkoutAt else { return }

        let delivered = await pendingDeliveredNotifications()
        let alreadyShown = delivered.contains {
            $0.request.content.categoryIdentifier == "WORKOUT_INACTIVITY"
        }

        if alreadyShown {
            UserDefaults.standard.set(referenceWorkoutAt, forKey: inactivityNotifiedKey)
            return
        }

        deliverImmediately(
            title: title,
            body: body,
            category: "WORKOUT_INACTIVITY",
            identifier: "workout_inactivity_\(UUID().uuidString)"
        )
        UserDefaults.standard.set(referenceWorkoutAt, forKey: inactivityNotifiedKey)
    }

    private func pendingDeliveredNotifications() async -> [UNNotification] {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
                continuation.resume(returning: notifications)
            }
        }
    }

    private func syncInactivityReminderToWatch(fireDate: Date, title: String, body: String) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        WatchConnectivityManager.shared.scheduleInactivityReminderOnWatch(
            title: title,
            body: body,
            year: components.year ?? 0,
            month: components.month ?? 0,
            day: components.day ?? 0,
            hour: components.hour ?? 0,
            minute: components.minute ?? 0,
            identifier: inactivityReminderIdentifier
        )
    }

    static let restOvertimeTitle = "Descanso encerrado!"
    static let restCompleteTitle = "Descanso encerrado!"

    static func restOvertimeBody(exerciseName: String) -> String {
        restCompleteBody(exerciseName: exerciseName)
    }

    static func restCompleteBody(exerciseName: String) -> String {
        "O tempo de descanso após \(exerciseName) terminou. Toque em OK vamos lá e continue o treino!"
    }

    private func deliverImmediately(
        title: String,
        body: String,
        category: String,
        identifier: String,
        exerciseName: String? = nil,
        immediate: Bool = false
    ) {
        let trigger: UNNotificationTrigger? = immediate
            ? nil
            : UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        scheduleOnPhone(
            title: title,
            body: body,
            category: category,
            identifier: identifier,
            trigger: trigger
        )

        WatchConnectivityManager.shared.deliverNotificationToWatch(
            title: title,
            body: body,
            category: category,
            identifier: identifier,
            exerciseName: exerciseName
        )
    }

    private func scheduleOnPhone(
        title: String,
        body: String,
        category: String,
        identifier: String,
        trigger: UNNotificationTrigger?
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

/// Exibe banner e som mesmo com o app em primeiro plano (ex.: fim do descanso).
final class AppNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AppNotificationCenterDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
