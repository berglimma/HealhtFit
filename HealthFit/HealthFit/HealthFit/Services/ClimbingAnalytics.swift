import Foundation

// MARK: - Resultados

/// Uma sessão de escalada emparelhada com seu snapshot.
struct ClimbingSessionEntry: Identifiable, Hashable {
    let session: WorkoutSession
    let snapshot: ClimbingSessionSnapshot

    var id: UUID { session.id }
    var date: Date { session.startedAt }
    var attempts: [ClimbingAttempt] { snapshot.attempts }
    var durationSeconds: Int { Int(session.duration) }

    // WorkoutSession não é Hashable; a identidade da sessão já basta aqui.
    static func == (lhs: ClimbingSessionEntry, rhs: ClimbingSessionEntry) -> Bool {
        lhs.id == rhs.id && lhs.snapshot == rhs.snapshot
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Taxa de sucesso agregada por tipo de via.
struct ClimbingDisciplineStat: Identifiable, Hashable {
    let discipline: ClimbingDiscipline
    let attemptCount: Int
    let successCount: Int

    var id: String { discipline.rawValue }
    var successRate: Double {
        attemptCount > 0 ? Double(successCount) / Double(attemptCount) : 0
    }
    var successPercent: Int { Int((successRate * 100).rounded()) }
}

/// Evolução dentro de um grau (ex.: 6º, 7º).
struct ClimbingDegreeProgress: Identifiable, Hashable {
    let degree: Int
    let attemptCount: Int
    let successCount: Int
    /// Taxa de sucesso na metade mais antiga da amostra.
    let earlierSuccessRate: Double
    /// Taxa de sucesso na metade mais recente.
    let recentSuccessRate: Double
    let hardestSendLabel: String?

    var id: Int { degree }
    var successRate: Double {
        attemptCount > 0 ? Double(successCount) / Double(attemptCount) : 0
    }
    var delta: Double { recentSuccessRate - earlierSuccessRate }

    /// Só chamamos de tendência com amostra suficiente dos dois lados.
    var trend: ClimbingTrend {
        guard attemptCount >= 6 else { return .insufficientData }
        if delta > 0.08 { return .improving }
        if delta < -0.08 { return .declining }
        return .stable
    }
}

enum ClimbingTrend {
    case improving
    case stable
    case declining
    case insufficientData

    var label: String {
        switch self {
        case .improving: return "Evoluindo"
        case .stable: return "Estável"
        case .declining: return "Em queda"
        case .insufficientData: return "Amostra pequena"
        }
    }

    var icon: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        case .insufficientData: return "questionmark"
        }
    }
}

/// Volume de uma semana.
struct ClimbingWeekVolume: Identifiable, Hashable {
    let weekStart: Date
    let sessionCount: Int
    let attemptCount: Int
    let successCount: Int
    let activeMinutes: Int

    var id: Date { weekStart }

    var label: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd/MM"
        return formatter.string(from: weekStart)
    }
}

/// Desempenho em uma faixa de temperatura ou umidade.
struct ClimbingConditionBucket: Identifiable, Hashable {
    let label: String
    let attemptCount: Int
    let successCount: Int

    var id: String { label }
    var successRate: Double {
        attemptCount > 0 ? Double(successCount) / Double(attemptCount) : 0
    }
    var successPercent: Int { Int((successRate * 100).rounded()) }
}

/// Leitura de prontidão para uma via mais difícil.
struct ClimbingReadiness {
    enum Level {
        case ready
        case moderate
        case rest

        var label: String {
            switch self {
            case .ready: return "Pronto"
            case .moderate: return "Parcial"
            case .rest: return "Priorize descanso"
            }
        }
    }

    let level: Level
    let sleepHours: Double?
    let hrvMs: Double?
    let hoursSinceLastClimb: Double?
    let reasons: [String]
}

// MARK: - Motor de análise

/// Estatísticas de escalada derivadas do histórico de sessões.
enum ClimbingAnalytics {
    /// Extrai apenas as sessões de escalada, da mais recente para a mais antiga.
    static func entries(from sessions: [WorkoutSession]) -> [ClimbingSessionEntry] {
        sessions
            .compactMap { session in
                guard let snapshot = session.climbing else { return nil }
                return ClimbingSessionEntry(session: session, snapshot: snapshot)
            }
            .sorted { $0.date > $1.date }
    }

