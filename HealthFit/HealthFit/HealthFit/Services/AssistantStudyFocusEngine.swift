import Foundation

struct StudyFocusRoutineProfile: Equatable {
    var preferredHour: Int?
    var preferredWeekdays: [Int]
    var usualSessionsPerWeek: Double
    var usualMinutesPerWeek: Double
    var usualWindowLabel: String?
    var weekdayHabitLabel: String?
    var streakDays: Int
    var hasEnoughData: Bool
    var summaryLine: String?

    static let empty = StudyFocusRoutineProfile(
        preferredHour: nil,
        preferredWeekdays: [],
        usualSessionsPerWeek: 0,
        usualMinutesPerWeek: 0,
        usualWindowLabel: nil,
        weekdayHabitLabel: nil,
        streakDays: 0,
        hasEnoughData: false,
        summaryLine: nil
    )
}

/// IAssistente: aprende a rotina de Foco em Estudo e gera avisos de progresso.
enum AssistantStudyFocusEngine {
    private static let minSessionsForHabit = 3
    private static let lookbackDays = 45
    static let inactivityThreshold: TimeInterval = 48 * 60 * 60

    static func studySessions(from sessions: [WorkoutSession]) -> [WorkoutSession] {
        sessions.filter(WeeklyProgressAnalyzer.isStudyFocusSession)
    }

    static func buildProfile(
        sessions: [WorkoutSession],
        now: Date = .now,
        calendar: Calendar = MotivationMessages.localCalendar
    ) -> StudyFocusRoutineProfile {
        let cutoff = calendar.date(byAdding: .day, value: -lookbackDays, to: now) ?? now
        let completed = studySessions(from: sessions).filter {
            ($0.endedAt ?? $0.startedAt) >= cutoff && $0.endedAt != nil
        }

        let hourBuckets = Dictionary(grouping: completed) {
            calendar.component(.hour, from: $0.endedAt ?? $0.startedAt)
        }
        let preferredHour = hourBuckets.max { lhs, rhs in
            if lhs.value.count != rhs.value.count { return lhs.value.count < rhs.value.count }
            return lhs.key > rhs.key
        }?.key

        let weekdayBuckets = Dictionary(grouping: completed) {
            calendar.component(.weekday, from: $0.endedAt ?? $0.startedAt)
        }
        let topWeekdays = weekdayBuckets
            .sorted { $0.value.count > $1.value.count }
            .prefix(3)
            .filter { $0.value.count >= 2 }
            .map(\.key)

        let weeks = max(1.0, Double(lookbackDays) / 7.0)
        let usualPerWeek = Double(completed.count) / weeks
        let minutes = completed.reduce(0.0) { $0 + ($1.duration / 60.0) }
        let usualMinutes = minutes / weeks

        let windowLabel: String? = {
            guard let hour = preferredHour, completed.count >= minSessionsForHabit else { return nil }
            return "entre \(hour)h e \(min(23, hour + 2))h"
        }()

        let weekdayLabel: String? = {
            guard !topWeekdays.isEmpty, completed.count >= minSessionsForHabit else { return nil }
            return topWeekdays.map(weekdayName).joined(separator: ", ")
        }()

        let streak = consecutiveStudyDays(in: completed, through: now, calendar: calendar)
        let hasEnough = completed.count >= minSessionsForHabit

        let summary: String? = {
            guard hasEnough else { return nil }
            var parts: [String] = []
            if let windowLabel { parts.append("você costuma estudar \(windowLabel)") }
            if let weekdayLabel { parts.append("mais em \(weekdayLabel)") }
            if usualPerWeek >= 1 {
                parts.append(String(format: "média de %.1f sessões/semana (%.0f min)", usualPerWeek, usualMinutes))
            }
            if streak >= 2 { parts.append("sequência atual de \(streak) dias") }
            guard !parts.isEmpty else { return nil }
            return parts.joined(separator: "; ") + "."
        }()

        return StudyFocusRoutineProfile(
            preferredHour: preferredHour,
            preferredWeekdays: Array(topWeekdays),
            usualSessionsPerWeek: usualPerWeek,
            usualMinutesPerWeek: usualMinutes,
            usualWindowLabel: windowLabel,
            weekdayHabitLabel: weekdayLabel,
            streakDays: streak,
            hasEnoughData: hasEnough,
            summaryLine: summary
        )
    }

    /// Aviso quando passou a janela habitual de estudo sem sessão.
    static func missedStudyWindowMessageIfNeeded(
        athleteName: String,
        profile: StudyFocusRoutineProfile,
        sessions: [WorkoutSession],
        lastInsightDayKey: String?,
        now: Date = .now,
        calendar: Calendar = MotivationMessages.localCalendar
    ) -> String? {
        guard profile.hasEnoughData,
              let hour = profile.preferredHour,
              let window = profile.usualWindowLabel else { return nil }

        let dayKey = AssistantRoutineStore.dayKey(for: now)
        if lastInsightDayKey == dayKey { return nil }

        let currentHour = calendar.component(.hour, from: now)
        guard currentHour >= hour + 1 else { return nil }

        if !profile.preferredWeekdays.isEmpty {
            let weekday = calendar.component(.weekday, from: now)
            guard profile.preferredWeekdays.contains(weekday) else { return nil }
        }

        let studiedToday = studySessions(from: sessions).contains {
            calendar.isDate($0.endedAt ?? $0.startedAt, inSameDayAs: now)
        }
        if studiedToday { return nil }

        let name = athleteName.isEmpty ? "Atleta" : athleteName
        var lines = [
            "\(name), aprendi sua rotina de **Foco em Estudo**: \(window) costuma ser seu horário.",
            "",
            "Hoje ainda não vi sessão de estudo nessa janela. Mesmo 10–15 minutos mantêm o hábito.",
            "",
            "Abra **Treinos → Meditação → Foco em Estudo** e retome suas prioridades.",
        ]
        if let days = profile.weekdayHabitLabel {
            lines.append("")
            lines.append("Seus dias mais fortes de estudo: \(days).")
        }
        return lines.joined(separator: "\n")
    }

