import Foundation

enum PostWorkoutFeeling: Equatable {
    case great
    case good
    case neutral
    case tired
    case sore
}

enum PostWorkoutKind: String, Codable, Equatable {
    case strength
    case cardio
    case meditation
}

enum PostWorkoutCheckInPhase: String, Codable, Equatable {
    case scheduled
    case askedFeeling
    case completed
}

struct PendingPostWorkoutCheckIn: Codable, Equatable, Identifiable {
    let sessionId: UUID
    let workoutTitle: String
    let endedAt: Date
    let completedExercises: Int
    let totalExercises: Int
    let caloriesBurned: Double
    let workoutKind: PostWorkoutKind
    let cardioIntensityLabel: String?
    let autoEndedByInactivity: Bool
    var phase: PostWorkoutCheckInPhase

    var id: UUID { sessionId }

    init(session: WorkoutSession, phase: PostWorkoutCheckInPhase = .scheduled) {
        sessionId = session.id
        workoutTitle = session.workoutTitle
        endedAt = session.endedAt ?? .now
        completedExercises = session.completedExercises
        totalExercises = session.totalExercises
        caloriesBurned = session.caloriesBurned
        workoutKind = Self.kind(for: session)
        cardioIntensityLabel = session.cardioIntensityLabel
        autoEndedByInactivity = session.autoEndedByInactivity
        self.phase = phase
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decode(UUID.self, forKey: .sessionId)
        workoutTitle = try container.decode(String.self, forKey: .workoutTitle)
        endedAt = try container.decode(Date.self, forKey: .endedAt)
        completedExercises = try container.decode(Int.self, forKey: .completedExercises)
        totalExercises = try container.decode(Int.self, forKey: .totalExercises)
        caloriesBurned = try container.decode(Double.self, forKey: .caloriesBurned)
        workoutKind = try container.decode(PostWorkoutKind.self, forKey: .workoutKind)
        cardioIntensityLabel = try container.decodeIfPresent(String.self, forKey: .cardioIntensityLabel)
        autoEndedByInactivity = try container.decodeIfPresent(Bool.self, forKey: .autoEndedByInactivity) ?? false
        phase = try container.decode(PostWorkoutCheckInPhase.self, forKey: .phase)
    }

    private enum CodingKeys: String, CodingKey {
        case sessionId, workoutTitle, endedAt, completedExercises, totalExercises
        case caloriesBurned, workoutKind, cardioIntensityLabel, autoEndedByInactivity, phase
    }

    private static func kind(for session: WorkoutSession) -> PostWorkoutKind {
        if session.targetDistanceKm != nil || session.cardioIntensityLabel != nil {
            return .cardio
        }
        let title = session.workoutTitle.lowercased()
        if title.contains("medita") || title.contains("mindful") || title.contains("respira") {
            return .meditation
        }
        return .strength
    }
}

enum PostWorkoutCheckInEngine {
    static let delaySeconds: TimeInterval = 90 * 60

    static let feelingQuickReplies = [
        "Estou ótimo!",
        "Me sinto bem",
        "Mais ou menos",
        "Estou cansado",
        "Estou com dores"
    ]

    static func isDue(_ checkIn: PendingPostWorkoutCheckIn, now: Date = .now) -> Bool {
        guard checkIn.phase != .completed else { return false }
        // Esqueceu de encerrar: fala com o usuário assim que abrir o IAssistente.
        if checkIn.autoEndedByInactivity { return true }
        return now.timeIntervalSince(checkIn.endedAt) >= delaySeconds
    }

    static func openingMessage(checkIn: PendingPostWorkoutCheckIn, athleteName: String) -> String {
        if checkIn.autoEndedByInactivity {
            return MotivationMessages.forgottenWorkoutAssistantOpening(
                workoutTitle: checkIn.workoutTitle,
                athleteName: athleteName
            )
        }

        let name = athleteName.isEmpty ? "Atleta" : athleteName
        let workoutFocus = workoutFocusLine(for: checkIn)

        return """
        Olá, \(name)! ⏱️

        Já se passaram 90 minutos desde o seu treino "\(checkIn.workoutTitle)".
        \(workoutFocus)

        Como você está se sentindo agora — corpo, energia e disposição?
        Me conte com sinceridade. Estou aqui para te ouvir.
        """
    }