    static func allAttempts(from entries: [ClimbingSessionEntry]) -> [ClimbingAttempt] {
        entries.flatMap(\.attempts)
    }

    // MARK: Taxa de sucesso por tipo de via

    static func disciplineStats(from entries: [ClimbingSessionEntry]) -> [ClimbingDisciplineStat] {
        let attempts = allAttempts(from: entries)
        let grouped = Dictionary(grouping: attempts, by: \.discipline)
        return grouped
            .map { discipline, list in
                ClimbingDisciplineStat(
                    discipline: discipline,
                    attemptCount: list.count,
                    successCount: list.filter(\.isSuccess).count
                )
            }
            .sorted { $0.successRate < $1.successRate }
    }

    // MARK: Progressão por grau

    static func degreeProgress(from entries: [ClimbingSessionEntry]) -> [ClimbingDegreeProgress] {
        // Cronológico: a divisão em metades precisa respeitar a linha do tempo.
        let attempts = allAttempts(from: entries).sorted { $0.recordedAt < $1.recordedAt }
        let grouped = Dictionary(grouping: attempts) { $0.grade.brazilianDegree }

        return grouped
            .compactMap { degree, list -> ClimbingDegreeProgress? in
                guard let degree else { return nil }
                let midpoint = list.count / 2
                let earlier = Array(list.prefix(midpoint))
                let recent = Array(list.suffix(list.count - midpoint))

                let hardest = list
                    .filter(\.isSuccess)
                    .max { $0.grade.difficultyPoints < $1.grade.difficultyPoints }

                return ClimbingDegreeProgress(
                    degree: degree,
                    attemptCount: list.count,
                    successCount: list.filter(\.isSuccess).count,
                    earlierSuccessRate: rate(of: earlier),
                    recentSuccessRate: rate(of: recent),
                    hardestSendLabel: hardest?.grade.displayLabel
                )
            }
            .sorted { $0.degree < $1.degree }
    }

    static func degreeProgress(from entries: [ClimbingSessionEntry], degree: Int) -> ClimbingDegreeProgress? {
        degreeProgress(from: entries).first { $0.degree == degree }
    }

    // MARK: Volume semanal

    static func weeklyVolume(from entries: [ClimbingSessionEntry], weeks: Int = 8) -> [ClimbingWeekVolume] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // segunda
        let grouped = Dictionary(grouping: entries) { entry -> Date in
            calendar.dateInterval(of: .weekOfYear, for: entry.date)?.start ?? entry.date
        }

