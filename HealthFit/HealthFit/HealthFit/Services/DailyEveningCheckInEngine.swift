import Foundation

enum DailyEveningDayFeeling: Equatable {
    case great
    case good
    case tiring
    case difficult
    case unmotivated
    case skippedWorkout
    case neutral
}

enum DailyEveningRestReadiness: Equatable {
    case readyToSleep
    case restless
    case sore
    case anxious
    case peaceful
    case neutral
}

enum DailyEveningCheckInPhase: String, Codable, Equatable {
    case pending
    case askedDayReflection
    case askedRestReadiness
    case completed
}

struct DailyEveningCheckInState: Codable, Equatable {
    var dateKey: String
    var phase: DailyEveningCheckInPhase
}

enum DailyEveningCheckInEngine {
    static let checkInHour = 21

    static let dayReflectionQuickReplies = [
        "Foi um ótimo dia!",
        "Dia cansativo",
        "Treinei muito bem",
        "Não treinei hoje",
        "Dia difícil"
    ]

    static let restReadinessQuickReplies = [
        "Pronto pra dormir",
        "Ainda agitado",
        "Dor muscular",
        "Ansioso",
        "Tranquilo e em paz"
    ]

    static func todayKey(for date: Date = .now) -> String {
        DailyWellnessEntry.dayKey(for: date)
    }

    /// Janela do check-in noturno em **hora local do dispositivo** (≥ 21:00 local).
    static func isCheckInWindowOpen(now: Date = .now, calendar: Calendar = MotivationMessages.localCalendar) -> Bool {
        calendar.component(.hour, from: now) >= checkInHour
    }

    /// Horário atual do dispositivo, ex.: "21h", "21h45" (local 24h wall clock).
    static func formattedClockTime(now: Date = .now, calendar: Calendar = MotivationMessages.localCalendar) -> String {
        DailyMorningCheckInEngine.formattedClockTime(now: now, calendar: calendar)
    }

    static func completedSessionsToday(from sessions: [WorkoutSession], on date: Date = .now) -> [WorkoutSession] {
        let key = todayKey(for: date)
        return sessions.filter { session in
            guard let endedAt = session.endedAt else { return false }
            return todayKey(for: endedAt) == key
        }
    }

    static func openingMessage(athleteName: String, context: HealthAssistantContext, now: Date = .now) -> String {
        let name = athleteName.isEmpty ? "Atleta" : athleteName
        let todaySessions = context.todayWorkoutSessions
        let greeting = dayPartGreeting(for: now)
        let clock = formattedClockTime(now: now)

        let energyHydration = energyAndHydrationComparison(context: context)

        if todaySessions.isEmpty {
            return """
            \(greeting), \(name)! 🌙

            Agora são \(clock) — hora de fechar o dia com calma e honestidade.

            Não vi treinos registrados hoje, e tudo bem: nem todo dia precisa ser de academia. O descanso também faz parte do progresso.

            \(energyHydration)

            Como foi seu dia de uma forma geral? Energia, humor, conquistas e desafios — quero ouvir você.
            """
        }

        let summary = workoutSummaryBlock(for: todaySessions)
        return """
        \(greeting), \(name)! 🌙

        Agora são \(clock) — hora de olhar pra trás e celebrar o que você construiu hoje.

        \(summary)

        \(energyHydration)

        Como foi seu dia além dos treinos? Humor, energia e sensações — me conta com sinceridade.
        """
    }

