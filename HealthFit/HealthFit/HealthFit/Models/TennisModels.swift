import CoreLocation
import Foundation
import SwiftUI

// MARK: - Sessão

/// Tipo de sessão — define intenção e leitura de carga.
enum TennisSessionType: String, Codable, CaseIterable, Identifiable, Hashable {
    case match = "Partida"
    case training = "Treino"
    case drill = "Drill"
    case lesson = "Aula"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .match: return "trophy.fill"
        case .training: return "figure.tennis"
        case .drill: return "target"
        case .lesson: return "person.2.fill"
        }
    }

    var detail: String {
        switch self {
        case .match: return "Jogo competitivo — carga alta e recuperação crítica"
        case .training: return "Treino livre ou com parceiro — volume controlado"
        case .drill: return "Blocos técnicos (saque, devolução, rede)"
        case .lesson: return "Aula com professor — intensidade variável"
        }
    }

    /// Peso na estimativa de carga (1.0 = treino padrão).
    var loadWeight: Double {
        switch self {
        case .match: return 1.25
        case .training: return 1.0
        case .drill: return 0.9
        case .lesson: return 0.85
        }
    }
}

enum TennisMatchFormat: String, Codable, CaseIterable, Identifiable, Hashable {
    case singles = "Simples"
    case doubles = "Duplas"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .singles: return "person.fill"
        case .doubles: return "person.2.fill"
        }
    }

    var loadWeight: Double {
        switch self {
        case .singles: return 1.0
        case .doubles: return 0.85
        }
    }
}

enum TennisCourtSurface: String, Codable, CaseIterable, Identifiable, Hashable {
    case hardOutdoor = "Duro (outdoor)"
    case hardIndoor = "Duro (indoor)"
    case clay = "Saibro"
    case grass = "Grama"
    case carpet = "Carpete"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .hardOutdoor: return "sun.max.fill"
        case .hardIndoor: return "building.2.fill"
        case .clay: return "circle.lefthalf.filled"
        case .grass: return "leaf.fill"
        case .carpet: return "rectangle.fill"
        }
    }

    var isOutdoor: Bool {
        switch self {
        case .hardIndoor, .carpet: return false
        default: return true
        }
    }

    var color: Color {
        switch self {
        case .hardOutdoor: return Color(red: 0.18, green: 0.45, blue: 0.85)
        case .hardIndoor: return Color(red: 0.35, green: 0.40, blue: 0.55)
        case .clay: return Color(red: 0.82, green: 0.42, blue: 0.22)
        case .grass: return Color(red: 0.28, green: 0.68, blue: 0.32)
        case .carpet: return Color(red: 0.55, green: 0.35, blue: 0.65)
        }
    }

    var detail: String {
        switch self {
        case .hardOutdoor: return "Ritmo rápido · GPS de cobertura e Flyover 3D da movimentação"
        case .hardIndoor: return "Sem GPS de quadra — foco em FC, picos e placar"
        case .clay: return "Deslizamentos · GPS de cobertura e Flyover da movimentação na quadra"
        case .grass: return "Rebote rápido · GPS de cobertura e Flyover da movimentação"
        case .carpet: return "Indoor sintético — pivôs curtos · sem Flyover de rota"
        }
    }

    /// Multiplicador de estresse articular na recuperação.
    var jointStressWeight: Double {
        switch self {
        case .hardOutdoor: return 1.15
        case .hardIndoor: return 1.1
        case .clay: return 0.95
        case .grass: return 1.05
        case .carpet: return 1.0
        }
    }
}

enum TennisSkillLevel: String, Codable, CaseIterable, Identifiable, Hashable {
    case beginner = "Iniciante"
    case intermediate = "Intermediário"
    case advanced = "Avançado"

    var id: String { rawValue }

