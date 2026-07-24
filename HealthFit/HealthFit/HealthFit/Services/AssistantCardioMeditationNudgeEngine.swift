import Foundation

enum AssistantCardioMeditationNudgeKind: Equatable {
    case cardio
    case meditation
    case both
}

enum AssistantCardioMeditationNudgeEngine {
    static let inactivityThreshold: TimeInterval = 48 * 60 * 60

    static func lastCardioDate(from sessions: [WorkoutSession]) -> Date? {
        sessions
            .filter(WeeklyProgressAnalyzer.isCardioSession)
            .compactMap { $0.endedAt ?? $0.startedAt }
            .max()
    }

    static func lastMeditationDate(from sessions: [WorkoutSession]) -> Date? {
        sessions
            .filter(WeeklyProgressAnalyzer.isMeditationSession)
            .compactMap { $0.endedAt ?? $0.startedAt }
            .max()
    }

    static func evaluate(
        sessions: [WorkoutSession],
        recordedCardioAt: Date? = nil,
        recordedMeditationAt: Date? = nil,
        accountCreatedAt: Date?,
        now: Date = .now,
        threshold: TimeInterval = inactivityThreshold
    ) -> (kind: AssistantCardioMeditationNudgeKind, cardioReference: Date?, meditationReference: Date?)? {
        let lastCardio = lastCardioDate(from: sessions) ?? recordedCardioAt
        let lastMeditation = lastMeditationDate(from: sessions) ?? recordedMeditationAt

        let cardioReference = lastCardio ?? accountCreatedAt
        let meditationReference = lastMeditation ?? accountCreatedAt

        let cardioStale = isStale(reference: cardioReference, now: now, threshold: threshold)
        let meditationStale = isStale(reference: meditationReference, now: now, threshold: threshold)

        switch (cardioStale, meditationStale) {
        case (true, true):
            return (.both, cardioReference, meditationReference)
        case (true, false):
            return (.cardio, cardioReference, meditationReference)
        case (false, true):
            return (.meditation, cardioReference, meditationReference)
        case (false, false):
            return nil
        }
    }

    static func message(
        kind: AssistantCardioMeditationNudgeKind,
        athleteName: String
    ) -> String {
        let name = athleteName.isEmpty ? "Atleta" : athleteName

        switch kind {
        case .cardio:
            return """
            Ei, \(name)! Faz cerca de **48 horas** sem cardio. 🏃💨

            **Por que manter a rotina?**
            • Coração e pulmão mais fortes ❤️🫁
            • Mais energia no dia a dia e nos treinos ⚡
            • Ajuda a queimar gordura e controlar o estresse 🔥
            • Melhora humor e qualidade do sono 😊😴

            **Estímulo:** Comece com 15–20 min leves (caminhada, bike ou corrida). Consistência vence intensidade.

            Abra **Treinos → Cardio** e retome hoje — seu futuro eu agradece! 💪
            """

        case .meditation:
            return """
            Ei, \(name)! Faz cerca de **48 horas** sem meditar. 🧘✨

            **Por que manter a rotina?**
            • Reduz ansiedade e estresse 🌿
            • Melhora foco, humor e recuperação mental 🧠
            • Apoia um sono mais reparador 😴
            • Facilita disciplina nos treinos e na dieta 🎯

            **Estímulo:** Basta 5–10 minutos. Respire, observe e solte — pequeno hábito, grande impacto.

            Abra **Treinos → Meditação** e cuide da mente hoje. 🕊️
            """

        case .both:
            return """
            Ei, \(name)! Faz cerca de **48 horas** sem cardio e sem meditação. 🏃🧘

            Esses dois hábitos se potencializam: o corpo se movimenta e a mente se acalma.

            **Benefícios do cardio** ❤️💨
            • Condicionamento cardiovascular
            • Mais energia e queima calórica
            • Humor e sono melhores

            **Benefícios da meditação** 🧠✨
            • Menos estresse e ansiedade
            • Mais foco e clareza
            • Recuperação mental para treinar melhor

            **Plano rápido de retorno**
            1. 5–10 min de meditação (Treinos → Meditação)
            2. 15–20 min de cardio leve (Treinos → Cardio)

            Pequenos passos reativam a rotina. Estou aqui no IAssistente para te acompanhar! 💪🌿
            """
        }
    }

    private static func isStale(
        reference: Date?,
        now: Date,
        threshold: TimeInterval
    ) -> Bool {
        guard let reference else { return false }
        return now.timeIntervalSince(reference) >= threshold
    }
}