    /// Comparação fim de dia: calorias gastas × ingeridas + hidratação.
    static func energyAndHydrationComparison(context: HealthAssistantContext) -> String {
        let burnedWorkouts = Int(
            context.todayWorkoutSessions.reduce(0) { $0 + $1.caloriesBurned }.rounded()
        )
        let burnedHealth = max(context.todayHealthKitActiveCalories, 0)
        let burned = max(burnedWorkouts, burnedHealth)
        let consumed = max(context.todayCaloriesConsumed, 0)
        let mealsDone = context.todayMealsCompleted
        let mealsTotal = context.todayMealsTotal
        let target = max(context.dailyCalorieTarget, 0)
        let hasMealData = context.hasMealPlan && mealsDone > 0 && consumed > 0

        var lines: [String] = ["📊 **Balanço do dia (calorias e hidratação)**"]

        if burned > 0 {
            if burnedHealth > burnedWorkouts, burnedWorkouts > 0 {
                let active = burnedHealth
                lines.append("• Gasto ativo (Health/treinos): ~\(active) kcal (treinos no app: ~\(burnedWorkouts) kcal)")
            } else if burnedHealth > 0, burnedWorkouts == 0 {
                lines.append("• Gasto ativo registrado: ~\(burnedHealth) kcal")
            } else {
                lines.append("• Calorias queimadas nos treinos: ~\(burnedWorkouts) kcal")
            }
        } else {
            lines.append("• Calorias queimadas: ainda sem registro claro de gasto ativo hoje.")
        }

        if hasMealData {
            lines.append("• Calorias ingeridas (refeições marcadas): ~\(consumed) kcal (\(mealsDone)/\(max(mealsTotal, mealsDone)) refeições)")
            if target > 0 {
                let vsTarget = consumed - target
                if abs(vsTarget) <= 100 {
                    lines.append("• Em relação à meta de \(target) kcal: bem perto do alvo. 🎯")
                } else if vsTarget > 0 {
                    lines.append("• Em relação à meta de \(target) kcal: cerca de \(vsTarget) kcal acima.")
                } else {
                    lines.append("• Em relação à meta de \(target) kcal: cerca de \(-vsTarget) kcal abaixo.")
                }
            }
            if burned > 0 {
                let balance = consumed - burned
                if balance > 150 {
                    lines.append("• Comparando gasto × ingestão: você ingeriu cerca de \(balance) kcal a mais do que o gasto ativo registrado.")
                } else if balance < -150 {
                    lines.append("• Comparando gasto × ingestão: o gasto ativo ficou cerca de \(-balance) kcal acima do que você marcou como ingerido.")
                } else {
                    lines.append("• Comparando gasto × ingestão: valores bem próximos hoje — bom equilíbrio aparente.")
                }
            }
        } else if !context.hasMealPlan {
            lines.append(
                "• Refeições: ainda sem cardápio ativo. Para o IAssistente comparar ingestão e gasto, monte o cardápio em Nutrição e marque o que comeu."
            )
        } else if mealsTotal > 0, mealsDone == 0 {
            lines.append(
                "• Refeições: você tem cardápio hoje, mas nenhuma refeição foi marcada como feita. Para eu te ajudar de verdade na comparação calórica, registre em Nutrição o que ingeriu ao longo do dia."
            )
        } else {
            lines.append(
                "• Refeições: ainda sem calorias ingeridas registradas. Marque as refeições feitas no cardápio para eu comparar com o que você gastou."
            )
        }

        lines.append(hydrationComparisonLine(context: context))
        return lines.joined(separator: "\n")
    }

    private static func hydrationComparisonLine(context: HealthAssistantContext) -> String {
        let intake = max(context.waterIntakeMl, 0)
        let goal = max(context.user?.recommendedDailyWaterML ?? 0, 0)

        if intake <= 0 {
            return "• Hidratação: sem registro de água hoje. Atualize no Perfil — isso ajuda o IAssistente a orientar sua recuperação e o balanço do dia. 💧"
        }
        if goal <= 0 {
            return "• Hidratação: \(intake) ml registrados hoje. 💧"
        }

        let percent = min(Int((Double(intake) / Double(goal) * 100).rounded()), 999)
        if intake >= goal {
            return "• Hidratação: \(intake) ml de \(goal) ml (\(percent)%) — meta batida. 💧✅"
        }
        if intake >= goal / 2 {
            let missing = goal - intake
            return "• Hidratação: \(intake) ml de \(goal) ml (\(percent)%). Faltam ~\(missing) ml para a meta — um pouco de água ainda ajuda, sem exagerar perto do sono. 💧"
        }
        return "• Hidratação: \(intake) ml de \(goal) ml (\(percent)%) — abaixo da metade da meta. Vale registrar e completar o que puder com calma. 💧"
    }

