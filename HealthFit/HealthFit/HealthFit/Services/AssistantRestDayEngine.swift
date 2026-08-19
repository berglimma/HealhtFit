import Foundation

extension Notification.Name {
    static let healthFitRestDayMarked = Notification.Name("healthFitRestDayMarked")
}

/// Dia de descanso declarado + alerta de 7 dias seguidos (meditação não conta como treino).
enum AssistantRestDayEngine {
    private static let pendingMessageKey = "healthfit_pending_rest_day_message"
    private static let sevenDayAlertDayKey = "healthfit_rest_seven_day_alert_day"
    private static let restDayNotifiedDayKey = "healthfit_rest_day_notified_day"

    static let minimumConsecutiveTrainingDaysForAlert = 7

    // MARK: - Q&A

    static func matches(_ question: String) -> Bool {
        let normalized = normalize(question)
        if normalized.contains("entre series")
            || normalized.contains("entre séries")
            || normalized.contains("timer de descanso")
            || normalized.contains("pausa entre series")
            || normalized.contains("pausa entre séries") {
            return false
        }
        let keywords = [
            "dia de descanso", "dia descanso", "preciso descansar", "devo descansar",
            "overtraining", "over training", "7 dias seguidos", "sete dias seguidos",
            "treinar todo dia", "treino todo dia", "hipertrofia descanso",
            "recuperacao muscular", "recuperação muscular", "descanso ativo",
            "descanso entre treinos", "descanso pos treino", "descanso pós treino",
            "marquei descanso", "descanso e hipertrofia", "musculo descansa",
            "músculo descansa", "fadiga muscular", "super treino"
        ]
        return keywords.contains { normalized.contains($0) }
    }

    static func answer(for question: String, context: HealthAssistantContext) -> String {
        let name = context.user?.greetingName ?? "Atleta"
        let modalities = detectedModalities(context: context)
        var sections: [String] = []

        if context.isTodayRestDay {
            sections.append("Você marcou **hoje como dia de descanso** — excelente decisão, \(name)! 🛌")
        }

        if context.consecutiveTrainingDays >= minimumConsecutiveTrainingDaysForAlert, !context.isTodayRestDay {
            sections.append(
                """
                Você treinou **\(context.consecutiveTrainingDays) dias seguidos** (meditação não entra nessa conta). \
                O corpo precisa de pausa para adaptar e crescer — considere marcar descanso em **Perfil → Sono e Hidratação**.
                """
            )
        }

        sections.append(hypertrophyRestBlock)
        sections.append(contentsOf: modalityAdviceBlocks(for: modalities))

        sections.append(
            """
            
            **Resumo:** descanso não é preguiça — é quando músculo, tendões e sistema nervoso se adaptam. \
            Alterne estímulo e recuperação; meditação ajuda a mente, mas **não substitui** o descanso físico de um dia sem treino pesado.
            
            Marque seu descanso a qualquer hora no perfil. Estou aqui no IAssistente! 💪🌿
            """
        )

        return sections.joined(separator: "\n\n")
    }

    // MARK: - Proactive messages

    static func restDayMarkedMessage(context: HealthAssistantContext) -> String {
        let name = context.user?.greetingName ?? "Atleta"
        let modalities = detectedModalities(context: context)
        var parts = [
            """
            Registrado, \(name)! **Hoje é seu dia de descanso.** 🛌
            
            Descanso programado acelera resultados: o músculo cresce na recuperação, não só na carga.
            """
        ]
        parts.append(hypertrophyRestBlock)
        parts.append(contentsOf: modalityAdviceBlocks(for: modalities))
        parts.append(
            """
            
            Aproveite para hidratar, dormir bem e caminhar leve se quiser. Amanhã volte com energia — estou no IAssistente!
            """
        )
        return parts.joined(separator: "\n\n")
    }

    static func sevenDayStreakMessage(context: HealthAssistantContext) -> String {
        let name = context.user?.greetingName ?? "Atleta"
        let days = context.consecutiveTrainingDays
        let modalities = detectedModalities(context: context)
        var parts = [
            """
            \(name), atenção: você treinou **\(days) dias seguidos** sem pausa (meditação não conta). ⚠️
            
            Consistência é ótima, mas **sem descanso a hipertrofia estagna** e a fadiga acumula. Marque um dia de descanso em **Perfil → Sono e Hidratação** — o IAssistente acompanha.
            """
        ]
        parts.append(hypertrophyRestBlock)
        if let first = modalityAdviceBlocks(for: modalities).first {
            parts.append(first)
        }
        parts.append("Quer saber mais? Pergunte aqui sobre descanso, hipertrofia ou overtraining.")
        return parts.joined(separator: "\n\n")
    }

    static func welcomeAlertIfNeeded(context: HealthAssistantContext) -> String? {
        if context.isTodayRestDay {
            return "Dia de descanso marcado hoje — recuperação ativa conta como treino inteligente."
        }
        if shouldDeliverSevenDayAlert(consecutiveDays: context.consecutiveTrainingDays, isRestDay: context.isTodayRestDay) {
            return "Treinos: \(context.consecutiveTrainingDays) dias seguidos sem pausa — considere um dia de descanso para hipertrofia e recuperação."
        }
        return nil
    }

    static func shouldDeliverSevenDayAlert(
        consecutiveDays: Int,
        isRestDay: Bool,
        now: Date = .now
    ) -> Bool {
        guard consecutiveDays >= minimumConsecutiveTrainingDaysForAlert, !isRestDay else { return false }
        let dayKey = DailyWellnessEntry.dayKey(for: now)
        return UserDefaults.standard.string(forKey: sevenDayAlertDayKey) != dayKey
    }

