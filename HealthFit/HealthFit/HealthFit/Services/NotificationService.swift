import Foundation
import UserNotifications

enum WaterReminderConfiguration {
    static let intervalHours = 2
    static let startHour = 8
    static let endHour = 20

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

enum DailyMotivationConfiguration {
    static let hour = 6
    static let minute = 0
    /// Janela pré-agendada (conteúdo rotativo; dispara localmente mesmo sem abrir o app).
    static let scheduledDayCount = 14
}

/// Lembrete de treino às 18:00 com janela de Live Activity de 3h (até 21:00).
enum EveningTrainingNudgeConfiguration {
    static let hour = 18
    static let minute = 0
    static let countdownDuration: TimeInterval = 3 * 60 * 60
    static let notificationIdentifier = "evening_training_nudge"
    static let category = "EVENING_TRAINING_NUDGE"
}

/// Lembretes de registro de suplementação: a cada 3h das 06:00 até ≤ 23:30.
enum SupplementReminderConfiguration {
    static let intervalHours = 3
    static let startHour = 6
    static let startMinute = 0
    /// Último horário permitido para um lembrete (inclusive).
    static let latestAllowedMinutes = 23 * 60 + 30

    /// Slots (hora, minuto): 06:00, 09:00, 12:00, 15:00, 18:00, 21:00
    /// (o próximo intervalo cairia após 23:30 e é omitido).
    static func reminderSlots(
        startHour: Int = startHour,
        startMinute: Int = startMinute,
        intervalHours: Int = intervalHours,
        latestAllowedMinutes: Int = latestAllowedMinutes
    ) -> [(hour: Int, minute: Int)] {
        guard intervalHours > 0 else { return [] }

        var slots: [(hour: Int, minute: Int)] = []
        var total = startHour * 60 + startMinute
        while total <= latestAllowedMinutes {
            slots.append((hour: total / 60, minute: total % 60))
            total += intervalHours * 60
        }
        return slots
    }

    static func slotIdentifier(hour: Int, minute: Int) -> String {
        String(format: "%02d_%02d", hour, minute)
    }
}

/// Horários das refeições: padrão + preferência do usuário; alerta no horário cadastrado.
enum MealReminderConfiguration {
    /// Disparo no horário da refeição (não antecipado).
    static let minutesBeforeMeal = 0

    /// Padrões quando o usuário ainda não personalizou.
    static func defaultMealClock(for mealType: MealType) -> (hour: Int, minute: Int) {
        switch mealType {
        case .breakfast: return (7, 0)
        case .morningSnack: return (10, 0)
        case .lunch: return (12, 30)
        case .afternoonSnack: return (16, 0)
        case .dinner: return (19, 0)
        case .supper: return (21, 30)
        }
    }

    /// Horário efetivo da refeição (cadastro do usuário ou padrão).
    @MainActor
    static func mealClock(for mealType: MealType) -> (hour: Int, minute: Int) {
        NutritionNotificationPreferences.shared.mealClock(for: mealType)
    }

    /// Horário do alerta = horário cadastrado da refeição.
    @MainActor
    static func reminderClock(for mealType: MealType) -> (hour: Int, minute: Int) {
        mealClock(for: mealType)
    }

    @MainActor
    static func formattedMealTime(for mealType: MealType) -> String {
        NutritionNotificationPreferences.shared.formattedMealTime(for: mealType)
    }
}

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let lastWorkoutKey = "healthfit_last_workout_completed_at"
    private let lastCardioKey = "healthfit_last_cardio_completed_at"
    private let lastMeditationKey = "healthfit_last_meditation_completed_at"
    private let inactivityNotifiedKey = "healthfit_inactivity_notified_for_workout_at"
    private let inactivityReminderIdentifier = "workout_inactivity_48h"
    private let cardioInactivityNotifiedKey = "healthfit_inactivity_notified_for_cardio_at"
    private let cardioInactivityReminderIdentifier = "cardio_inactivity_48h"
    private let meditationInactivityNotifiedKey = "healthfit_inactivity_notified_for_meditation_at"
    private let meditationInactivityReminderIdentifier = "meditation_inactivity_48h"
    private let appUsageInactivityNotifiedKey = "healthfit_app_usage_inactivity_notified_for_session"
    private let appUsageInactivityReminderIdentifier = "app_usage_inactivity_48h"
    private let waterReminderIdentifierPrefix = "water_reminder_"
    private let mealReminderIdentifierPrefix = "meal_reminder_"
    private let supplementReminderIdentifierPrefix = "supplement_reminder_"
    private let dailyMotivationIdentifierPrefix = "daily_motivation_"
    private let dailyAssistantCheckInIdentifier = "daily_assistant_checkin_9am"
    private let dailyEveningAssistantCheckInIdentifier = "daily_assistant_checkin_9pm"
    private let eveningTrainingNudgeIdentifier = EveningTrainingNudgeConfiguration.notificationIdentifier
    private let healthIconYellowNotifiedDayKey = "healthfit_health_icon_yellow_notified_day"
    private let healthIconRedNotifiedAnchorKey = "healthfit_health_icon_red_notified_anchor"
    private let healthIconRedReminderIdentifier = "health_icon_red_24h"
    private let assistantCardioNudgeKey = "healthfit_assistant_cardio_nudge_for"
    private let assistantMeditationNudgeKey = "healthfit_assistant_meditation_nudge_for"
    private let mealRemindersEnabledKey = "healthfit_meal_reminders_enabled"
    private let lastRecurringRefreshDayKey = "healthfit.notifications.lastRecurringRefreshDay"