    static func classifyDayFeeling(_ text: String) -> DailyEveningDayFeeling {
        let normalized = text
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))

        if matches(normalized, any: ["nao treinei", "não treinei", "sem treino", "faltei", "nao fui", "não fui", "pulei"]) {
            return .skippedWorkout
        }
        if matches(normalized, any: ["otimo", "ótimo", "incrivel", "excelente", "top", "treinei muito", "arras", "conquist"]) {
            return .great
        }
        if matches(normalized, any: ["bem", "boa", "tranquilo", "produtivo", "satisfeito"]) {
            return .good
        }
        if matches(normalized, any: ["dificil", "difícil", "pesado", "complicado", "pessimo", "péssimo", "ruim"]) {
            return .difficult
        }
        if matches(normalized, any: ["desanim", "motivacao", "motivação", "preguica", "preguiça", "sem vontade"]) {
            return .unmotivated
        }
        if matches(normalized, any: ["cansativo", "cansado", "exausto", "esgotado", "fadiga", "pesado"]) {
            return .tiring
        }
        return .neutral
    }

    static func isDayFeelingReply(_ text: String) -> Bool {
        if AssistantGratitudeEngine.matches(text) { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let normalized = trimmed
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))

        for reply in dayReflectionQuickReplies {
            let replyNormalized = reply
                .lowercased()
                .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
            if normalized == replyNormalized || normalized.contains(replyNormalized) {
                return true
            }
        }

        let signals = [
            "otimo", "bem", "dificil", "cansativ", "desanim", "treinei", "nao treinei",
            "faltei", "produtivo", "ruim", "pesado", "me sinto", "estou", "foi "
        ]
        let hasFeelingSignal = signals.contains(where: { normalized.contains($0) })

        if PostWorkoutCheckInEngine.looksLikeOffTopicQuestion(trimmed) {
            let shortFeelingWithQuestionMark = hasFeelingSignal
                && trimmed.count <= 40
                && !PostWorkoutCheckInEngine.hasStandaloneQuestionContent(normalized)
            if !shortFeelingWithQuestionMark, trimmed.contains("?") || !hasFeelingSignal {
                return false
            }
        }

        if hasFeelingSignal { return true }
        return trimmed.count <= 48
    }

    static func isRestReadinessReply(_ text: String) -> Bool {
        if AssistantGratitudeEngine.matches(text) { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let normalized = trimmed
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))

        for reply in restReadinessQuickReplies {
            let replyNormalized = reply
                .lowercased()
                .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
            if normalized == replyNormalized || normalized.contains(replyNormalized) {
                return true
            }
        }

        let signals = [
            "pronto", "sono", "dormir", "agitado", "dor", "ansios", "cansado",
            "descans", "inquiet", "me sinto", "estou"
        ]
        let hasFeelingSignal = signals.contains(where: { normalized.contains($0) })

        if PostWorkoutCheckInEngine.looksLikeOffTopicQuestion(trimmed) {
            let shortFeelingWithQuestionMark = hasFeelingSignal
                && trimmed.count <= 40
                && !PostWorkoutCheckInEngine.hasStandaloneQuestionContent(normalized)
            if !shortFeelingWithQuestionMark, trimmed.contains("?") || !hasFeelingSignal {
                return false
            }
        }

        if hasFeelingSignal { return true }
        return trimmed.count <= 48
    }

    static func reminderToAnswerDayFeeling() -> String {
        PostWorkoutCheckInEngine.pendingQuestionReminder(
            "como foi seu dia além dos treinos — humor, energia e sensações?"
        )
    }

    static func reminderToAnswerRestReadiness() -> String {
        PostWorkoutCheckInEngine.pendingQuestionReminder(
            "como está seu corpo e mente agora para descansar?"
        )
    }

    static func classifyRestReadiness(_ text: String) -> DailyEveningRestReadiness {
        let normalized = text
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))

        if matches(normalized, any: ["pronto", "sono", "dormir", "cama", "descansar"]) {
            return .readyToSleep
        }
        if matches(normalized, any: ["agitado", "acelerado", "inquieto", "nao consigo", "não consigo", "insone"]) {
            return .restless
        }
        if matches(normalized, any: ["dor", "dolorido", "doendo", "muscul", "rigidez", "travado"]) {
            return .sore
        }
        if matches(normalized, any: ["ansios", "preocup", "nervoso", "estress", "cabeça cheia"]) {
            return .anxious
        }
        if matches(normalized, any: ["tranquilo", "paz", "calmo", "sereno", "relaxado"]) {
            return .peaceful
        }
        return .neutral
    }

    static func dayReflectionFollowUp(
        feeling: DailyEveningDayFeeling,
        context: HealthAssistantContext
    ) -> String {
        let name = context.user?.greetingName ?? "Atleta"
        let hadWorkout = !context.todayWorkoutSessions.isEmpty
        let acknowledgment = dayAcknowledgment(for: feeling, hadWorkout: hadWorkout, name: name, sessions: context.todayWorkoutSessions)

        return """
        \(acknowledgment)

        Agora, na hora de ir pra cama: como está seu corpo e sua mente? Pronto pra desligar, ainda agitado, com dores... me conta.
        """
    }

    static func closingSequence(
        readiness: DailyEveningRestReadiness,
        dayFeeling: DailyEveningDayFeeling,
        context: HealthAssistantContext
    ) -> [String] {
        let name = context.user?.greetingName ?? "Atleta"
        let hadWorkout = !context.todayWorkoutSessions.isEmpty

        return [
            restAcknowledgment(for: readiness, name: name),
            sleepGuidance(for: readiness, dayFeeling: dayFeeling, hadWorkout: hadWorkout, context: context, name: name),
            goodNightFarewell(for: readiness, hadWorkout: hadWorkout, name: name)
        ]
    }

    private static func workoutSummaryBlock(for sessions: [WorkoutSession]) -> String {
        let lines = sessions.map(workoutLine(for:))
        let totalCalories = Int(sessions.reduce(0) { $0 + $1.caloriesBurned }.rounded())
        var block = "Hoje você registrou \(sessions.count) treino(s):\n\(lines.joined(separator: "\n"))"
        if totalCalories > 0 {
            block += "\n\nTotal aproximado: \(totalCalories) kcal queimadas. 💪"
        }
        return block
    }

    private static func workoutLine(for session: WorkoutSession) -> String {
        let calories = Int(session.caloriesBurned.rounded())
        let calorieSuffix = calories > 0 ? ", ~\(calories) kcal" : ""

        if let km = session.completedDistanceKm, km > 0 {
            return "• \(session.workoutTitle) — \(String(format: "%.1f", km)) km\(calorieSuffix)"
        }
        if session.completedExercises > 0 {
            return "• \(session.workoutTitle) — \(session.completedExercises) exercício(s)\(calorieSuffix)"
        }
        return "• \(session.workoutTitle)\(calorieSuffix)"
    }

    private static func dayAcknowledgment(
        for feeling: DailyEveningDayFeeling,
        hadWorkout: Bool,
        name: String,
        sessions: [WorkoutSession]
    ) -> String {
        switch feeling {
        case .great:
            if hadWorkout {
                let highlight = sessions.first?.workoutTitle ?? "treino"
                return "Que combinação poderosa, \(name)! 🙌 Dia excelente e ainda com \"\(highlight)\" no currículo — consistência assim muda o jogo."
            }
            return "Que ótimo fechar o dia assim, \(name)! 🌟 Energia positiva à noite ajuda até no sono."
        case .good:
            if hadWorkout {
                return "Dia sólido, \(name)! Você treinou e ainda manteve o humor em dia — equilíbrio que sustenta resultados."
            }
            return "Um dia tranquilo também conta, \(name). O importante é como você se sente agora, sem culpa."
        case .tiring:
            if hadWorkout {
                return "Dia puxado com treino no meio, \(name). Exige bastante do corpo — agora o foco é recuperar com inteligência."
            }
            return "Dias cansativos acontecem, \(name). Seu corpo pede descanso de qualidade — vamos preparar isso juntos."
        case .difficult:
            return "Obrigado por compartilhar, \(name). Dias difíceis não apagam seu progresso — amanhã é uma página nova. 🌿"
        case .unmotivated:
            if hadWorkout {
                return "Mesmo sem muita motivação, você treinou hoje, \(name). Isso é disciplina de verdade — respeito! 💪"
            }
            return "Sem motivação e sem treino hoje, \(name) — e está tudo bem. Um bom sono pode recarregar a mente para amanhã."
        case .skippedWorkout:
            return """
            Sem treino hoje, \(name) — e eu não vou te cobrar. 🌙

            Descanso estratégico faz parte. Amanhã você pode retomar na aba Treinos, no seu ritmo.
            """
        case .neutral:
            if hadWorkout {
                return "Você treinou hoje e fechou o dia no seu ritmo, \(name). Cada sessão registrada é um tijolo a mais."
            }
            return "Obrigado por dividir como foi o dia, \(name). Nem todo dia precisa ser espetacular."
        }
    }

    private static func restAcknowledgment(for readiness: DailyEveningRestReadiness, name: String) -> String {
        switch readiness {
        case .readyToSleep:
            return "Perfeito, \(name)! Corpo e mente pedindo descanso — sinal de que você viveu o dia de verdade. 😴"
        case .peaceful:
            return "Que bom chegar à noite em paz, \(name). Esse estado é ouro para recuperação muscular e mental. 🌿"
        case .restless:
            return "Entendo, \(name). Cabeça acelerada à noite é comum — vamos suavizar a transição pro sono."
        case .sore:
            return "Dor muscular após o dia é esperada, \(name). Vamos cuidar disso antes de você deitar."
        case .anxious:
            return "Ansiedade à noite merece carinho, \(name). Respiração lenta pode ser seu melhor aliado agora."
        case .neutral:
            return "Obrigado por responder, \(name). Vamos preparar uma boa noite de descanso."
        }
    }

    private static func sleepGuidance(
        for readiness: DailyEveningRestReadiness,
        dayFeeling: DailyEveningDayFeeling,
        hadWorkout: Bool,
        context: HealthAssistantContext,
        name: String
    ) -> String {
        var tips: [String] = []

        switch readiness {
        case .readyToSleep, .peaceful, .neutral:
            tips.append("🛏️ **Rotina de sono:** quarto escuro, fresco e sem telas nos próximos 30 min.")
        case .restless, .anxious:
            tips.append("🧘 **Respiração 4-7-8:** inspire 4s, segure 7s, solte 8s — repita 5 vezes para acalmar o sistema nervoso.")
            tips.append("📵 **Desconecte:** evite redes e notícias agora — sua mente precisa desacelerar.")
        case .sore:
            tips.append("🧊 **Recuperação:** alongamento leve de 5 min e água morna podem aliviar tensão muscular.")
            if hadWorkout {
                tips.append("💪 **Lembrete:** dor leve pós-treino é normal — seus músculos se reconstruem no sono.")
            }
        }

        if hadWorkout {
            tips.append("😴 **Sono e ganhos:** a maior parte da recuperação muscular acontece dormindo 7–9 h.")
        } else if dayFeeling == .skippedWorkout || dayFeeling == .unmotivated {
            tips.append("🌅 **Amanhã:** quando voltar ao IAssistente, conversamos de novo — um passo de cada vez reconstrói o ritmo.")
        }

        if let hours = context.sleepHours, hours < 6 {
            tips.append("⚠️ Você registrou pouco sono recentemente — priorize descanso hoje, \(name).")
        }

        if context.waterIntakeMl <= 0 {
            tips.append("💧 Sem água registrada hoje — anote no Perfil amanhã; hidratação completa o balanço do dia.")
        } else if let user = context.user {
            let goal = user.recommendedDailyWaterML
            if goal > 0, context.waterIntakeMl < goal / 2 {
                tips.append("💧 Hidratação baixa hoje — um gole de água agora, sem exagero antes de dormir.")
            }
        }

        if context.hasMealPlan, context.todayMealsCompleted == 0, context.todayMealsTotal > 0 {
            tips.append(
                "🍽️ Lembrete: marque as refeições feitas em Nutrição. Assim, no próximo check-in eu comparo melhor calorias ingeridas × gastas."
            )
        }

        return tips.joined(separator: "\n\n")
    }

    private static func goodNightFarewell(
        for readiness: DailyEveningRestReadiness,
        hadWorkout: Bool,
        name: String,
        now: Date = .now
    ) -> String {
        // Check-in noturno é ≥ 21h — saudação de descanso; se rodado mais cedo, mantém o corte de 20h.
        let restSalute = MotivationMessages.isRestWindow(for: now)
            ? MotivationMessages.restGreeting(for: now)
            : MotivationMessages.dayPartGreeting(for: now)

        switch readiness {
        case .readyToSleep, .peaceful:
            if hadWorkout {
                return "\(restSalute), \(name)! Você merece esse descanso depois do que fez hoje. Durma bem — hidrate levemente e desacelere. Estou no IAssistente se precisar. 🌙💤"
            }
            return "\(restSalute), \(name)! Descanse profundamente e recarregue. Te vejo no próximo check-in! 🌙"
        case .restless, .anxious:
            return "Vai com calma, \(name). Feche os olhos quando puder — cada respiração te aproxima do sono. Descanse bem! 🌙"
        case .sore:
            return "Recupere bem, \(name). Seu corpo trabalhou — agora deixe o sono fazer o resto. Bom descanso! 💤"
        case .neutral:
            return "\(restSalute), \(name)! Que seu descanso seja reparador. Estou na aba IAssistente quando quiser conversar. 🌙"
        }
    }

    private static func dayPartGreeting(for date: Date) -> String {
        MotivationMessages.dayPartGreeting(for: date)
    }

    private static func matches(_ text: String, any keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }
}
