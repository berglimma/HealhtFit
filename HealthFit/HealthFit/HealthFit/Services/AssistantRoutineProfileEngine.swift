import Foundation

/// Perfil de rotina aprendido a partir de treinos + check-ins do IAssistente.
struct AssistantRoutineProfile: Equatable {
    var preferredWorkoutHour: Int?
    var preferredWeekdays: [Int]
    var usualSessionsPerWeek: Double
    var recentTiredRate: Double
    var recentPositiveRate: Double
    var usualWindowLabel: String?
    var weekdayHabitLabel: String?
    var summaryLine: String?
    var hasEnoughData: Bool

    static let empty = AssistantRoutineProfile(
        preferredWorkoutHour: nil,
        preferredWeekdays: [],
        usualSessionsPerWeek: 0,
        recentTiredRate: 0,
        recentPositiveRate: 0,
        usualWindowLabel: nil,
        weekdayHabitLabel: nil,
        summaryLine: nil,
        hasEnoughData: false
    )
}

enum AssistantRoutineProfileEngine {
    private static let minSessionsForHabit = 4
    private static let lookbackDays = 45

    static func buildProfile(
        sessions: [WorkoutSession],
        snapshot: AssistantRoutineSnapshot,
        now: Date = .now,
        calendar: Calendar = MotivationMessages.localCalendar
    ) -> AssistantRoutineProfile {
        let cutoff = calendar.date(byAdding: .day, value: -lookbackDays, to: now) ?? now
        let completed = sessions.filter {
            $0.endedAt != nil && ($0.endedAt ?? $0.startedAt) >= cutoff
        }

        let hourBuckets = Dictionary(grouping: completed) { session -> Int in
            calendar.component(.hour, from: session.endedAt ?? session.startedAt)
        }
        let preferredHour = hourBuckets.max { lhs, rhs in
            if lhs.value.count != rhs.value.count {
                return lhs.value.count < rhs.value.count
            }
            return lhs.key > rhs.key
        }?.key

        let weekdayBuckets = Dictionary(grouping: completed) { session -> Int in
            calendar.component(.weekday, from: session.endedAt ?? session.startedAt)
        }
        let topWeekdays = weekdayBuckets
            .sorted { $0.value.count > $1.value.count }
            .prefix(3)
            .filter { $0.value.count >= 2 }
            .map(\.key)

        let weeks = max(1.0, Double(lookbackDays) / 7.0)
        let usualPerWeek = Double(completed.count) / weeks

        let recentMoods = snapshot.moodSamples.filter { $0.recordedAt >= cutoff }
        let tiredKeys: Set<String> = ["tired", "tiring", "stressed", "sore", "unmotivated", "difficult", "anxious"]
        let positiveKeys: Set<String> = ["great", "good", "peaceful", "readyToSleep"]
        let tiredCount = recentMoods.filter { tiredKeys.contains($0.feeling) }.count
        let positiveCount = recentMoods.filter { positiveKeys.contains($0.feeling) }.count
        let moodTotal = max(1, recentMoods.count)
        let tiredRate = Double(tiredCount) / Double(moodTotal)
        let positiveRate = Double(positiveCount) / Double(moodTotal)

        let windowLabel: String? = {
            guard let hour = preferredHour, completed.count >= minSessionsForHabit else { return nil }
            let end = min(23, hour + 2)
            return "entre \(hour)h e \(end)h"
        }()

        let weekdayLabel: String? = {
            guard !topWeekdays.isEmpty, completed.count >= minSessionsForHabit else { return nil }
            let names = topWeekdays.map(weekdayName).joined(separator: ", ")
            return names
        }()

        let hasEnough = completed.count >= minSessionsForHabit || recentMoods.count >= 5
        let summary: String? = {
            guard hasEnough else { return nil }
            var parts: [String] = []
            if let windowLabel {
                parts.append("você costuma treinar \(windowLabel)")
            }
            if let weekdayLabel {
                parts.append("com mais frequência em \(weekdayLabel)")
            }
            if tiredRate >= 0.45 {
                parts.append("e tem relatado cansaço com frequência nos check-ins")
            } else if positiveRate >= 0.55 {
                parts.append("e seus check-ins recentes estão majoritariamente positivos")
            }
            if usualPerWeek >= 1 {
                parts.append(String(format: "média de %.1f treinos/semana", usualPerWeek))
            }
            guard !parts.isEmpty else { return nil }
            return parts.joined(separator: "; ") + "."
        }()

        return AssistantRoutineProfile(
            preferredWorkoutHour: preferredHour,
            preferredWeekdays: Array(topWeekdays),
            usualSessionsPerWeek: usualPerWeek,
            recentTiredRate: tiredRate,
            recentPositiveRate: positiveRate,
            usualWindowLabel: windowLabel,
            weekdayHabitLabel: weekdayLabel,
            summaryLine: summary,
            hasEnoughData: hasEnough
        )
    }