    /// Meta sugerida de % do tempo em zona alta (FC).
    var highZoneGoalPercent: Double {
        switch self {
        case .beginner: return 25
        case .intermediate: return 35
        case .advanced: return 45
        }
    }
}

enum TennisHandedness: String, Codable, CaseIterable, Identifiable, Hashable {
    case right = "Destro"
    case left = "Canhoto"

    var id: String { rawValue }
}

enum TennisLoadBand: String, Codable, CaseIterable, Identifiable, Hashable {
    case light = "Leve"
    case moderate = "Moderada"
    case heavy = "Pesada"
    case extreme = "Extrema"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .light: return Color(red: 0.25, green: 0.75, blue: 0.45)
        case .moderate: return Color(red: 0.95, green: 0.72, blue: 0.18)
        case .heavy: return Color(red: 0.95, green: 0.45, blue: 0.22)
        case .extreme: return Color(red: 0.90, green: 0.22, blue: 0.28)
        }
    }

    var icon: String {
        switch self {
        case .light: return "leaf.fill"
        case .moderate: return "flame.fill"
        case .heavy: return "bolt.fill"
        case .extreme: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Setup / Snapshot

struct TennisSetup: Hashable, Codable {
    var sessionType: TennisSessionType
    var matchFormat: TennisMatchFormat
    var surface: TennisCourtSurface
    var skillLevel: TennisSkillLevel
    var handedness: TennisHandedness
    /// Meta opcional de sets (partida) ou blocos (treino).
    var targetSets: Int?
    /// Meta opcional de duração em minutos (0 = livre).
    var targetMinutes: Int?
    /// Meta de % do tempo em zona alta de FC.
    var highZoneGoalPercent: Double?
    var courtName: String
    var courtLatitude: Double?
    var courtLongitude: Double?

    static let `default` = TennisSetup(
        sessionType: .training,
        matchFormat: .singles,
        surface: .hardOutdoor,
        skillLevel: .intermediate,
        handedness: .right,
        targetSets: nil,
        targetMinutes: nil,
        highZoneGoalPercent: nil,
        courtName: "",
        courtLatitude: nil,
        courtLongitude: nil
    )

    var resolvedHighZoneGoalPercent: Double {
        highZoneGoalPercent ?? skillLevel.highZoneGoalPercent
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = courtLatitude, let lon = courtLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    func snapshot() -> TennisSessionSnapshot {
        TennisSessionSnapshot(
            sessionType: sessionType,
            matchFormat: matchFormat,
            surface: surface,
            skillLevel: skillLevel,
            handedness: handedness,
            targetSets: targetSets,
            targetMinutes: targetMinutes,
            highZoneGoalPercent: resolvedHighZoneGoalPercent,
            courtName: courtName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            courtLatitude: courtLatitude,
            courtLongitude: courtLongitude,
            gamesWon: 0,
            gamesLost: 0,
            setsWon: 0,
            setsLost: 0,
            burstCount: 0,
            highZoneSeconds: 0,
            recoverySeconds: 0,
            peakHeartRate: 0,
            averageHeartRate: 0,
            loadScore: 0,
            loadBand: .light,
            courtCoverageKm: 0,
            heatmapPoints: [],
            recoveryTips: []
        )
    }
}

struct TennisHeatmapPoint: Codable, Hashable, Identifiable {
    var id: UUID
    var latitude: Double
    var longitude: Double
    var intensity: Double

    init(id: UUID = UUID(), latitude: Double, longitude: Double, intensity: Double) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.intensity = min(max(intensity, 0), 1)
    }
}

struct TennisSessionSnapshot: Codable, Hashable {
    var sessionType: TennisSessionType
    var matchFormat: TennisMatchFormat
    var surface: TennisCourtSurface
    var skillLevel: TennisSkillLevel
    var handedness: TennisHandedness
    var targetSets: Int?
    var targetMinutes: Int?
    var highZoneGoalPercent: Double
    var courtName: String?
    var courtLatitude: Double?
    var courtLongitude: Double?

    // Placar
    var gamesWon: Int
    var gamesLost: Int
    var setsWon: Int
    var setsLost: Int

    // Carga intermitente
    var burstCount: Int
    var highZoneSeconds: Int
    var recoverySeconds: Int
    var peakHeartRate: Double
    var averageHeartRate: Double
    var loadScore: Double
    var loadBand: TennisLoadBand
    var courtCoverageKm: Double
    var heatmapPoints: [TennisHeatmapPoint]
    var recoveryTips: [String]

    var scoreLabel: String {
        "Sets \(setsWon)–\(setsLost) · Games \(gamesWon)–\(gamesLost)"
    }

    var highZonePercent: Double {
        let total = highZoneSeconds + recoverySeconds
        guard total > 0 else { return 0 }
        return (Double(highZoneSeconds) / Double(total)) * 100
    }
    
    var densityRatio: Double {
        let total = highZoneSeconds + recoverySeconds
        guard total > 0 else { return 0 }
        return Double(highZoneSeconds) / Double(total)
    }
}

// MARK: - Métricas ao vivo / análise

enum TennisMetricsEngine {
    /// Limiar de FC (fração da máxima estimada) para “zona alta”.
    static let highZoneFractionOfMaxHR = 0.75
    /// Aceleração (g) do Watch acima da qual conta um pico/explosão.
    static let burstAccelThresholdG = 2.2
    /// Intervalo mínimo entre picos (anti-ruído).
    static let burstCooldownSeconds: TimeInterval = 4

    static func estimatedMaxHR(age: Int?) -> Double {
        let years = max(16, min(age ?? 30, 80))
        return 220 - Double(years)
    }

    static func isHighZone(bpm: Double, maxHR: Double) -> Bool {
        guard bpm > 40, maxHR > 80 else { return false }
        return bpm >= maxHR * highZoneFractionOfMaxHR
    }

    static func computeLoadScore(
        setup: TennisSetup,
        activeSeconds: Int,
        highZoneSeconds: Int,
        burstCount: Int,
        calories: Double
    ) -> (score: Double, band: TennisLoadBand) {
        let minutes = max(1, Double(activeSeconds) / 60)
        let zoneFactor = min(1.5, Double(highZoneSeconds) / max(1, Double(activeSeconds)) * 2.2)
        let burstFactor = min(1.4, 0.6 + Double(burstCount) * 0.04)
        let calorieFactor = min(1.3, calories / max(minutes * 8, 1))
        let raw = minutes
            * setup.sessionType.loadWeight
            * setup.matchFormat.loadWeight
            * setup.surface.jointStressWeight
            * (0.55 + zoneFactor * 0.25 + burstFactor * 0.15 + calorieFactor * 0.05)
        let score = min(100, raw * 1.8)
        let band: TennisLoadBand
        switch score {
        case ..<25: band = .light
        case ..<50: band = .moderate
        case ..<75: band = .heavy
        default: band = .extreme
        }
        return (score, band)
    }

    static func recoveryTips(
        setup: TennisSetup,
        loadBand: TennisLoadBand,
        activeMinutes: Int,
        highZonePercent: Double
    ) -> [String] {
        var tips: [String] = []
        tips.append("Hidrate e reponha sódio — sessões de tênis perdem bastante suor em rajadas.")

        switch setup.surface {
        case .hardOutdoor, .hardIndoor:
            tips.append("Quadra dura: priorize mobilidade de tornozelo e descarga de joelhos (isometria de quadríceps).")
        case .clay:
            tips.append("Saibro: alongue adutores e aquecimento de quadril — deslizes aumentam carga medial.")
        case .grass:
            tips.append("Grama: fortaleça panturrilha e estabilização de tornozelo após a sessão.")
        case .carpet:
            tips.append("Carpete: foque em mobilidade de quadril e controle de pivô.")
        }

        if setup.sessionType == .match || loadBand == .heavy || loadBand == .extreme {
            tips.append("Manguito rotador e antebraço: 2–3 séries leves de rotação externa e wrist curls no dia seguinte.")
        }
        if highZonePercent >= 40 {
            tips.append("Muita zona alta: durma +7h e evite HIIT pesado nas próximas 24h.")
        }
        if activeMinutes >= 90 {
            tips.append("Volume longo: compressão leve nas panturrilhas e caminhada suave de 10 min ajudam a recuperação.")
        }
        if setup.matchFormat == .singles && setup.sessionType == .match {
            tips.append("Simples: priorize regeneração de pernas (isquios e glúteos) antes do próximo jogo.")
        }
        tips.append("Força específica: agachamento búlgaro, landmine press e face pulls 2×/semana sustentam o jogo.")
        return Array(tips.prefix(5))
    }

    /// Agrupa pontos GPS em células para heatmap aproximado da quadra.
    static func buildHeatmap(from route: [RouteCoordinate], maxPoints: Int = 48) -> [TennisHeatmapPoint] {
        let active = route.filter { !$0.isPaused }
        guard !active.isEmpty else { return [] }

        struct Cell: Hashable { let lat: Int; let lon: Int }
        var buckets: [Cell: (sumLat: Double, sumLon: Double, count: Int, speed: Double)] = [:]
        for p in active {
            let cell = Cell(lat: Int((p.latitude * 40_000).rounded()), lon: Int((p.longitude * 40_000).rounded()))
            var current = buckets[cell] ?? (0, 0, 0, 0)
            current.sumLat += p.latitude
            current.sumLon += p.longitude
            current.count += 1
            current.speed += max(0, p.speedMetersPerSecond ?? 0)
            buckets[cell] = current
        }

        let maxCount = buckets.values.map(\.count).max() ?? 1
        let points: [TennisHeatmapPoint] = buckets.values.map { cell in
            let intensity = Double(cell.count) / Double(maxCount)
            return TennisHeatmapPoint(
                latitude: cell.sumLat / Double(cell.count),
                longitude: cell.sumLon / Double(cell.count),
                intensity: intensity
            )
        }
        .sorted { $0.intensity > $1.intensity }

        return Array(points.prefix(maxPoints))
    }
}

// MARK: - Analytics / diário

struct TennisSessionEntry: Identifiable {
    var id: UUID
    var startedAt: Date
    var title: String
    var activeSeconds: Int
    var calories: Double
    var snapshot: TennisSessionSnapshot
}

enum TennisAnalytics {
    static func entries(from history: [ xWorkoutSession]) -> [TennisSessionEntry] {
        history.compactMap { session in
            guard session.isTennisSession, let snap = session.tennis else { return nil }
            return TennisSessionEntry(
                id: session.id,
                startedAt: session.startedAt,
                title: session.workoutTitle,
                activeSeconds: session.activeDurationSeconds,
                calories: session.caloriesBurned,
                snapshot: snap
            )
        }
        .sorted { $0.startedAt > $1.startedAt }
    }

    static func weeklyVolume(from entries: [TennisSessionEntry], weeks: Int = 8) -> [(label: String, sessions: Int, minutes: Int)] {
        let cal = Calendar.current
        let now = Date()
        return (0..<weeks).reversed().compactMap { offset -> (String, Int, Int)? in
            guard let start = cal.date(byAdding: .weekOfYear, value: -offset, to: now) else { return nil }
            let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: start)) ?? start
            let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            let weekEntries = entries.filter { $0.startedAt >= weekStart && $0.startedAt < weekEnd }
            let minutes = weekEntries.reduce(0) { $0 + $1.activeSeconds } / 60
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "pt_BR")
            formatter.setLocalizedDateFormatFromTemplate("dd/MM")
            return (formatter.string(from: weekStart), weekEntries.count, minutes)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
