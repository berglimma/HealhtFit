import Foundation

extension Notification.Name {
    static let healthFitSupplementLogged = Notification.Name("healthFitSupplementLogged")
}

/// Engajamento do IAssistente sobre registro de suplementação (proativo 1×/dia + reação ao log).
@MainActor
enum AssistantSupplementNudgeEngine {
    private static let pendingAckKey = "healthfit_pending_supplement_ack"
    private static let nudgeDayKey = "healthfit_supplement_nudge_day"
    private static let ackNotifiedDayKey = "healthfit_supplement_ack_notified_day"

    // MARK: - Proactive daily nudge

    static func shouldDeliverDailyNudge(
        todayIntakes: [SupplementIntakeEntry],
        now: Date = .now
    ) -> Bool {
        let dayKey = DailyWellnessEntry.dayKey(for: now)
        if UserDefaults.standard.string(forKey: nudgeDayKey) == dayKey {
            return false
        }
        // Se já registrou hoje, o incentivo proativo não é necessário.
        return todayIntakes.isEmpty
    }

    static func markDailyNudgeDelivered(now: Date = .now) {
        UserDefaults.standard.set(DailyWellnessEntry.dayKey(for: now), forKey: nudgeDayKey)
    }

    static func dailyNudgeMessage(athleteName: String) -> String {
        let name = athleteName.isEmpty ? "Atleta" : athleteName
        return """
        Ei, \(name)! Ainda não registrou suplementação hoje. 💊

        Anotar o que você toma (whey, creatina, vitaminas…) ajuda a manter consistência e a acompanhar no relatório mensal.

        Abra **Nutrição → Suplementos**, escolha o item, ajuste a quantidade e toque em registrar.

        Se quiser, pergunte aqui sobre timing, doses ou qual suplemento combina com o seu objetivo. Estou no IAssistente! 🌿
        """
    }

    // MARK: - Acknowledgment after logging

    static func acknowledgmentMessage(for intake: SupplementIntakeEntry, athleteName: String) -> String {
        let name = athleteName.isEmpty ? "Atleta" : athleteName
        return """
        Registrado, \(name)! ✅ \(intake.name) — \(intake.quantityDisplay).

        Consistência diária vale mais que dose alta. Continue em **Nutrição → Suplementos** quando tomar o próximo.

        Qualquer dúvida sobre timing ou combinação, é só perguntar aqui no IAssistente.
        """
    }

    static func queueLoggedAcknowledgment(_ intake: SupplementIntakeEntry, athleteName: String) {
        let message = acknowledgmentMessage(for: intake, athleteName: athleteName)
        UserDefaults.standard.set(message, forKey: pendingAckKey)
        PostWorkoutCheckInService.shared.notifyAssistantMessagePending()

        let dayKey = DailyWellnessEntry.dayKey(for: .now)
        let alreadyNotifiedToday = UserDefaults.standard.string(forKey: ackNotifiedDayKey) == dayKey
        if !alreadyNotifiedToday {
            NotificationService.shared.deliverAssistantMessageNotification(
                body: "Registrado: \(intake.name) (\(intake.quantityDisplay)). Continue em Nutrição → Suplementos."
            )
            UserDefaults.standard.set(dayKey, forKey: ackNotifiedDayKey)
        }

        NotificationCenter.default.post(
            name: .healthFitSupplementLogged,
            object: nil,
            userInfo: ["message": message]
        )
    }

    static func consumePendingAcknowledgment() -> String? {
        guard let message = UserDefaults.standard.string(forKey: pendingAckKey),
              !message.isEmpty else { return nil }
        UserDefaults.standard.removeObject(forKey: pendingAckKey)
        return message
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: pendingAckKey)
        UserDefaults.standard.removeObject(forKey: nudgeDayKey)
        UserDefaults.standard.removeObject(forKey: ackNotifiedDayKey)
    }
}
