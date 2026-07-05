import Foundation

enum DailyMorningFeeling: Equatable {
    case great
    case good
    case tired
    case stressed
    case unmotivated
    case neutral
}

enum DailyMorningCheckInPhase: String, Codable, Equatable {
    case pending
    case askedFeeling
    case completed
}

struct DailyMorningCheckInState: Codable, Equatable {
    var dateKey: String
    var phase: DailyMorningCheckInPhase
}

enum DailyMorningCheckInEngine {
    static let checkInHour = 9

    static let feelingQuickReplies = [
        "Estou ótimo!",
        "Me sinto bem",
        "Um pouco cansado",
        "Estou estressado",
        "Preciso de motivação"
    ]

    static func todayKey(for date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func isCheckInWindowOpen(now: Date = .now) -> Bool {
        Calendar.current.component(.hour, from: now) >= checkInHour
    }

    static func openingMessage(athleteName: String, context: HealthAssistantContext) -> String {
        let name = athleteName.isEmpty ? "Atleta" : athleteName
        let dayGreeting = dayPartGreeting(for: .now)

        return """
        \(dayGreeting), \(name)! ☀️

        São 9h — momento ideal para alinhar corpo e mente antes do dia.

        Como você está se sentindo agora? Energia, humor e disposição — me conte com sinceridade.

        Depois te ajudo com meditação, treino ou um lembrete de cardio, conforme o seu dia.
        """
    }

    static func classifyFeeling(_ text: String) -> DailyMorningFeeling {
        let normalized = text
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))

        if matches(normalized, any: ["otimo", "ótimo", "incrivel", "excelente", "top", "100%", "energia"]) {
            return .great
        }
        if matches(normalized, any: ["bem", "boa", "tranquilo", "me sinto bem"]) {
            return .good
        }
        if matches(normalized, any: ["estress", "ansied", "agitado", "nervoso", "pressao", "pressão"]) {
            return .stressed
        }
        if matches(normalized, any: ["motivacao", "motivação", "desanim", "preguica", "preguiça", "sem vontade"]) {
            return .unmotivated
        }
        if matches(normalized, any: ["cansado", "exausto", "sono", "sem energia", "pesado", "fadiga"]) {
            return .tired
        }
        return .neutral
    }

    static func responseSequence(
        feeling: DailyMorningFeeling,
        context: HealthAssistantContext
    ) -> [String] {
        let name = context.user?.greetingName ?? "Atleta"
        return [
            acknowledgment(for: feeling, name: name),
            wellnessFocus(for: feeling, context: context, name: name),
            farewell(for: feeling, name: name)
        ]
    }

    private static func dayPartGreeting(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return "Bom dia"
        case 12..<18: return "Boa tarde"
        default: return "Boa noite"
        }
    }

    private static func acknowledgment(for feeling: DailyMorningFeeling, name: String) -> String {
        switch feeling {
        case .great, .good:
            return "Que ótimo começar o dia assim, \(name)! 🙌 Energia positiva pela manhã costuma refletir no resto do dia."
        case .tired:
            return "Obrigado por ser honesto, \(name). Acordar cansado acontece — vamos ajustar o dia com leveza."
        case .stressed:
            return "Entendo, \(name). Estresse pela manhã merece cuidado antes de exigir mais do corpo."
        case .unmotivated:
            return "Tudo bem sentir falta de motivação, \(name). Um passo pequeno já reacende o ritmo."
        case .neutral:
            return "Obrigado por compartilhar, \(name). Nem todo dia começa intenso — e está tudo bem."
        }
    }

    private static func wellnessFocus(
        for feeling: DailyMorningFeeling,
        context: HealthAssistantContext,
        name: String
    ) -> String {
        let needsCardioReminder = shouldRemindCardio(context: context)
        let needsMeditation = feeling == .stressed || feeling == .tired || feeling == .unmotivated
            || (context.sleepHours.map { $0 < 6 } ?? false)

        if needsMeditation {
            var message = """
            🧘 **Meditação (5–10 min)**
            Abra Treinos → Meditação e faça uma sessão curta. Respiração lenta reduz estresse e melhora foco para o dia.
            """
            if needsCardioReminder {
                message += """


            🏃 **Lembrete de cardio**
            \(cardioReminderLine(context: context))
            """
            } else if feeling == .great || feeling == .good {
                message += """


            💪 **Treino**
            Com essa energia, aproveite para uma ficha de musculação hoje — consistência constrói resultados.
            """
            }
            return message
        }

        if needsCardioReminder {
            return """
            🏃 **Lembrete de cardio**
            \(cardioReminderLine(context: context))

            💪 **Treino**
            Combine com musculação na aba Treinos quando puder — equilíbrio entre força e condicionamento acelera seus resultados.
            """
        }

        switch feeling {
        case .great, .good:
            return """
            💪 **Treino**
            Energia boa é sinal verde para musculação hoje. Escolha uma ficha na aba Treinos e mantenha o ritmo.

            🏃 **Cardio**
            Se tiver 20–30 min, um cardio leve complementa bem — caminhada, bike ou esteira.
            """
        case .tired, .neutral:
            return """
            🧘 **Meditação leve**
            5 minutos de respiração em Treinos → Meditação podem equilibrar sua energia antes de decidir o treino.

            💪 **Treino adaptado**
            Se treinar, prefira volume moderado hoje — o importante é manter a consistência sem exagerar.
            """
        case .stressed, .unmotivated:
            return """
            🧘 **Meditação**
            Comece com uma sessão curta para acalmar a mente — isso facilita retomar treinos e cardio depois.
            """
        }
    }

    private static func farewell(for feeling: DailyMorningFeeling, name: String) -> String {
        switch feeling {
        case .great, .good:
            return "Excelente dia pela frente, \(name)! Estarei aqui na aba IAssistente quando precisar. Vamos com tudo! 💪"
        case .tired, .stressed:
            return "Cuide-se hoje, \(name). Pequenos passos contam. Volto a te ouvir amanhã às 9h. 🌿"
        case .unmotivated, .neutral:
            return "Um dia de cada vez, \(name). Amanhã às 9h conversamos de novo. Você consegue! ☀️"
        }
    }

    private static func shouldRemindCardio(context: HealthAssistantContext) -> Bool {
        if let hours = context.hoursSinceLastWorkout, hours >= 48 {
            return true
        }
        return context.weeklyWorkoutCount < 2
    }

    private static func cardioReminderLine(context: HealthAssistantContext) -> String {
        if let hours = context.hoursSinceLastWorkout, hours >= 48 {
            let days = max(Int(hours / 24), 2)
            return "Faz \(days) dia(s) desde seu último treino. Que tal 20 min de cardio leve hoje? Aba Treinos → Cardio."
        }
        if context.weeklyWorkoutCount == 0 {
            return "Nenhum treino registrado esta semana. Comece com 15–20 min de caminhada ou bike — seu coração agradece."
        }
        return "Apenas \(context.weeklyWorkoutCount) treino(s) esta semana. Cardio 2–3x ajuda na consistência — experimente hoje à tarde."
    }

    private static func matches(_ text: String, any keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }
}