        return grouped
            .map { weekStart, list in
                let attempts = list.flatMap(\.attempts)
                return ClimbingWeekVolume(
                    weekStart: weekStart,
                    sessionCount: list.count,
                    attemptCount: attempts.count,
                    successCount: attempts.filter(\.isSuccess).count,
                    activeMinutes: list.reduce(0) { $0 + $1.snapshot.activeClimbingSeconds } / 60
                )
            }
            .sorted { $0.weekStart > $1.weekStart }
            .prefix(weeks)
            .reversed()
    }

    // MARK: Grau mais difícil encadenado

    static func hardestSend(from entries: [ClimbingSessionEntry]) -> ClimbingAttempt? {
        allAttempts(from: entries)
            .filter(\.isSuccess)
            .max { $0.grade.difficultyPoints < $1.grade.difficultyPoints }
    }

    // MARK: Desempenho por condição

    static func temperatureBuckets(from entries: [ClimbingSessionEntry]) -> [ClimbingConditionBucket] {
        buckets(from: entries, value: { $0.snapshot.temperatureCelsius }) { temp in
            switch temp {
            case ..<10: return "Abaixo de 10 °C"
            case ..<16: return "10–16 °C"
            case ..<22: return "16–22 °C"
            case ..<28: return "22–28 °C"
            default: return "Acima de 28 °C"
            }
        }
    }

    static func humidityBuckets(from entries: [ClimbingSessionEntry]) -> [ClimbingConditionBucket] {
        buckets(from: entries, value: { $0.snapshot.humidityPercent }) { humidity in
            switch humidity {
            case ..<40: return "Seco (< 40%)"
            case ..<60: return "Ameno (40–60%)"
            case ..<80: return "Úmido (60–80%)"
            default: return "Muito úmido (> 80%)"
            }
        }
    }

    /// Faixa com melhor taxa de sucesso, exigindo amostra mínima para não virar ruído.
    static func bestBucket(_ buckets: [ClimbingConditionBucket], minimumAttempts: Int = 4) -> ClimbingConditionBucket? {
        buckets
            .filter { $0.attemptCount >= minimumAttempts }
            .max { $0.successRate < $1.successRate }
    }

    // MARK: Prontidão

    static func readiness(
        entries: [ClimbingSessionEntry],
        sleepHours: Double?,
        hrvMs: Double?,
        restingHeartRate: Double? = nil
    ) -> ClimbingReadiness {
        var reasons: [String] = []
        var score = 0

        if let sleepHours {
            if sleepHours >= 7 {
                score += 2
                reasons.append(String(format: "Sono de %.1f h na faixa recomendada.", sleepHours))
            } else if sleepHours >= 6 {
                score += 1
                reasons.append(String(format: "Sono de %.1f h — um pouco abaixo do ideal de 7–9 h.", sleepHours))
            } else {
                reasons.append(String(format: "Sono de %.1f h, abaixo de 6 h. É o fator que mais pesa contra hoje.", sleepHours))
            }
        } else {
            reasons.append("Sem registro de sono — anote em Sono e Hidratação para eu incluir na leitura.")
        }

        // Comparação da HRV com a média das sessões anteriores, quando existe base.
        let historicHRV = entries.compactMap(\.snapshot.hrvMsBefore)
        if let hrvMs {
            if let baseline = average(historicHRV), baseline > 0 {
                let delta = (hrvMs - baseline) / baseline
                if delta >= -0.05 {
                    score += 2
                    reasons.append(String(format: "HRV de %.0f ms, em linha com sua média de %.0f ms.", hrvMs, baseline))
                } else if delta >= -0.15 {
                    score += 1
                    reasons.append(String(format: "HRV de %.0f ms, um pouco abaixo da média de %.0f ms.", hrvMs, baseline))
                } else {
                    reasons.append(String(format: "HRV de %.0f ms, bem abaixo da média de %.0f ms — sinal de recuperação incompleta.", hrvMs, baseline))
                }
            } else {
                score += 1
                reasons.append(String(format: "HRV de %.0f ms registrada. Ainda montando sua linha de base.", hrvMs))
            }
        } else {
            reasons.append("Sem HRV recente do Apple Watch — durma com o relógio para eu acompanhar a recuperação.")
        }

        let hoursSince = entries.first.map { Date().timeIntervalSince($0.date) / 3600 }
        if let hoursSince {
            if hoursSince >= 48 {
                score += 2
                reasons.append(String(format: "Última escalada há %.0f h — dedos e polias tiveram tempo de recuperar.", hoursSince))
            } else if hoursSince >= 24 {
                score += 1
                reasons.append(String(format: "Última escalada há %.0f h. Um dia de intervalo é o mínimo para tentar seu limite.", hoursSince))
            } else {
                reasons.append(String(format: "Você escalou há %.0f h. Dois dias seguidos no limite é o caminho curto para lesão de polia.", hoursSince))
            }
        }

        let level: ClimbingReadiness.Level = {
            if score >= 5 { return .ready }
            if score >= 3 { return .moderate }
            return .rest
        }()

        return ClimbingReadiness(
            level: level,
            sleepHours: sleepHours,
            hrvMs: hrvMs,
            hoursSinceLastClimb: hoursSince,
            reasons: reasons
        )
    }

    // MARK: - Helpers

    private static func rate(of attempts: [ClimbingAttempt]) -> Double {
        guard !attempts.isEmpty else { return 0 }
        return Double(attempts.filter(\.isSuccess).count) / Double(attempts.count)
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func buckets(
        from entries: [ClimbingSessionEntry],
        value: (ClimbingSessionEntry) -> Double?,
        label: (Double) -> String
    ) -> [ClimbingConditionBucket] {
        var tally: [String: (attempts: Int, successes: Int)] = [:]

        for entry in entries {
            guard let measurement = value(entry), !entry.attempts.isEmpty else { continue }
            let key = label(measurement)
            let successes = entry.attempts.filter(\.isSuccess).count
            let current = tally[key] ?? (0, 0)
            tally[key] = (current.attempts + entry.attempts.count, current.successes + successes)
        }

        return tally
            .map { ClimbingConditionBucket(label: $0.key, attemptCount: $0.value.attempts, successCount: $0.value.successes) }
            .sorted { $0.successRate > $1.successRate }
    }
}