    static func classifyFeeling(_ text: String) -> PostWorkoutFeeling {
        let normalized = text
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))

        if matches(normalized, any: ["otimo", "ótimo", "incrivel", "incrível", "excelente", "top", "100%", "forte", "energia"]) {
            return .great
        }
        if matches(normalized, any: ["bem", "boa", "good", "tranquilo", "ok demais", "me sinto bem"]) {
            return .good
        }
        if matches(normalized, any: ["dor", "dolorido", "doendo", "lesao", "lesão", "machuc", "rigidez", "travado"]) {
            return .sore
        }
        if matches(normalized, any: ["cansado", "exausto", "esgotado", "sem energia", "fadiga", "morto", "acabado", "pesado"]) {
            return .tired
        }
        return .neutral
    }

    /// Indica se o texto responde ao check-in de como o usuário está se sentindo.
    static func isFeelingReply(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let normalized = trimmed
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))

        for reply in feelingQuickReplies {
            let replyNormalized = reply
                .lowercased()
                .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
            if normalized == replyNormalized || normalized.contains(replyNormalized) {
                return true
            }
        }

        let feelingSignals = [
            "otimo", "bem", "boa", "cansado", "dor", "mais ou menos", "exausto", "dolorido",
            "tranquilo", "legal", "mal", "ruim", "normal", "regular", "dispos", "energia",
            "forte", "top", "incrivel", "ok", "neutro", "pesado", "rigidez", "machuc",
            "fadiga", "acabado", "morto", "me sinto", "estou", "to ", "tô "
        ]
        let hasFeelingSignal = feelingSignals.contains(where: { normalized.contains($0) })

        // Nova pergunta tem prioridade — exceto resposta curta de sentimento com "?" no final.
        if looksLikeOffTopicQuestion(trimmed) {
            let shortFeelingWithQuestionMark = hasFeelingSignal
                && trimmed.count <= 40
                && !hasStandaloneQuestionContent(normalized)
            if !shortFeelingWithQuestionMark, trimmed.contains("?") || !hasFeelingSignal {
                return false
            }
        }

        if hasFeelingSignal {
            return true
        }

        // Resposta curta e livre, sem cara de pergunta.
        return trimmed.count <= 48
    }

    /// Conteúdo interrogativo além de um "?" solto (ex.: "Estou bem, qual meu IMC?").
    static func hasStandaloneQuestionContent(_ normalized: String) -> Bool {
        let markers = [
            "como ", "qual ", "quais ", "quanto", "quanta", "quando ", "onde ",
            "por que", "porque", "o que ", "posso ", "devo ", "sera que",
            "me explica", "me diga", "me fala", "quero saber",
            "meu imc", "proteina", "creatina", "suplemento", "cardapio", "biotipo",
            "alcool", "cerveja", "calorias", "montar treino"
        ]
        return markers.contains(where: { normalized.contains($0) })
    }

    /// Detecta pergunta nova / fora do tema esperado (em vez de responder o check-in).
    static func looksLikeOffTopicQuestion(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let normalized = trimmed
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))

        if trimmed.contains("?") {
            return true
        }

        let questionPrefixes = [
            "como ", "qual ", "quais ", "quanto ", "quanta ", "quando ", "onde ",
            "por que ", "porque ", "o que ", "posso ", "devo ", "sera que "
        ]
        if questionPrefixes.contains(where: { normalized.hasPrefix($0) }) {
            let nonQuestionPrefixes = [
                "como sempre", "como de costume", "como eu", "como vc", "como voce"
            ]
            if !nonQuestionPrefixes.contains(where: { normalized.hasPrefix($0) }) {
                return true
            }
        }

        let questionSignals = [
            "o que e", "o que sao", "qual e", "quais ", "quanto", "quando ", "onde ",
            "por que", "porque",
            "como faco", "como treinar", "como montar", "como dormir", "como melhorar",
            "como fazer", "como ganhar", "como perder", "como beber", "como tomar",
            "como fica", "como funciona", "como usar", "como calcular",
            "posso ", "devo ", "me explica", "me diga", "me fala", "quero saber",
            "montar treino", "criar ficha", "gerar treino",
            "meu imc", " imc", "proteina", "creatina", "whey", "suplemento",
            "cardapio", "biotipo", "ectomorfo", "mesomorfo", "endomorfo",
            "alcool", "cerveja", "deficit", "calorias", "series", "repeticoes"
        ]
        return questionSignals.contains(where: { normalized.contains($0) })
    }

    /// Lembrete educado de pergunta pendente (uma vez por turno desviado).
    static func pendingQuestionReminder(_ pendingQuestion: String) -> String {
        "Quando puder, me responde também: \(pendingQuestion)"
    }

    static func reminderToAnswerFeeling(checkIn: PendingPostWorkoutCheckIn) -> String {
        pendingQuestionReminder(
            "como você está se sentindo agora depois de \"\(checkIn.workoutTitle)\" — corpo, energia e disposição?"
        )
    }

    static func responseSequence(
        feeling: PostWorkoutFeeling,
        checkIn: PendingPostWorkoutCheckIn,
        athleteName: String
    ) -> [String] {
        let name = athleteName.isEmpty ? "Atleta" : athleteName
        var messages = [
            acknowledgment(for: feeling, checkIn: checkIn, name: name),
            motivation(for: feeling, checkIn: checkIn, name: name)
        ]
        if checkIn.autoEndedByInactivity {
            let tip = MotivationMessages.forgottenWorkoutMotivation.randomElement()
                ?? MotivationMessages.forgottenWorkoutMotivation[0]
            messages.append(
                "Sobre esquecer de finalizar: acontece com muita gente. Da próxima vez, encerre na tela do treino — e se precisar, eu te lembro. \(tip)"
            )
        }
        messages.append(farewell(for: feeling, checkIn: checkIn, name: name))
        return messages
    }

    private static func workoutFocusLine(for checkIn: PendingPostWorkoutCheckIn) -> String {
        switch checkIn.workoutKind {
        case .strength:
            return "Você concluiu \(checkIn.completedExercises) de \(checkIn.totalExercises) exercícios — o corpo já está processando essa carga."
        case .cardio:
            let intensity = checkIn.cardioIntensityLabel.map { " (\($0))" } ?? ""
            let calories = checkIn.caloriesBurned > 0 ? String(format: " · ~%.0f kcal", checkIn.caloriesBurned) : ""
            return "Seu cardio\(intensity) exigiu fôlego e foco\(calories)."
        case .meditation:
            return "Sua sessão de meditação ajudou na recuperação mental e no equilíbrio."
        }
    }

    private static func acknowledgment(
        for feeling: PostWorkoutFeeling,
        checkIn: PendingPostWorkoutCheckIn,
        name: String
    ) -> String {
        switch feeling {
        case .great, .good:
            return "Que bom ouvir isso, \(name)! 🙌 Recuperação assim depois de \"\(checkIn.workoutTitle)\" mostra que você respeitou o ritmo do treino."
        case .neutral:
            return "Entendo, \(name). Nem todo dia o corpo responde igual — e tudo bem reconhecer isso."
        case .tired:
            return "Obrigado por ser honesto, \(name). Fadiga após \"\(checkIn.workoutTitle)\" pode ser normal, principalmente em fases de maior volume."
        case .sore:
            return "Obrigado por compartilhar, \(name). Sensação de dor ou rigidez merece atenção — recuperação faz parte do progresso."
        }
    }

    private static func motivation(
        for feeling: PostWorkoutFeeling,
        checkIn: PendingPostWorkoutCheckIn,
        name: String
    ) -> String {
        switch (feeling, checkIn.workoutKind) {
        case (.great, .strength), (.good, .strength):
            return "Musculação bem executada constrói músculo, postura e confiança. Hoje: hidrate-se, priorize proteína e durma bem — amanhã você volta ainda mais preparado."
        case (.great, .cardio), (.good, .cardio):
            return "Cardio consistente fortalece coração e resistência. Mantenha a hidratação e celebre esse passo — consistência vence intensidade isolada."
        case (.great, .meditation), (.good, .meditation):
            return "Mente recuperada potencializa todos os outros treinos. Guarde essa sensação de calma para os próximos desafios."
        case (.neutral, .strength):
            return "Se o corpo pediu pausa hoje, ajuste sono e alimentação. Um treino 'regular' ainda conta — o importante é não desistir do processo."
        case (.neutral, .cardio):
            return "Cardio nem sempre parece leve depois — hidrate e alongue. Na próxima sessão, ajuste a intensidade se precisar."
        case (.neutral, .meditation):
            return "Às vezes a mente demora a acalmar — continue praticando. Pequenas sessões também somam."
        case (.tired, _):
            return "Descanse de verdade hoje: água, refeição equilibrada e sono de qualidade. Seu corpo reconstrói força no repouso, não só no treino."
        case (.sore, .strength):
            return "Evite repetir o mesmo grupo muscular amanhã. Alongue com cuidado, use gelo se necessário e não ignore dor aguda persistente."
        case (.sore, .cardio):
            return "Impacto e volume podem gerar desconforto — caminhada leve e mobilidade ajudam. Se a dor for intensa, reduza a carga nos próximos dias."
        case (.sore, .meditation):
            return "Combine descanso físico com respiração lenta hoje. Corpo e mente recuperam juntos."
        }
    }

    private static func farewell(
        for feeling: PostWorkoutFeeling,
        checkIn: PendingPostWorkoutCheckIn,
        name: String
    ) -> String {
        switch feeling {
        case .great, .good:
            return "Você está evoluindo, \(name). 🏆 Orgulho do seu comprometimento com \"\(checkIn.workoutTitle)\". Descanse bem — você merece. Até o próximo treino!"
        case .neutral:
            return "Siga firme, \(name). Um dia regular ainda é um dia vencido. Ajuste o que precisar e volte com foco. Estarei aqui na aba IAssistente. 💪"
        case .tired:
            return "Escute seu corpo, \(name), mas não abandone a rotina. Descanse hoje e planeje um treino mais leve em seguida. Consistência inteligente é o segredo."
        case .sore:
            return "Cuide-se nos próximos dias, \(name). Recuperação não é fraqueza — é estratégia. Se a dor persistir, procure um profissional. Volte quando estiver pronto; estarei aqui."
        }
    }

    private static func matches(_ text: String, any keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }
}