    /// Progresso semanal / sequência (1× por dia).
    static func progressMessageIfNeeded(
        athleteName: String,
        profile: StudyFocusRoutineProfile,
        sessions: [WorkoutSession],
        lastProgressDayKey: String?,
        now: Date = .now,
        calendar: Calendar = MotivationMessages.localCalendar
    ) -> String? {
        let dayKey = AssistantRoutineStore.dayKey(for: now)
        if lastProgressDayKey == dayKey { return nil }

        let hour = calendar.component(.hour, from: now)
        guard hour >= 11, hour < 21 else { return nil }

        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let weekSessions = studySessions(from: sessions).filter {
            ($0.endedAt ?? $0.startedAt) >= weekStart
        }
        let weekMinutes = Int(weekSessions.reduce(0.0) { $0 + ($1.duration / 60.0) }.rounded())
        let weekCount = weekSessions.count

        guard weekCount > 0 || profile.hasEnoughData else { return nil }

        let name = athleteName.isEmpty ? "Atleta" : athleteName
        var bullets: [String] = []
        bullets.append("Esta semana: \(weekCount) sessão\(weekCount == 1 ? "" : "ões") · \(weekMinutes) min de foco.")

        if profile.hasEnoughData, profile.usualSessionsPerWeek >= 1 {
            if Double(weekCount) + 0.4 < profile.usualSessionsPerWeek {
                bullets.append(
                    String(
                        format: "Você está um pouco abaixo da sua média (%.1f sessões/semana).",
                        profile.usualSessionsPerWeek
                    )
                )
            } else if weekCount > 0 {
                bullets.append("Ritmo alinhado (ou acima) da sua média de estudo — ótimo progresso.")
            }
        }

        if profile.streakDays >= 2 {
            bullets.append("Sequência: \(profile.streakDays) dias com Foco em Estudo.")
        }
        if let window = profile.usualWindowLabel {
            bullets.append("Horário aprendido: \(window).")
        }

        guard bullets.count >= 2 else { return nil }

        var lines = [
            "\(name), atualização de progresso no **Foco em Estudo**:",
            "",
        ]
        bullets.prefix(5).forEach { lines.append("• \($0)") }
        lines.append("")
        lines.append("Continue em **Treinos → Meditação → Foco em Estudo**. Estou acompanhando sua rotina.")
        return lines.joined(separator: "\n")
    }

    static func inactivityMessage(athleteName: String) -> String {
        let name = athleteName.isEmpty ? "Atleta" : athleteName
        return """
        Ei, \(name)! Faz cerca de **48 horas** sem Foco em Estudo. 📚

        Manter a rotina de concentração fortalece memória, disciplina e progresso nas suas prioridades.

        **Estímulo:** 15–20 minutos bastam. Abra o card de estudo, marque a prioridade #1 e inicie.

        **Treinos → Meditação → Foco em Estudo**
        """
    }

    static func lastStudyDate(from sessions: [WorkoutSession]) -> Date? {
        studySessions(from: sessions)
            .compactMap { $0.endedAt ?? $0.startedAt }
            .max()
    }

    static func evaluateInactivity(
        sessions: [WorkoutSession],
        recordedStudyAt: Date?,
        now: Date = .now,
        threshold: TimeInterval = inactivityThreshold
    ) -> Date? {
        let reference = lastStudyDate(from: sessions) ?? recordedStudyAt
        guard let reference, now.timeIntervalSince(reference) >= threshold else { return nil }
        return reference
    }

    static func notificationProgressBody(profile: StudyFocusRoutineProfile, weekMinutes: Int, weekCount: Int) -> String {
        if profile.streakDays >= 2 {
            return "\(weekCount) sessões · \(weekMinutes) min esta semana · sequência de \(profile.streakDays) dias. Continue o Foco em Estudo!"
        }
        if weekCount > 0 {
            return "Progresso: \(weekCount) sessão\(weekCount == 1 ? "" : "ões") e \(weekMinutes) min de estudo esta semana."
        }
        if let window = profile.usualWindowLabel {
            return "Sua rotina de estudo costuma ser \(window). Que tal encaixar uma sessão hoje?"
        }
        return "Registre uma sessão de Foco em Estudo para eu aprender sua rotina e acompanhar o progresso."
    }

    private static func consecutiveStudyDays(
        in sessions: [WorkoutSession],
        through date: Date,
        calendar: Calendar
    ) -> Int {
        let keys = Set(sessions.map { AssistantRoutineStore.dayKey(for: $0.endedAt ?? $0.startedAt) })
        guard !keys.isEmpty else { return 0 }
        var streak = 0
        var cursor = date
        while keys.contains(AssistantRoutineStore.dayKey(for: cursor)) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    private static func weekdayName(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "domingo"
        case 2: return "segunda"
        case 3: return "terça"
        case 4: return "quarta"
        case 5: return "quinta"
        case 6: return "sexta"
        case 7: return "sábado"
        default: return "dia \(weekday)"
        }
    }
}
