import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            self.scheduleDailyMotivationNotifications()
        }
    }

    func scheduleDailyMotivationNotifications(hour: Int = 8, minute: Int = 0) {
        cancelDailyMotivationNotifications()

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)

        for dayOffset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = hour
            components.minute = minute

            guard let scheduledDate = calendar.date(from: components), scheduledDate > .now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Hora de treinar! 💪"
            content.body = MotivationMessages.dailyMessage(for: day)
            content.sound = .default
            content.categoryIdentifier = "DAILY_MOTIVATION"

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "daily_motivation_\(dayOffset)",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request)
        }
    }

    func cancelDailyMotivationNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests
                .filter { $0.identifier.hasPrefix("daily_motivation") }
                .map(\.identifier)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    func deliverWorkoutStartNotification(workoutTitle: String, athleteName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Treino iniciado! 🔥"
        content.body = MotivationMessages.workoutStartMessage(workoutTitle: workoutTitle, athleteName: athleteName)
        content.sound = .default
        content.categoryIdentifier = "WORKOUT_START"

        deliverImmediately(content, identifier: "workout_start_\(UUID().uuidString)")
    }

    func deliverWorkoutEndNotification(session: WorkoutSession, athleteName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Treino finalizado! 🏆"
        content.body = MotivationMessages.workoutEndMessage(session: session, athleteName: athleteName)
        content.sound = .default
        content.categoryIdentifier = "WORKOUT_END"

        deliverImmediately(content, identifier: "workout_end_\(UUID().uuidString)")
    }

    func deliverRestOvertimeNotification(exerciseName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Descanso encerrado!"
        content.body = "O tempo de descanso após \(exerciseName) terminou. Hora de voltar ao treino!"
        content.sound = .default
        content.categoryIdentifier = "REST_OVERTIME"

        deliverImmediately(content, identifier: "rest_overtime_\(UUID().uuidString)")
    }

    func scheduleRestReminder(after seconds: TimeInterval, exerciseName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Descanso prolongado!"
        content.body = "Você está descansando há muito tempo após \(exerciseName). Hora de voltar ao treino!"
        content.sound = .default
        content.categoryIdentifier = "REST_REMINDER"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(seconds, 1), repeats: false)
        let request = UNNotificationRequest(
            identifier: "rest_reminder_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func cancelRestReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rest_reminder"])
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.filter { $0.identifier.hasPrefix("rest_reminder") }.map(\.identifier)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    func scheduleWorkoutComplete(title: String) {
        let content = UNMutableNotificationContent()
        content.title = "Treino Concluído! 💪"
        content.body = "Parabéns! Você finalizou \(title). Ótimo trabalho!"
        content.sound = .default

        deliverImmediately(content, identifier: "workout_complete_\(UUID().uuidString)")
    }

    private func deliverImmediately(_ content: UNMutableNotificationContent, identifier: String) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