    static let inactivityThreshold: TimeInterval = 48 * 60 * 60

    private init() {}

    private var mealRemindersEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: mealRemindersEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: mealRemindersEnabledKey) }
    }

    private func mealReminderIdentifier(for mealType: MealType) -> String {
        "\(mealReminderIdentifierPrefix)\(String(describing: mealType))"
    }

    private var knownMealReminderIdentifiers: [String] {
        MealType.allCases.map(mealReminderIdentifier(for:))
    }

    private func supplementReminderIdentifier(hour: Int, minute: Int) -> String {
        "\(supplementReminderIdentifierPrefix)\(SupplementReminderConfiguration.slotIdentifier(hour: hour, minute: minute))"
    }

    private var knownSupplementReminderIdentifiers: [String] {
        SupplementReminderConfiguration.reminderSlots().map {
            supplementReminderIdentifier(hour: $0.hour, minute: $0.minute)
        }
    }

    private var knownDailyMotivationIdentifiers: [String] {
        (0..<DailyMotivationConfiguration.scheduledDayCount).map { "\(dailyMotivationIdentifierPrefix)\($0)" }
    }

    private func localTimeComponents(hour: Int, minute: Int) -> DateComponents {
        var components = DateComponents()
        // UNCalendarNotificationTrigger uses the device local zone when timeZone
        // is nil; set both explicitly so wall-clock hours work worldwide.
        components.calendar = Calendar.current
        components.timeZone = .current
        components.hour = hour
        components.minute = minute
        return components
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().delegate = AppNotificationCenterDelegate.shared
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if let error {
                        print("[HealthFit] Falha ao pedir autorização de notificação: \(error.localizedDescription)")
                    }
                    guard granted else {
                        print("[HealthFit] Notificações negadas pelo usuário; lembretes não serão agendados.")
                        return
                    }
                    Task { @MainActor in
                        // Defer bulk scheduling so first launch permission prompt does not freeze UI.
                        await Task.yield()
                        try? await Task.sleep(nanoseconds: 400_000_000)
                        NotificationService.shared.refreshRecurringNotifications(force: true)
                    }
                }
            case .authorized, .provisional, .ephemeral:
                Task { @MainActor in
                    await Task.yield()
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    NotificationService.shared.refreshRecurringNotifications(force: true)
                }
            case .denied:
                print("[HealthFit] Notificações desativadas em Ajustes; reative para receber lembretes de refeição e motivação.")
            @unknown default:
                break
            }
        }
    }

    func refreshRecurringNotifications(force: Bool = false) {
        let today = Calendar.current.startOfDay(for: .now).timeIntervalSince1970
        if !force {
            let last = UserDefaults.standard.double(forKey: lastRecurringRefreshDayKey)
            if last == today { return }
        }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional
                    || settings.authorizationStatus == .ephemeral else {
                print("[HealthFit] Sem permissão de notificação (\(settings.authorizationStatus.rawValue)); recorrentes não agendados.")
                return
            }
            Task { @MainActor in
                UserDefaults.standard.set(today, forKey: NotificationService.shared.lastRecurringRefreshDayKey)
                NotificationService.shared.scheduleAuthorizedRecurringNotifications()
            }
        }
    }

    private func scheduleAuthorizedRecurringNotifications() {
        scheduleDailyMotivationNotifications()
        scheduleDailyAssistantCheckIn()
        scheduleDailyEveningAssistantCheckIn()
        scheduleWaterReminders()
        refreshSupplementRemindersFromPreferences()
        refreshMealRemindersFromPreferences()
    }

    /// Respeita a preferência em Perfil (cardápio não força mais o agendamento).
    func updateMealReminders(hasMealPlan: Bool) {
        _ = hasMealPlan
        refreshMealRemindersFromPreferences()
    }

    func refreshMealRemindersFromPreferences() {
        let enabled = NutritionNotificationPreferences.shared.mealRemindersEnabled
        mealRemindersEnabled = enabled
        if enabled {
            scheduleMealReminders()
        } else {
            cancelMealReminders()
        }
    }

    func refreshSupplementRemindersFromPreferences() {
        if NutritionNotificationPreferences.shared.supplementRemindersEnabled {
            scheduleSupplementReminders()
        } else {
            cancelSupplementReminders()
        }
    }

    func scheduleDailyAssistantCheckIn(
        hour: Int = DailyAssistantCheckInConfiguration.hour,
        minute: Int = 0
    ) {
        cancelDailyAssistantCheckIn()

        // Hours are wall-clock in the device local timezone (not UTC / not Brazil-only).
        let components = localTimeComponents(hour: hour, minute: minute)

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

        // ≥ 21:00 local — rest-oriented body (bom descanso).
        let components = localTimeComponents(hour: hour, minute: minute)

        scheduleOnPhone(
            title: "Como foi seu dia? 🌙",
            body: "Bom descanso! O IAssistente compara calorias gastas × ingeridas e sua hidratação — abra o chat para ver o balanço.",
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

    // MARK: - Evening training nudge (18:00)

    /// Agenda o alerta local que “acorda” o app / avisa na tela bloqueada às 18:00.
    func scheduleEveningTrainingNudge(fireDate: Date, title: String, body: String) {
        cancelEveningTrainingNudge()

        let interval = fireDate.timeIntervalSinceNow
        guard interval > 1 else { return }

        scheduleOnPhone(
            title: title,
            body: body,
            category: EveningTrainingNudgeConfiguration.category,
            identifier: eveningTrainingNudgeIdentifier,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
    }

    /// Entrega imediata (app em primeiro plano na janela 18:00–21:00).
    func deliverEveningTrainingNudge(title: String, body: String) {
        deliverImmediately(
            title: title,
            body: body,
            category: EveningTrainingNudgeConfiguration.category,
            identifier: "\(eveningTrainingNudgeIdentifier)_now_\(UUID().uuidString)",
            immediate: true
        )
    }

    func cancelEveningTrainingNudge() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [eveningTrainingNudgeIdentifier]
        )
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: [eveningTrainingNudgeIdentifier]
        )
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let ids = notifications
                .filter { $0.request.identifier.hasPrefix(self.eveningTrainingNudgeIdentifier) }
                .map(\.request.identifier)
            guard !ids.isEmpty else { return }
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
        }
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
        let hours = WaterReminderConfiguration.reminderHours(
            startHour: startHour,
            endHour: endHour,
            intervalHours: intervalHours
        )
        let prefix = waterReminderIdentifierPrefix
        // Cancela por prefixo e só então agenda — evita corrida que apagava os novos pedidos.
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests
                .filter { $0.identifier.hasPrefix(prefix) }
                .map(\.identifier)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)

            Task { @MainActor in
                let service = NotificationService.shared
                for hour in hours {
                    let components = service.localTimeComponents(hour: hour, minute: minute)

                    service.scheduleOnPhone(
                        title: "Hora de beber água! 💧",
                        body: MotivationMessages.waterReminderMessage(forHour: hour),
                        category: "WATER_REMINDER",
                        identifier: "\(prefix)\(hour)",
                        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                    )
                }
            }
        }
    }

    func cancelWaterReminders() {
        let prefix = waterReminderIdentifierPrefix
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests
                .filter { $0.identifier.hasPrefix(prefix) }
                .map(\.identifier)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    func scheduleMealReminders() {
        // Remoção síncrona por IDs conhecidos — getPending+remove async apagava os alertas
        // recém-agendados a cada refresh (ex.: app voltando ao foreground).
        cancelMealReminders()

        for mealType in MealType.allCases {
            let clock = MealReminderConfiguration.reminderClock(for: mealType)
            let components = localTimeComponents(hour: clock.hour, minute: clock.minute)

            scheduleOnPhone(
                title: "Hora do \(mealType.rawValue) 🍽️",
                body: MotivationMessages.mealReminderMessage(for: mealType),
                category: "MEAL_REMINDER",
                identifier: mealReminderIdentifier(for: mealType),
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
        }
    }

    func cancelMealReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: knownMealReminderIdentifiers
        )
    }

    /// Lembretes locais a cada 3h (06:00–21:00) para registrar suplementação.
    func scheduleSupplementReminders() {
        guard NutritionNotificationPreferences.shared.supplementRemindersEnabled else {
            cancelSupplementReminders()
            return
        }
        // Remoção síncrona por IDs conhecidos — evita corrida com getPending assíncrono no refresh.
        cancelSupplementReminders()

        let bodies = [
            "Que suplemento você tomou? Registre em Nutrição → Suplementos.",
            "Anote whey, creatina ou vitaminas para manter o histórico em dia.",
            "Um registro rápido agora ajuda o IAssistente e o relatório mensal.",
            "Hora de atualizar sua suplementação no HealthFit."
        ]

        for (index, slot) in SupplementReminderConfiguration.reminderSlots().enumerated() {
            let components = localTimeComponents(hour: slot.hour, minute: slot.minute)

            scheduleOnPhone(
                title: "Hora de registrar seu suplemento 💊",
                body: bodies[index % bodies.count],
                category: "SUPPLEMENT_REMINDER",
                identifier: supplementReminderIdentifier(hour: slot.hour, minute: slot.minute),
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
        }
    }

    func cancelSupplementReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: knownSupplementReminderIdentifiers
        )
    }

    // MARK: - Health icon (yellow / red)

    func refreshHealthIconNotifications(
        status: WellnessHealthIconStatus,
        detailMessage: String,
        redFireDate: Date?,
        dayKey: String,
        staleAnchor: Date?
    ) {
        switch status {
        case .green:
            cancelHealthIconRedReminder()
        case .yellow:
            deliverHealthIconYellowIfNeeded(dayKey: dayKey, detailMessage: detailMessage)
            if let redFireDate {
                scheduleHealthIconRedReminder(fireDate: redFireDate, detailMessage: detailMessage, staleAnchor: staleAnchor)
            }
        case .red:
            deliverHealthIconRedIfNeeded(staleAnchor: staleAnchor, detailMessage: detailMessage)
        }
    }

    func cancelHealthIconRedReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [healthIconRedReminderIdentifier]
        )
    }

    /// Estado local das notificações do ícone — sincronizado via `wellnessMeta`.
    func healthIconNotificationStateForSync() -> (yellowDayKey: String?, redAnchor: Date?) {
        (
            UserDefaults.standard.string(forKey: healthIconYellowNotifiedDayKey),
            UserDefaults.standard.object(forKey: healthIconRedNotifiedAnchorKey) as? Date
        )
    }

    func applySyncedHealthIconNotificationState(yellowDayKey: String?, redAnchor: Date?) {
        if let yellowDayKey {
            UserDefaults.standard.set(yellowDayKey, forKey: healthIconYellowNotifiedDayKey)
        }
        if let redAnchor {
            UserDefaults.standard.set(redAnchor, forKey: healthIconRedNotifiedAnchorKey)
        }
    }

    private func deliverHealthIconYellowIfNeeded(dayKey: String, detailMessage: String) {
        let notifiedDay = UserDefaults.standard.string(forKey: healthIconYellowNotifiedDayKey)
        guard notifiedDay != dayKey else { return }

        deliverImmediately(
            title: "Ícone de saúde amarelo ⚠️💛",
            body: MotivationMessages.healthIconYellowMessage(detail: detailMessage),
            category: "HEALTH_ICON_YELLOW",
            identifier: "health_icon_yellow_\(dayKey)"
        )
        UserDefaults.standard.set(dayKey, forKey: healthIconYellowNotifiedDayKey)
    }

    private func scheduleHealthIconRedReminder(fireDate: Date, detailMessage: String, staleAnchor: Date?) {
        cancelHealthIconRedReminder()

        let title = "Ícone de saúde vermelho 🚨❤️"
        let body = MotivationMessages.healthIconRedMessage(detail: detailMessage)

        if fireDate <= .now {
            deliverHealthIconRedIfNeeded(staleAnchor: staleAnchor, detailMessage: detailMessage)
            return
        }

        let interval = fireDate.timeIntervalSinceNow
        scheduleOnPhone(
            title: title,
            body: body,
            category: "HEALTH_ICON_RED",
            identifier: healthIconRedReminderIdentifier,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
    }

    private func deliverHealthIconRedIfNeeded(staleAnchor: Date?, detailMessage: String) {
        if let staleAnchor {
            let notified = UserDefaults.standard.object(forKey: healthIconRedNotifiedAnchorKey) as? Date
            guard notified != staleAnchor else { return }
            UserDefaults.standard.set(staleAnchor, forKey: healthIconRedNotifiedAnchorKey)
        }

        cancelHealthIconRedReminder()
        deliverImmediately(
            title: "Ícone de saúde vermelho 🚨❤️",
            body: MotivationMessages.healthIconRedMessage(detail: detailMessage),
            category: "HEALTH_ICON_RED",
            identifier: "health_icon_red_\(UUID().uuidString)"
        )
    }

    func scheduleDailyMotivationNotifications(
        hour: Int = DailyMotivationConfiguration.hour,
        minute: Int = DailyMotivationConfiguration.minute
    ) {
        cancelDailyMotivationNotifications()

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        var watchEntries: [[String: Any]] = []

        for dayOffset in 0..<DailyMotivationConfiguration.scheduledDayCount {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.calendar = calendar
            components.timeZone = .current
            components.hour = hour
            components.minute = minute

            guard let scheduledDate = calendar.date(from: components), scheduledDate > .now else { continue }

            let title = MotivationMessages.dailyNotificationTitle(for: day)
            let body = MotivationMessages.dailyMessage(for: day)
            let identifier = "\(dailyMotivationIdentifierPrefix)\(dayOffset)"

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
        let knownIds = knownDailyMotivationIdentifiers
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: knownIds
        )
        // Limpa IDs legados (ex.: prefixo antigo sem underscore final) se existirem.
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests
                .filter {
                    $0.identifier.hasPrefix("daily_motivation")
                        && !knownIds.contains($0.identifier)
                }
                .map(\.identifier)
            guard !ids.isEmpty else { return }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
        WatchConnectivityManager.shared.cancelDailyMotivationOnWatch()
    }

    /// Notificação de treino em dupla/equipe (convite, chat, marcação).
    func deliverDuoTeamNotification(
        title: String,
        body: String,
        teamId: String? = nil,
        teamName: String? = nil,
        kind: String? = nil
    ) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var userInfo: [AnyHashable: Any] = [:]
        if let teamId, !teamId.isEmpty { userInfo["teamId"] = teamId }
        if let teamName, !teamName.isEmpty { userInfo["teamName"] = teamName }
        if let kind, !kind.isEmpty { userInfo["kind"] = kind }
        deliverImmediately(
            title: title,
            body: trimmed,
            category: "DUO_TEAM",
            identifier: "duo_team_\(UUID().uuidString)",
            userInfo: userInfo
        )
    }

    /// Alerta local quando o IAssistente entrega uma mensagem completa ao usuário.
    func deliverAssistantMessageNotification(body: String) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let maxLength = 160
        let truncated: String
        if trimmed.count <= maxLength {
            truncated = trimmed
        } else {
            let index = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
            truncated = String(trimmed[..<index]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
        }

        deliverImmediately(
            title: "IAssistente",
            body: truncated,
            category: "ASSISTANT_MESSAGE",
            identifier: "assistant_message_\(UUID().uuidString)"
        )
    }

    func deliverWorkoutStartNotification(workoutTitle: String, athleteName: String) {
        deliverImmediately(
            title: "Treino iniciado! 🔥",
            body: MotivationMessages.workoutStartMessage(workoutTitle: workoutTitle, athleteName: athleteName),
            category: "WORKOUT_START",
            identifier: "workout_start_\(UUID().uuidString)"
        )
    }

    /// Feedback imediato ao tentar iniciar outro treino enquanto já há sessão ativa.
    /// Distinto do antigo lembrete de background “Treino em andamento” (desativado).
    func deliverActiveWorkoutAlreadyInProgressNotification(activeWorkoutTitle: String) {
        let title = activeWorkoutTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let body: String
        if title.isEmpty {
            body = "Você tentou iniciar outro treino, mas já existe um em progresso. Continue ou finalize o treino atual."
        } else {
            body = "Você tentou iniciar outro treino, mas “\(title)” ainda está em progresso. Continue ou finalize o treino atual."
        }
        deliverImmediately(
            title: "Já existe um treino em andamento",
            body: body,
            category: "WORKOUT_ALREADY_ACTIVE",
            identifier: "workout_already_active_\(UUID().uuidString)",
            immediate: true
        )
    }

    /// Desativado: não envia mais a notificação persistente “Treino em andamento”.
    /// Mantido como no-op para não quebrar callers; use `cancelActiveWorkoutBackgroundReminder` para limpar entregues.
    func deliverActiveWorkoutBackgroundReminder(
        workoutTitle _: String,
        exerciseName _: String?,
        sessionId: UUID
    ) {
        cancelActiveWorkoutBackgroundReminder(sessionId: sessionId)
    }

    func cancelActiveWorkoutBackgroundReminder(sessionId: UUID? = nil) {
        if let sessionId {
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: ["workout_background_\(sessionId.uuidString)"]
            )
            UNUserNotificationCenter.current().removeDeliveredNotifications(
                withIdentifiers: ["workout_background_\(sessionId.uuidString)"]
            )
            return
        }
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("workout_background_") }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let ids = notifications
                .map(\.request.identifier)
                .filter { $0.hasPrefix("workout_background_") }
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    func deliverCardioStartNotification(sessionTitle: String, athleteName: String) {
        deliverImmediately(
            title: "Cardio iniciado! 🏃",
            body: MotivationMessages.cardioStartMessage(sessionTitle: sessionTitle, athleteName: athleteName),
            category: "CARDIO_START",
            identifier: "cardio_start_\(UUID().uuidString)"
        )
    }

    func deliverMeditationStartNotification(sessionTitle: String, athleteName: String) {
        deliverImmediately(
            title: "Meditação iniciada 🧘",
            body: MotivationMessages.meditationStartMessage(sessionTitle: sessionTitle, athleteName: athleteName),
            category: "MEDITATION_START",
            identifier: "meditation_start_\(UUID().uuidString)"
        )
    }

    func deliverWorkoutEndNotification(session: WorkoutSession, athleteName: String) {
        if session.autoEndedByInactivity {
            deliverForgottenWorkoutEndNotification(session: session, athleteName: athleteName)
            return
        }

        let titleLower = session.workoutTitle.lowercased()
        let title: String
        let category: String
        if titleLower.hasPrefix("meditação") || titleLower.hasPrefix("meditacao") {
            title = "Meditação concluída 🧘‍♀️"
            category = "MEDITATION_END"
        } else if titleLower.hasPrefix("cardio") {
            title = "Cardio finalizado! 🏆"
            category = "CARDIO_END"
        } else {
            title = "Treino finalizado! 🏆"
            category = "WORKOUT_END"
        }

        deliverImmediately(
            title: title,
            body: MotivationMessages.workoutEndMessage(session: session, athleteName: athleteName),
            category: category,
            identifier: "session_end_\(UUID().uuidString)"
        )
    }

    /// Notificação triste/alerta quando o treino passa de 2h30 sem finalizar.
    func deliverForgottenWorkoutEndNotification(session: WorkoutSession, athleteName: String) {
        deliverImmediately(
            title: "⚠️ Treino encerrado por inatividade",
            body: MotivationMessages.forgottenWorkoutEndNotification(
                workoutTitle: session.workoutTitle,
                athleteName: athleteName
            ),
            category: "WORKOUT_AUTO_END",
            identifier: "workout_auto_end_\(session.id.uuidString)",
            immediate: true
        )
    }

    func scheduleActiveWorkoutAutoEnd(sessionId: UUID, workoutTitle: String, fireDate: Date) {
        cancelActiveWorkoutAutoEnd(sessionId: sessionId)
        let interval = fireDate.timeIntervalSince(.now)
        guard interval > 1 else {
            deliverImmediately(
                title: "⚠️ Treino aberto há muito tempo",
                body: MotivationMessages.forgottenWorkoutEndNotification(
                    workoutTitle: workoutTitle,
                    athleteName: "Atleta"
                ),
                category: "WORKOUT_AUTO_END",
                identifier: "workout_auto_end_\(sessionId.uuidString)",
                immediate: true
            )
            return
        }

        scheduleOnPhone(
            title: "⚠️ Você esqueceu de encerrar o treino?",
            body: MotivationMessages.forgottenWorkoutPendingNotification(workoutTitle: workoutTitle),
            category: "WORKOUT_AUTO_END",
            identifier: "workout_auto_end_\(sessionId.uuidString)",
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
    }

    func cancelActiveWorkoutAutoEnd(sessionId: UUID? = nil) {
        if let sessionId {
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: ["workout_auto_end_\(sessionId.uuidString)"]
            )
            UNUserNotificationCenter.current().removeDeliveredNotifications(
                withIdentifiers: ["workout_auto_end_\(sessionId.uuidString)"]
            )
            return
        }
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests
                .filter { $0.identifier.hasPrefix("workout_auto_end_") }
                .map(\.identifier)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Evolução corporal

    private static let bodyEvolutionReadyPrefix = "body_evolution_ready_"
    private static let bodyEvolutionResultId = "body_evolution_result"

    func scheduleBodyEvolutionReady(fireDate: Date, userId: String) {
        cancelBodyEvolutionReadyReminder()
        let identifier = Self.bodyEvolutionReadyPrefix + userId
        let interval = fireDate.timeIntervalSince(.now)
        let body = "Já passaram 30 dias do seu acompanhamento de evolução. Abra Evolução Corporal para comparar as medidas (fotos continuam opcionais e privadas)."

        if interval <= 1 {
            deliverImmediately(
                title: "Evolução corporal",
                body: body,
                category: "BODY_EVOLUTION_READY",
                identifier: identifier,
                immediate: true
            )
            return
        }

        scheduleOnPhone(
            title: "Evolução corporal",
            body: body,
            category: "BODY_EVOLUTION_READY",
            identifier: identifier,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
    }

    func cancelBodyEvolutionReadyReminder() {
        let prefix = Self.bodyEvolutionReadyPrefix
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests
                .filter { $0.identifier.hasPrefix(prefix) }
                .map(\.identifier)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let ids = notifications
                .filter { $0.request.identifier.hasPrefix(prefix) }
                .map(\.request.identifier)
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    func deliverBodyEvolutionResult(summary: String) {
        deliverImmediately(
            title: "IAssistente · Evolução corporal",
            body: summary,
            category: "BODY_EVOLUTION_RESULT",
            identifier: Self.bodyEvolutionResultId,
            immediate: true
        )
    }

    func deliverRestOvertimeNotification(exerciseName: String) {
        deliverRestCompleteNotification(exerciseName: exerciseName)
    }

    func deliverRestCompleteNotification(exerciseName: String) {
        // Só notifica o iPhone aqui; o Watch já recebe restOvertime / restTimer.
        let content = UNMutableNotificationContent()
        content.title = Self.restCompleteTitle
        content.body = Self.restCompleteBody(exerciseName: exerciseName)
        content.sound = .default
        content.categoryIdentifier = "REST_COMPLETE"
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: Self.restEndReminderIdentifier,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Agenda lembrete exatamente para o fim da pausa (não notifica no início).
    func scheduleRestEndReminder(after seconds: TimeInterval, exerciseName: String) {
        cancelRestReminders()

        let delay = max(seconds, 1)
        let content = UNMutableNotificationContent()
        content.title = Self.restCompleteTitle
        content.body = Self.restCompleteBody(exerciseName: exerciseName)
        content.sound = .default
        content.categoryIdentifier = "REST_COMPLETE"
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: Self.restEndReminderIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleRestReminder(after seconds: TimeInterval, exerciseName: String) {
        scheduleRestEndReminder(after: seconds, exerciseName: exerciseName)
    }

    func cancelRestReminders() {
        let knownIds = [
            Self.restEndReminderIdentifier,
            "rest_reminder"
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: knownIds)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: knownIds)

        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("rest_reminder") || $0.hasPrefix("rest_complete_") }
            guard !ids.isEmpty else { return }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let ids = notifications
                .map(\.request.identifier)
                .filter { $0.hasPrefix("rest_reminder") || $0.hasPrefix("rest_complete_") }
            guard !ids.isEmpty else { return }
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    private static let restEndReminderIdentifier = "rest_end_reminder"

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

    // MARK: - Inspeção de equipamento de escalada

    func deliverClimbingGearInspectionAlert(overdueNames: [String], dueSoonNames: [String]) {
        let names = overdueNames + dueSoonNames
        guard !names.isEmpty else { return }

        let title = overdueNames.isEmpty
            ? "Inspeção de equipamento próxima 🧗"
            : "Inspecione seu equipamento antes de subir 🧗"

        let body: String = {
            let listed = names.prefix(3).joined(separator: ", ")
            let remainder = names.count - min(3, names.count)
            let suffix = remainder > 0 ? " e mais \(remainder)" : ""
            if overdueNames.isEmpty {
                return "\(listed)\(suffix) estão perto do limite de usos ou de tempo de serviço."
            }
            return "\(listed)\(suffix) passaram do limite de usos ou de tempo de serviço. Revise antes da próxima escalada."
        }()

        deliverImmediately(
            title: title,
            body: body,
            category: "CLIMBING_GEAR_INSPECTION",
            identifier: "climbing_gear_inspection_\(UUID().uuidString)"
        )
    }

    func recordWorkoutCompleted(at date: Date = .now) {
        UserDefaults.standard.set(date, forKey: lastWorkoutKey)
        UserDefaults.standard.removeObject(forKey: inactivityNotifiedKey)
        refreshWorkoutInactivityReminder(lastWorkoutAt: date)
    }

    func recordCardioCompleted(at date: Date = .now) {
        UserDefaults.standard.set(date, forKey: lastCardioKey)
        UserDefaults.standard.removeObject(forKey: cardioInactivityNotifiedKey)
        UserDefaults.standard.removeObject(forKey: assistantCardioNudgeKey)
        refreshCardioInactivityReminder(lastCardioAt: date)
    }

    func recordMeditationCompleted(at date: Date = .now) {
        UserDefaults.standard.set(date, forKey: lastMeditationKey)
        UserDefaults.standard.removeObject(forKey: meditationInactivityNotifiedKey)
        UserDefaults.standard.removeObject(forKey: assistantMeditationNudgeKey)
        refreshMeditationInactivityReminder(lastMeditationAt: date)
    }

    func refreshWorkoutInactivityReminder(lastWorkoutAt: Date?, accountCreatedAt: Date? = nil) {
        cancelWorkoutInactivityReminder()

        let referenceDate = lastWorkoutAt ?? accountCreatedAt
        guard let referenceDate else { return }

        let fireDate = referenceDate.addingTimeInterval(Self.inactivityThreshold)
        let title = "Hora de voltar a treinar! 💪"
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

    func refreshCardioInactivityReminder(lastCardioAt: Date?, accountCreatedAt: Date? = nil) {
        cancelCardioInactivityReminder()

        let referenceDate = lastCardioAt ?? accountCreatedAt
        guard let referenceDate else { return }

        let fireDate = referenceDate.addingTimeInterval(Self.inactivityThreshold)
        let title = "Cardio te espera! 🏃💨"
        let body = MotivationMessages.cardioInactivityMessage()

        if fireDate <= .now {
            Task {
                await deliverTypedInactivityIfNeeded(
                    referenceAt: referenceDate,
                    notifiedKey: cardioInactivityNotifiedKey,
                    category: "CARDIO_INACTIVITY",
                    title: title,
                    body: body
                )
            }
        } else {
            let interval = fireDate.timeIntervalSinceNow
            scheduleOnPhone(
                title: title,
                body: body,
                category: "CARDIO_INACTIVITY",
                identifier: cardioInactivityReminderIdentifier,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            )
        }
    }

    func refreshMeditationInactivityReminder(lastMeditationAt: Date?, accountCreatedAt: Date? = nil) {
        cancelMeditationInactivityReminder()

        let referenceDate = lastMeditationAt ?? accountCreatedAt
        guard let referenceDate else { return }

        let fireDate = referenceDate.addingTimeInterval(Self.inactivityThreshold)
        let title = "Hora de meditar 🧘✨"
        let body = MotivationMessages.meditationInactivityMessage()

        if fireDate <= .now {
            Task {
                await deliverTypedInactivityIfNeeded(
                    referenceAt: referenceDate,
                    notifiedKey: meditationInactivityNotifiedKey,
                    category: "MEDITATION_INACTIVITY",
                    title: title,
                    body: body
                )
            }
        } else {
            let interval = fireDate.timeIntervalSinceNow
            scheduleOnPhone(
                title: title,
                body: body,
                category: "MEDITATION_INACTIVITY",
                identifier: meditationInactivityReminderIdentifier,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            )
        }
    }

    func cancelWorkoutInactivityReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [inactivityReminderIdentifier]
        )
        WatchConnectivityManager.shared.cancelInactivityReminderOnWatch()
    }

    func cancelCardioInactivityReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [cardioInactivityReminderIdentifier]
        )
    }

    func cancelMeditationInactivityReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [meditationInactivityReminderIdentifier]
        )
    }

    /// Marca que o IAssistente já enviou o estímulo de cardio/meditação para este período.
    func markAssistantCardioNudgeDelivered(for referenceDate: Date) {
        UserDefaults.standard.set(referenceDate, forKey: assistantCardioNudgeKey)
    }

    func markAssistantMeditationNudgeDelivered(for referenceDate: Date) {
        UserDefaults.standard.set(referenceDate, forKey: assistantMeditationNudgeKey)
    }

    func hasAssistantCardioNudge(for referenceDate: Date) -> Bool {
        (UserDefaults.standard.object(forKey: assistantCardioNudgeKey) as? Date) == referenceDate
    }

    func hasAssistantMeditationNudge(for referenceDate: Date) -> Bool {
        (UserDefaults.standard.object(forKey: assistantMeditationNudgeKey) as? Date) == referenceDate
    }

    var lastRecordedCardioAt: Date? {
        UserDefaults.standard.object(forKey: lastCardioKey) as? Date
    }

    var lastRecordedMeditationAt: Date? {
        UserDefaults.standard.object(forKey: lastMeditationKey) as? Date
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
        await deliverTypedInactivityIfNeeded(
            referenceAt: referenceWorkoutAt,
            notifiedKey: inactivityNotifiedKey,
            category: "WORKOUT_INACTIVITY",
            title: title,
            body: body
        )
    }

    private func deliverTypedInactivityIfNeeded(
        referenceAt: Date,
        notifiedKey: String,
        category: String,
        title: String,
        body: String
    ) async {
        let notifiedFor = UserDefaults.standard.object(forKey: notifiedKey) as? Date
        guard notifiedFor != referenceAt else { return }

        let delivered = await pendingDeliveredNotifications()
        let alreadyShown = delivered.contains {
            $0.request.content.categoryIdentifier == category
        }

        if alreadyShown {
            UserDefaults.standard.set(referenceAt, forKey: notifiedKey)
            return
        }

        deliverImmediately(
            title: title,
            body: body,
            category: category,
            identifier: "\(category.lowercased())_\(UUID().uuidString)"
        )
        UserDefaults.standard.set(referenceAt, forKey: notifiedKey)
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
        immediate: Bool = false,
        userInfo: [AnyHashable: Any] = [:]
    ) {
        let trigger: UNNotificationTrigger? = immediate
            ? nil
            : UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        scheduleOnPhone(
            title: title,
            body: body,
            category: category,
            identifier: identifier,
            trigger: trigger,
            userInfo: userInfo
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
        trigger: UNNotificationTrigger?,
        userInfo: [AnyHashable: Any] = [:]
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category
        content.interruptionLevel = .timeSensitive
        if !userInfo.isEmpty {
            content.userInfo = userInfo
        }

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[HealthFit] Falha ao agendar notificação \(identifier): \(error.localizedDescription)")
            }
        }
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
        if notification.request.content.categoryIdentifier == EveningTrainingNudgeConfiguration.category {
            Task { @MainActor in
                EveningTrainingNudgeService.handleNotificationWake()
            }
        }
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let content = response.notification.request.content
        if content.categoryIdentifier == EveningTrainingNudgeConfiguration.category {
            Task { @MainActor in
                EveningTrainingNudgeService.handleNotificationWake()
            }
        }
        Task { @MainActor in
            DuoNavigationRouter.shared.handleNotificationUserInfo(
                content.userInfo,
                category: content.categoryIdentifier
            )
            CoachNavigationRouter.shared.handleNotificationUserInfo(
                content.userInfo,
                category: content.categoryIdentifier
            )
        }
        completionHandler()
    }
}
