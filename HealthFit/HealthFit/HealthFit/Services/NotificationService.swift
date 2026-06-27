import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            Task { @MainActor in
                self.scheduleDailyMotivationNotifications()
            }
        }
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
        deliverImmediately(
            title: Self.restOvertimeTitle,
            body: Self.restOvertimeBody(exerciseName: exerciseName),
            category: "REST_OVERTIME",
            identifier: "rest_overtime_\(UUID().uuidString)",
            exerciseName: exerciseName
        )
    }

    func scheduleRestReminder(after seconds: TimeInterval, exerciseName: String) {
        let title = "Descanso prolongado!"
        let body = "Você está descansando há muito tempo após \(exerciseName). Hora de voltar ao treino!"
        let identifier = "rest_reminder_\(UUID().uuidString)"

        scheduleOnPhone(
            title: title,
            body: body,
            category: "REST_REMINDER",
            identifier: identifier,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(seconds, 1), repeats: false)
        )

        WatchConnectivityManager.shared.deliverNotificationToWatch(
            title: title,
            body: body,
            category: "REST_REMINDER",
            identifier: identifier
        )
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

    static let restOvertimeTitle = "Descanso encerrado!"

    static func restOvertimeBody(exerciseName: String) -> String {
        "O tempo de descanso após \(exerciseName) terminou. Hora de voltar ao treino!"
    }

    private func deliverImmediately(
        title: String,
        body: String,
        category: String,
        identifier: String,
        exerciseName: String? = nil
    ) {
        scheduleOnPhone(
            title: title,
            body: body,
            category: category,
            identifier: identifier,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
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
        trigger: UNNotificationTrigger
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
