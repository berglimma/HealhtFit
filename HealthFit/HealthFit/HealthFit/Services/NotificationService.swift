import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
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

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "workout_complete", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
