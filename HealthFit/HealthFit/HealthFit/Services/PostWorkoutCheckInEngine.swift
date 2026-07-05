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
        self.phase = phase
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
        return now.timeIntervalSince(checkIn.endedAt) >= delaySeconds
    }

    static func openingMessage(checkIn: PendingPostWorkoutCheckIn, athleteName: String) -> String {
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

    static func responseSequence(
        feeling: PostWorkoutFeeling,
        checkIn: PendingPostWorkoutCheckIn,
        athleteName: String
    ) -> [String] {
        let name = athleteName.isEmpty ? "Atleta" : athleteName
        return [
            acknowledgment(for: feeling, checkIn: checkIn, name: name),
            motivation(for: feeling, checkIn: checkIn, name: name),
            farewell(for: feeling, checkIn: checkIn, name: name)
        ]
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
