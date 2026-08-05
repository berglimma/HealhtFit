import Foundation

/// Alertas de maré no IAssistente para quem pratica Surf / Kitesurf.
/// No máximo 1 mensagem proativa por dia (UserDefaults); welcome pode citar um resumo curto.
enum AssistantTideAlertEngine {
    private static let lastDeliveredDayKey = "assistant.tideAlert.lastDeliveredDay"
    private static let lastWelcomeDayKey = "assistant.tideAlert.lastWelcomeDay"

    /// Usuário pratica (ou praticou recentemente) surf ou kite.
    static func practicesWaterSport(sessions: [WorkoutSession], lookbackDays: Int = 90) -> Bool {
        let cutoff = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: .now) ?? .distantPast
        return sessions.contains { session in
            guard SurfKiteMetricsAnalyzer.isWaterSportSession(session) else { return false }
            let date = session.endedAt ?? session.startedAt
            return date >= cutoff
        }
    }

    static func practicesSurf(sessions: [WorkoutSession], lookbackDays: Int = 90) -> Bool {
        let cutoff = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: .now) ?? .distantPast
        return sessions.contains { session in
            guard SurfKiteMetricsAnalyzer.isSurfSession(session) else { return false }
            let date = session.endedAt ?? session.startedAt
            return date >= cutoff
        }
    }

    static func practicesKite(sessions: [WorkoutSession], lookbackDays: Int = 90) -> Bool {
        let cutoff = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: .now) ?? .distantPast
        return sessions.contains { session in
            guard SurfKiteMetricsAnalyzer.isKitesurfSession(session) else { return false }
            let date = session.endedAt ?? session.startedAt
            return date >= cutoff
        }
    }

    /// Bullet curto para o welcome do IAssistente (1×/dia).
    static func welcomeAlertIfNeeded(
        sessions: [WorkoutSession],
        snapshot: OpenMeteoWindService.Snapshot?,
        now: Date = .now
    ) -> String? {
        guard practicesWaterSport(sessions: sessions) else { return nil }
        guard !alreadyDeliveredToday(key: lastWelcomeDayKey, now: now) else { return nil }

        markDeliveredToday(key: lastWelcomeDayKey, now: now)

        let isKite = practicesKite(sessions: sessions)
        let isSurf = practicesSurf(sessions: sessions)
        let sportBit: String = {
            switch (isSurf, isKite) {
            case (true, true): return "Surf/Kite"
            case (false, true): return "Kitesurf"
            default: return "Surf"
            }
        }()

        if let snapshot {
            let fav = snapshot.favorability(isKitesurf: isKite && !isSurf)
            let tide = snapshot.estimatedTideLabel
            switch fav {
            case .favorable:
                return "\(sportBit): maré/condições parecem favoráveis agora (\(tide)). Confira Vento e maré em Treinos → Cardio."
            case .unfavorable:
                return "\(sportBit): maré ou vento menos ideais agora (\(tide)). Vale planejar o horário da sessão."
            case .moderate, .unknown:
                return "\(sportBit): confira a maré de hoje antes de ir à água — \(tide). Abra Cardio → Surf/Kitesurf."
            }
        }

        return "\(sportBit): dica de praia — confira maré e vento no app (Open-Meteo) antes da sessão. Treinos → Cardio."
    }

    /// Mensagem completa proativa (1×/dia, se ainda não enviada).
    static func proactiveMessageIfNeeded(
        athleteName: String,
        sessions: [WorkoutSession],
        snapshot: OpenMeteoWindService.Snapshot?,
        now: Date = .now
    ) -> String? {
        guard practicesWaterSport(sessions: sessions) else { return nil }
        guard !alreadyDeliveredToday(key: lastDeliveredDayKey, now: now) else { return nil }

        let name = athleteName.isEmpty ? "Atleta" : athleteName
        let isKite = practicesKite(sessions: sessions)
        let isSurf = practicesSurf(sessions: sessions)
        let sports: String = {
            switch (isSurf, isKite) {
            case (true, true): return "surf e kite"
            case (false, true): return "kitesurf"
            default: return "surf"
            }
        }()

        let body: String
        if let snapshot {
            let forKite = isKite && !isSurf
            let fav = snapshot.favorability(isKitesurf: forKite)
            let height = snapshot.seaLevelHeightMeters.map { String(format: "%+.2f m MSL", $0) }
                ?? snapshot.tideExtrema.first.map { String(format: "%.2f m", $0.heightMeters) }
                ?? "—"
            let phase = snapshot.estimatedPhaseLabel ?? snapshot.estimatedTideLabel
            let wind = String(format: "%.0f km/h · %@", snapshot.windSpeedKmh, snapshot.windLabel)
            let favLine = fav.badgeLabel + (fav.shortReason.map { " — \($0)" } ?? "")
            body = """
            Ei, \(name)! Alerta de maré para quem curte \(sports). 🌊

            **Condições recentes** (\(snapshot.locationLabel))
            • Maré: \(phase) · \(height)
            • Vento: \(wind)
            • Avaliação: \(favLine)

            \(encouragement(fav: fav, isKite: isKite))

            Revise o card **Vento e maré** em Treinos → Cardio (Surf/Kitesurf). Estimativa Open-Meteo Marine — não substitui tábua oficial.
            """
        } else {
            body = """
            Ei, \(name)! Como você pratica \(sports), vale checar a maré do dia. 🌊

            A maré muda o banco de areia, a entrada na água e a segurança da sessão. Abra **Treinos → Cardio → Surf ou Kitesurf** para ver vento e nível do mar (GPS + Open-Meteo).

            \(timeOfDayHint(now: now))
            """
        }

        markDeliveredToday(key: lastDeliveredDayKey, now: now)
        return body
    }

    // MARK: - Private

    private static func encouragement(fav: TideWindFavorability, isKite: Bool) -> String {
        switch fav {
        case .favorable:
            return isKite
                ? "**Hora de soltar o kite** — condições no ponto. Hidrate e revise o equipamento."
                : "**Hora de pegar onda** — maré no caminho certo. Respeito ao mar e ao local."
        case .moderate:
            return "Cenário ok com leitura atenta do pico. Se for, escolha o horário e o local com calma."
        case .unfavorable:
            return "Hoje o combo maré/vento pede cautela. Se for treinar, prefira spot conhecido e janela melhor."
        case .unknown:
            return "Sem leitura completa ainda — atualize Vento e maré com localização ligada."
        }
    }

    private static func timeOfDayHint(now: Date) -> String {
        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 5..<11:
            return "Manhã: muitas praias mudam rápido na enchente — confira o pico antes de sair."
        case 11..<17:
            return "Tarde: vento costuma subir; para kite, o mid-day costuma ser o sweet spot."
        default:
            return "Se planejar a sessão de amanhã, abra o card de condições à noite e de manhã de novo."
        }
    }

    private static func dayKey(for date: Date) -> String {
        let c = Calendar.current
        let y = c.component(.year, from: date)
        let m = c.component(.month, from: date)
        let d = c.component(.day, from: date)
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private static func alreadyDeliveredToday(key: String, now: Date) -> Bool {
        UserDefaults.standard.string(forKey: key) == dayKey(for: now)
    }

    private static func markDeliveredToday(key: String, now: Date) {
        UserDefaults.standard.set(dayKey(for: now), forKey: key)
    }
}
