import Foundation

/// Parabéns de aniversário do IAssistente — somente no dia do aniversário, 1×.
/// A mensagem só conta como enviada depois de aparecer no chat do IAssistente.
enum AssistantBirthdayCongratsEngine {
    private static let lastDeliveredDayKey = "assistant.birthdayCongrats.lastDeliveredDay"
    private static let pendingMessageKey = "assistant.birthdayCongrats.pendingMessage"
    private static let pendingDayKey = "assistant.birthdayCongrats.pendingDay"
    private static let legacyYearKey = "assistant.birthdayCongrats.lastDeliveredYear"

    /// Corrige builds que marcavam “entregue” antes de aparecer no chat.
    private static let deliveryFixVersionKey = "assistant.birthdayCongrats.fixV2"

    static func prepareForSession() {
        clearLegacyYearKeyIfNeeded()
        if !UserDefaults.standard.bool(forKey: deliveryFixVersionKey) {
            UserDefaults.standard.removeObject(forKey: lastDeliveredDayKey)
            UserDefaults.standard.set(true, forKey: deliveryFixVersionKey)
        }
        clearStalePending()
    }

    /// Compara mês/dia no fuso local; se falhar, tenta componentes em UTC (comum em Timestamp do Firebase).
    static func isBirthday(dateOfBirth: Date?, on day: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let dateOfBirth else { return false }
        let today = monthDay(from: day, calendar: calendar)
        if matchesBirthday(birth: monthDay(from: dateOfBirth, calendar: calendar), today: today, on: day, calendar: calendar) {
            return true
        }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        return matchesBirthday(birth: monthDay(from: dateOfBirth, calendar: utc), today: today, on: day, calendar: calendar)
    }

    /// Ainda não mostrou no IAssistente hoje e hoje é aniversário.
    static func shouldDeliver(dateOfBirth: Date?, now: Date = .now) -> Bool {
        prepareForSession()
        guard isBirthday(dateOfBirth: dateOfBirth, on: now) else {
            clearStalePending(now: now)
            return false
        }
        if hasPendingMessage(for: now) { return true }
        let todayKey = DailyWellnessEntry.dayKey(for: now)
        return UserDefaults.standard.string(forKey: lastDeliveredDayKey) != todayKey
    }

    static func markDelivered(now: Date = .now) {
        let todayKey = DailyWellnessEntry.dayKey(for: now)
        UserDefaults.standard.set(todayKey, forKey: lastDeliveredDayKey)
        clearPendingMessage()
    }

    /// Abertura do app no aniversário: enfileira para o chat + notificação curta.
    /// Não marca como entregue — isso só acontece quando o IAssistente exibe a mensagem.
    @MainActor
    static func queueIfNeeded(athleteName: String, dateOfBirth: Date?) {
        prepareForSession()
        guard isBirthday(dateOfBirth: dateOfBirth) else {
            clearStalePending()
            return
        }
        let todayKey = DailyWellnessEntry.dayKey(for: .now)
        if UserDefaults.standard.string(forKey: lastDeliveredDayKey) == todayKey {
            return
        }
        if hasPendingMessage(for: .now) {
            PostWorkoutCheckInService.shared.notifyAssistantMessagePending()
            return
        }

        let text = message(athleteName: athleteName)
        UserDefaults.standard.set(text, forKey: pendingMessageKey)
        UserDefaults.standard.set(todayKey, forKey: pendingDayKey)
        PostWorkoutCheckInService.shared.notifyAssistantMessagePending()

        let shortName = athleteName.trimmingCharacters(in: .whitespacesAndNewlines)
        let who = shortName.isEmpty ? "Atleta" : shortName
        NotificationService.shared.deliverAssistantMessageNotification(
            body: "🎂 Feliz aniversário, \(who)! O mundo precisa de você — abra o IAssistente."
        )
    }