    static func markSevenDayAlertDelivered(now: Date = .now) {
        UserDefaults.standard.set(DailyWellnessEntry.dayKey(for: now), forKey: sevenDayAlertDayKey)
    }

    @MainActor
    static func queueRestDayMarkedMessage(_ text: String) {
        UserDefaults.standard.set(text, forKey: pendingMessageKey)
        PostWorkoutCheckInService.shared.notifyAssistantMessagePending()

        let dayKey = DailyWellnessEntry.dayKey(for: .now)
        let alreadyNotifiedToday = UserDefaults.standard.string(forKey: restDayNotifiedDayKey) == dayKey
        if !alreadyNotifiedToday {
            NotificationService.shared.deliverAssistantMessageNotification(
                body: "Dia de descanso registrado. O IAssistente explica por que a recuperação acelera seus resultados."
            )
            UserDefaults.standard.set(dayKey, forKey: restDayNotifiedDayKey)
        }

        NotificationCenter.default.post(
            name: .healthFitRestDayMarked,
            object: nil,
            userInfo: ["message": text]
        )
    }

    static func consumePendingMessage() -> String? {
        guard let message = UserDefaults.standard.string(forKey: pendingMessageKey),
              !message.isEmpty else { return nil }
        UserDefaults.standard.removeObject(forKey: pendingMessageKey)
        return message
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: pendingMessageKey)
        UserDefaults.standard.removeObject(forKey: sevenDayAlertDayKey)
        UserDefaults.standard.removeObject(forKey: restDayNotifiedDayKey)
    }

    // MARK: - Modality detection

    enum RestDayModality: String, CaseIterable {
        case strength
        case home
        case cardio
        case fight
        case climbing
        case waterSport
        case rowing
        case general
    }

    static func detectedModalities(context: HealthAssistantContext) -> [RestDayModality] {
        var found = Set<RestDayModality>()
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        let recent = context.recentWorkoutSessions.filter {
            ($0.endedAt ?? $0.startedAt) >= cutoff
                && WeeklyProgressAnalyzer.isTrainingSession($0)
        }

        for session in recent {
            if session.climbing != nil {
                found.insert(.climbing)
            }
            if session.waterSport != nil {
                found.insert(.waterSport)
            }
            if session.rowing != nil {
                found.insert(.rowing)
            }
            if WeeklyProgressAnalyzer.isCardioSession(session) {
                let title = session.workoutTitle.lowercased()
                if title.contains("luta") || title.contains("boxe") || title.contains("jiu")
                    || title.contains("muay") || title.contains("mma") {
                    found.insert(.fight)
                } else {
                    found.insert(.cardio)
                }
            }
            let title = session.workoutTitle.lowercased()
            if title.contains("casa") || title.contains("home") || title.contains("hiit") {
                found.insert(.home)
            } else if !WeeklyProgressAnalyzer.isCardioSession(session), session.climbing == nil {
                found.insert(.strength)
            }
        }

        if let user = context.user {
            for id in user.effectivePracticedModalityIDs {
                if id == PracticeModalityID.strength { found.insert(.strength) }
                if id == PracticeModalityID.home { found.insert(.home) }
                if id == PracticeModalityID.fight { found.insert(.fight) }
                if id.hasPrefix("cardio.") && id != PracticeModalityID.fight { found.insert(.cardio) }
            }
        }

        if found.isEmpty { found.insert(.general) }
        return RestDayModality.allCases.filter { found.contains($0) }
    }

    // MARK: - Content blocks

    private static let hypertrophyRestBlock = """
    **Descanso e hipertrofia**
    • O músculo se adapta **depois** do estímulo — sono, alimentação e dias sem carga pesada são parte do ganho.
    • Treinar todo dia sem pausa eleva cortisol, reduz performance e aumenta risco de lesão.
    • Para hipertrofia, **1–2 dias de descanso por semana** (ou descanso ativo leve) costumam funcionar melhor que volume infinito.
    """

    private static func modalityAdviceBlocks(for modalities: [RestDayModality]) -> [String] {
        modalities.compactMap { modalityAdvice(for: $0) }
    }

    private static func modalityAdvice(for modality: RestDayModality) -> String? {
        switch modality {
        case .strength:
            return """
            **Musculação:** fibras musculares e sistema nervoso central precisam de 24–48 h após treinos pesados de força. \
            Sem descanso, a progressão de carga trava e a técnica piora.
            """
        case .home:
            return """
            **Treino em casa:** volume alto em HIIT ou calistenia também fatiga articulações e tendões. \
            Um dia off evita overuse e mantém consistência no mês.
            """
        case .cardio:
            return """
            **Cardio:** endurance melhora com ciclos de carga e recuperação. \
            Descanso reduz inflamação e permite que o coração e as pernas absorvam o volume.
            """
        case .fight:
            return """
            **Luta / combate:** impacto e sparring acumulam fadiga no SNC e nas articulações. \
            Descanso protege reação, timing e previne contusões por excesso.
            """
        case .climbing:
            return """
            **Escalada:** dedos, antebraços e ombros precisam de pausa — tendinite aparece quando não há dia off. \
            Escalar leve em rest day é ok; máximo no dedo, evite.
            """
        case .waterSport:
            return """
            **Surf / kite / esportes aquáticos:** remada e equilíbrio exigem core e ombros. \
            Mar e vento cansam — descanso seco recupera estabilizadores e prevenção de lesão.
            """
        case .rowing:
            return """
            **Remo / ergômetro:** lombar e posterior de coxa acumulam volume rápido. \
            Um dia sem remada pesada ajuda técnica e potência na próxima sessão.
            """
        case .general:
            return """
            **Recuperação geral:** alternar estímulo e descanso é o que sustenta progresso em qualquer modalidade.
            """
        }
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
    }
}