    /// Mensagem proativa: perdeu a janela habitual de treino.
    static func missedWindowMessageIfNeeded(
        athleteName: String,
        profile: AssistantRoutineProfile,
        context: HealthAssistantContext,
        snapshot: AssistantRoutineSnapshot,
        now: Date = .now,
        calendar: Calendar = MotivationMessages.localCalendar
    ) -> String? {
        guard profile.hasEnoughData,
              let hour = profile.preferredWorkoutHour,
              let window = profile.usualWindowLabel else { return nil }

        let dayKey = AssistantRoutineStore.dayKey(for: now)
        if snapshot.lastInsightDayKey == dayKey { return nil }

        let currentHour = calendar.component(.hour, from: now)
        guard currentHour >= hour + 1 else { return nil }

        if !profile.preferredWeekdays.isEmpty {
            let weekday = calendar.component(.weekday, from: now)
            guard profile.preferredWeekdays.contains(weekday) else { return nil }
        }

        if !context.todayWorkoutSessions.isEmpty { return nil }
        if let hours = context.hoursSinceLastWorkout, hours < 20 { return nil }

        let name = athleteName.isEmpty ? "Atleta" : athleteName
        var lines = [
            "\(name), aprendi sua rotina: \(window) costuma ser seu horário de treino.",
            "",
            "Hoje ainda não vi treino registrado nessa janela. Se puder, encaixe mesmo que seja mais curto — consistência vence intensidade isolada.",
        ]
        if profile.recentTiredRate >= 0.45 {
            lines.append("")
            lines.append("Como você tem reportado mais cansaço, prefira um treino leve, mobilidade ou caminhada em vez de forçar carga alta.")
        }
        if let weekdays = profile.weekdayHabitLabel {
            lines.append("")
            lines.append("Seus dias mais fortes costumam ser: \(weekdays).")
        }
        return lines.joined(separator: "\n")
    }

    /// Análise personalizada dos dados (1×/dia), com base na rotina aprendida.
    static func personalizedAnalysisMessageIfNeeded(
        athleteName: String,
        profile: AssistantRoutineProfile,
        context: HealthAssistantContext,
        snapshot: AssistantRoutineSnapshot,
        now: Date = .now
    ) -> String? {
        let dayKey = AssistantRoutineStore.dayKey(for: now)
        if snapshot.lastAnalysisDayKey == dayKey { return nil }

        let hour = MotivationMessages.localCalendar.component(.hour, from: now)
        // Evita competir com check-ins 9h / 21h — janela intermediária.
        guard hour >= 12, hour < 20 else { return nil }

        let name = athleteName.isEmpty ? "Atleta" : athleteName
        var bullets: [String] = []

        if context.weeklyWorkoutCount == 0 {
            bullets.append("Semana ainda sem treinos registrados — retomar hoje muda o ritmo.")
        } else if profile.usualSessionsPerWeek >= 2, Double(context.weeklyWorkoutCount) + 0.5 < profile.usualSessionsPerWeek {
            bullets.append(
                String(
                    format: "Você está abaixo da sua média (%.1f treinos/semana). Já foram %d nesta semana.",
                    profile.usualSessionsPerWeek,
                    context.weeklyWorkoutCount
                )
            )
        } else if context.weeklyWorkoutCount > 0 {
            bullets.append("Treinos na semana: \(context.weeklyWorkoutCount) — bom sinal de constância.")
        }

        if let sleep = context.sleepHours {
            if sleep < 7 {
                bullets.append(String(format: "Sono de hoje: %.1fh — abaixo do ideal (7–9h).", sleep))
            } else if sleep > 9 {
                bullets.append(String(format: "Sono de hoje: %.1fh — acima do recomendado; avalie fadiga acumulada.", sleep))
            }
        }

        if let user = context.user, user.recommendedDailyWaterML > 0 {
            let goal = user.recommendedDailyWaterML
            let pct = Int((Double(context.waterIntakeMl) / Double(goal) * 100).rounded())
            if pct < 60 {
                bullets.append("Hidratação em \(pct)% da meta (\(context.waterIntakeMl) ml de \(goal) ml).")
            }
        }

        if context.hasMealPlan, context.todayMealsTotal > 0 {
            let mealsPct = Int(
                (Double(context.todayMealsCompleted) / Double(context.todayMealsTotal) * 100).rounded()
            )
            if mealsPct < 50 {
                bullets.append("Cardápio de hoje: \(context.todayMealsCompleted)/\(context.todayMealsTotal) refeições — dá para recuperar nas próximas.")
            }
        }

        if profile.recentTiredRate >= 0.4 {
            bullets.append("Seus check-ins recentes apontam cansaço recorrente — priorize recuperação e carga inteligente.")
        } else if profile.recentPositiveRate >= 0.55 {
            bullets.append("Humor e disposição nos check-ins estão positivos — ótimo momento para evoluir com consistência.")
        }

        if let window = profile.usualWindowLabel {
            bullets.append("Janela habitual de treino aprendida: \(window).")
        }

        guard bullets.count >= 2 else { return nil }

        var sections = [
            "\(name), fiz uma leitura personalizada da sua rotina e dos dados de hoje:",
            "",
        ]
        bullets.prefix(5).forEach { sections.append("• \($0)") }
        sections.append("")
        if let summary = profile.summaryLine {
            sections.append("O que aprendi sobre você: \(summary)")
            sections.append("")
        }
        sections.append("Pode me perguntar “o que preciso melhorar?” para um plano mais detalhado.")
        return sections.joined(separator: "\n")
    }

    static func welcomePersonalizationLines(profile: AssistantRoutineProfile) -> [String] {
        guard profile.hasEnoughData else { return [] }
        var lines: [String] = ["Estou aprendendo sua rotina para personalizar os avisos:"]
        if let summary = profile.summaryLine {
            lines.append("• \(summary)")
        } else {
            if let window = profile.usualWindowLabel {
                lines.append("• Horário habitual de treino: \(window)")
            }
            if let days = profile.weekdayHabitLabel {
                lines.append("• Dias mais frequentes: \(days)")
            }
        }
        return lines
    }

    static func morningPersonalizationNote(profile: AssistantRoutineProfile) -> String? {
        guard profile.hasEnoughData else { return nil }
        if profile.recentTiredRate >= 0.45 {
            return "Pelos seus últimos check-ins, o cansaço tem aparecido com frequência — comece o dia com leveza e hidratação."
        }
        if let window = profile.usualWindowLabel {
            return "Pela sua rotina, o treino costuma cair \(window). Se fizer sentido hoje, já deixe esse horário reservado."
        }
        return nil
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