    /// Pendência do dia — não depende de `dateOfBirth` (já validado na fila).
    static func consumePendingMessage(now: Date = .now) -> String? {
        clearStalePending(now: now)
        let todayKey = DailyWellnessEntry.dayKey(for: now)
        guard UserDefaults.standard.string(forKey: pendingDayKey) == todayKey,
              let message = UserDefaults.standard.string(forKey: pendingMessageKey),
              !message.isEmpty else { return nil }
        UserDefaults.standard.removeObject(forKey: pendingMessageKey)
        UserDefaults.standard.removeObject(forKey: pendingDayKey)
        return message
    }

    static func hasPendingMessage(for now: Date = .now) -> Bool {
        let todayKey = DailyWellnessEntry.dayKey(for: now)
        guard UserDefaults.standard.string(forKey: pendingDayKey) == todayKey else { return false }
        let text = UserDefaults.standard.string(forKey: pendingMessageKey) ?? ""
        return !text.isEmpty
    }

    static func hasDelivered(on now: Date = .now) -> Bool {
        let todayKey = DailyWellnessEntry.dayKey(for: now)
        return UserDefaults.standard.string(forKey: lastDeliveredDayKey) == todayKey
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: lastDeliveredDayKey)
        UserDefaults.standard.removeObject(forKey: pendingMessageKey)
        UserDefaults.standard.removeObject(forKey: pendingDayKey)
        UserDefaults.standard.removeObject(forKey: legacyYearKey)
        UserDefaults.standard.removeObject(forKey: deliveryFixVersionKey)
    }

    static func message(athleteName: String) -> String {
        let name = athleteName.trimmingCharacters(in: .whitespacesAndNewlines)
        let who = name.isEmpty ? "você" : name

        return """
        🎂 Feliz aniversário, \(who)!

        Hoje o calendário marca mais do que uma data — marca a prova viva de que você existe, resiste e escolhe continuar. Em um mundo que às vezes parece barulhento demais, a sua presença é silêncio com sentido: alguém que treina o corpo, cuida da mente e não desiste de si.

        Que este novo ciclo te lembre de três verdades simples:
        • Foco — a direção que transforma desejo em caminho.
        • Força — não a que grita, mas a que levanta de novo quando o dia pesa.
        • Esperança — a filosofia quieta de quem planta hoje o que o amanhã colherá.

        O mundo precisa de você. Precisa do seu exemplo, da sua constância, do seu jeito de ser luz mesmo nos dias nublados. Não porque você seja perfeito — mas porque, ao cuidar de si, você inspira outros a acreditar que também é possível.

        Celebre com orgulho. Respire fundo. E siga: o melhor de você ainda está sendo escrito — e o HealthFit caminha com você em cada passo.

        Com carinho,
        IAssistente 💚
        """
    }

    // MARK: - Private

    private static func matchesBirthday(
        birth: (month: Int, day: Int),
        today: (month: Int, day: Int),
        on day: Date,
        calendar: Calendar
    ) -> Bool {
        guard birth.month > 0, birth.day > 0 else { return false }
        if birth.month == 2, birth.day == 29 {
            let isLeap = calendar.range(of: .day, in: .month, for: day)?.count == 29
            if isLeap {
                return today.month == 2 && today.day == 29
            }
            return today.month == 2 && today.day == 28
        }
        return birth.month == today.month && birth.day == today.day
    }

    private static func monthDay(from date: Date, calendar: Calendar) -> (month: Int, day: Int) {
        let parts = calendar.dateComponents([.month, .day], from: date)
        return (parts.month ?? 0, parts.day ?? 0)
    }

    private static func clearPendingMessage() {
        UserDefaults.standard.removeObject(forKey: pendingMessageKey)
        UserDefaults.standard.removeObject(forKey: pendingDayKey)
    }

    private static func clearStalePending(now: Date = .now) {
        let todayKey = DailyWellnessEntry.dayKey(for: now)
        if let pendingDay = UserDefaults.standard.string(forKey: pendingDayKey), pendingDay != todayKey {
            clearPendingMessage()
        }
    }

    private static func clearLegacyYearKeyIfNeeded() {
        guard UserDefaults.standard.object(forKey: legacyYearKey) != nil else { return }
        UserDefaults.standard.removeObject(forKey: legacyYearKey)
    }
}
