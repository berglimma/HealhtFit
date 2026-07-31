import Foundation

/// Orquestra o lembrete das 18:00: notificação local + Live Activity com countdown de 3h.
@MainActor
enum EveningTrainingNudgeService {
    private static let shownDayKey = "healthfit_evening_nudge_shown_day"
    private static let historyKey = "healthfit_session_history"
    private static let activeSessionKey = "healthfit_active_session"

    static let statusMessage = "Você ainda não treinou hoje"
    static let notificationTitle = "HealthFit · Hora de treinar"

    // MARK: - Trained today

    static func hasTrainedToday(
        sessions: [WorkoutSession],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> Bool {
        sessions.contains { session in
            guard let endedAt = session.endedAt else { return false }
            return calendar.isDate(endedAt, inSameDayAs: now)
        }
    }

    static func dayKey(for date: Date = .now, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            parts.year ?? 0,
            parts.month ?? 0,
            parts.day ?? 0
        )
    }

    /// Início da janela (18:00) e fim do countdown (21:00) no dia local de `now`.
    static func nudgeWindow(
        on date: Date = .now,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date)? {
        let startOfDay = calendar.startOfDay(for: date)
        guard let start = calendar.date(
            bySettingHour: EveningTrainingNudgeConfiguration.hour,
            minute: EveningTrainingNudgeConfiguration.minute,
            second: 0,
            of: startOfDay
        ) else { return nil }
        let end = start.addingTimeInterval(EveningTrainingNudgeConfiguration.countdownDuration)
        return (start, end)
    }

    // MARK: - Lifecycle

    /// Chamado no launch/foreground e após sync de histórico.
    static func refresh(workoutStore: WorkoutStore) {
        refresh(
            sessions: workoutStore.sessionHistory,
            hasActiveWorkout: workoutStore.activeSession != nil
        )
    }

    /// Avalia sem `WorkoutStore` (ex.: delegate de notificação).
    static func refreshFromPersistedState() {
        let sessions = loadPersistedSessions()
        let hasActive = UserDefaults.standard.data(forKey: activeSessionKey) != nil
        refresh(sessions: sessions, hasActiveWorkout: hasActive)
    }

    static func handleNotificationWake() {
        refreshFromPersistedState()
    }

    /// Treino ativo iniciado → não mostrar nudge em paralelo.
    static func handleActiveWorkoutStarted() {
        EveningTrainingNudgeController.shared.end()
        NotificationService.shared.cancelEveningTrainingNudge()
        scheduleNextFire(after: .now, calendar: .current, skipToday: true)
    }

    /// Treino concluído hoje → cancela notificação e encerra Live Activity.
    static func handleWorkoutCompleted() {
        NotificationService.shared.cancelEveningTrainingNudge()
        EveningTrainingNudgeController.shared.end()
        UserDefaults.standard.set(dayKey(), forKey: shownDayKey)
        scheduleNextFire(after: .now, calendar: .current, skipToday: true)
    }

    static func cancelAll() {
        NotificationService.shared.cancelEveningTrainingNudge()
        EveningTrainingNudgeController.shared.end()
        UserDefaults.standard.removeObject(forKey: shownDayKey)
    }

    // MARK: - Core

    private static func refresh(
        sessions: [WorkoutSession],
        hasActiveWorkout: Bool,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        guard let window = nudgeWindow(on: now, calendar: calendar) else { return }
        let todayKey = dayKey(for: now, calendar: calendar)
        let trained = hasTrainedToday(sessions: sessions, calendar: calendar, now: now)

        if trained || hasActiveWorkout {
            NotificationService.shared.cancelEveningTrainingNudge()
            EveningTrainingNudgeController.shared.end()
            if trained {
                UserDefaults.standard.set(todayKey, forKey: shownDayKey)
            }
            // Agenda o próximo dia às 18:00 se já treinou hoje (ou há treino ativo).
            scheduleNextFire(after: now, calendar: calendar, skipToday: true)
            return
        }

        if now >= window.start && now < window.end {
            presentNudgeIfNeeded(
                dayKey: todayKey,
                endDate: window.end,
                now: now
            )
            // Já estamos na janela — próxima ocorrência é amanhã.
            scheduleNextFire(after: now, calendar: calendar, skipToday: true)
            return
        }

        if now < window.start {
            let motivation = MotivationMessages.eveningTrainingNudgeMessage(for: now)
            NotificationService.shared.scheduleEveningTrainingNudge(
                fireDate: window.start,
                title: notificationTitle,
                body: "\(statusMessage)\n\(motivation)"
            )
            return
        }

        // Passou das 21:00 sem treinar — só agenda amanhã.
        EveningTrainingNudgeController.shared.end()
        scheduleNextFire(after: now, calendar: calendar, skipToday: true)
    }

    private static func presentNudgeIfNeeded(dayKey: String, endDate: Date, now: Date) {
        let alreadyShown = UserDefaults.standard.string(forKey: shownDayKey) == dayKey
        let motivation = MotivationMessages.eveningTrainingNudgeMessage(for: now)

        if !alreadyShown {
            NotificationService.shared.deliverEveningTrainingNudge(
                title: notificationTitle,
                body: "\(statusMessage)\n\(motivation)"
            )
            UserDefaults.standard.set(dayKey, forKey: shownDayKey)
        }

        if !EveningTrainingNudgeController.shared.isActive {
            EveningTrainingNudgeController.shared.start(
                dayKey: dayKey,
                statusMessage: statusMessage,
                motivationalMessage: motivation,
                endDate: endDate
            )
        }
    }

    private static func scheduleNextFire(
        after now: Date,
        calendar: Calendar,
        skipToday: Bool
    ) {
        let startOfToday = calendar.startOfDay(for: now)
        let dayOffset = skipToday ? 1 : 0
        guard let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday),
              let fire = calendar.date(
                bySettingHour: EveningTrainingNudgeConfiguration.hour,
                minute: EveningTrainingNudgeConfiguration.minute,
                second: 0,
                of: targetDay
              ) else { return }

        let motivation = MotivationMessages.eveningTrainingNudgeMessage(for: fire)
        NotificationService.shared.scheduleEveningTrainingNudge(
            fireDate: fire,
            title: notificationTitle,
            body: "\(statusMessage)\n\(motivation)"
        )
    }

    private static func loadPersistedSessions() -> [WorkoutSession] {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let sessions = try? JSONDecoder().decode([WorkoutSession].self, from: data) else {
            return []
        }
        return sessions
    }
}
