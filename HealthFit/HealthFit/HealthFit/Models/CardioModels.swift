import Foundation
import SwiftUI

enum RunningDistance: Int, CaseIterable, Identifiable, Codable, Hashable {
    case five = 5
    case ten = 10
    case fifteen = 15
    case twenty = 20
    case twentyFive = 25
    case thirty = 30
    case thirtyFive = 35
    case forty = 40

    var id: Int { rawValue }

    var label: String { "\(rawValue) km" }

    var kilometers: Double { Double(rawValue) }

    var icon: String {
        switch self {
        case .five: return "5.circle.fill"
        case .ten: return "10.circle.fill"
        case .fifteen: return "15.circle.fill"
        case .twenty: return "20.circle.fill"
        case .twentyFive: return "25.circle.fill"
        case .thirty: return "30.circle.fill"
        case .thirtyFive: return "35.circle.fill"
        case .forty: return "40.circle.fill"
        }
    }

    var marathonRole: String {
        switch self {
        case .five: return "Velocidade e base aeróbica"
        case .ten: return "Ritmo de prova e resistência"
        case .fifteen: return "Volume intermediário para maratona"
        case .twenty: return "Longão de preparação"
        case .twentyFive: return "Simulação de fase avançada"
        case .thirty: return "Longão avançado de resistência"
        case .thirtyFive: return "Volume próximo à maratona"
        case .forty: return "Simulação quase completa"
        }
    }
}

enum CardioIntensity: String, CaseIterable, Codable, Identifiable, Hashable {
    case low = "Baixa"
    case medium = "Média"
    case high = "Alta"

    var id: String { rawValue }

    var durationMinutes: Int {
        switch self {
        case .low: return 50
        case .medium: return 40
        case .high: return 30
        }
    }

    var multiplier: Double {
        switch self {
        case .low: return 0.75
        case .medium: return 1.0
        case .high: return 1.35
        }
    }

    /// Ritmo estimado em segundos por km (corrida por distância).
    var paceSecondsPerKm: Int {
        switch self {
        case .low: return 420
        case .medium: return 360
        case .high: return 330
        }
    }

    var description: String {
        switch self {
        case .low: return "Ritmo leve, foco em resistência e recuperação"
        case .medium: return "Ritmo moderado, ideal para queima calórica"
        case .high: return "Ritmo intenso, máximo esforço cardiovascular"
        }
    }

    var icon: String {
        switch self {
        case .low: return "tortoise.fill"
        case .medium: return "figure.run"
        case .high: return "hare.fill"
        }
    }

    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return AppTheme.accentSecondary
        case .high: return .red
        }
    }

    func formattedPace() -> String {
        PaceFormatting.format(secondsPerKm: paceSecondsPerKm)
    }
}

struct CardioExercise: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var description: String
    var icon: String
    var caloriesPerMinute: Double

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        icon: String,
        caloriesPerMinute: Double
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.caloriesPerMinute = caloriesPerMinute
    }

    /// Corrida com metas de distância (livre / presets / personalizado).
    var supportsDistanceGoals: Bool {
        name == "Corrida"
    }

    /// Metas de km também em caminhada, bikes outdoor, remo e esteira (sem GPS).
    var supportsCustomDistanceGoals: Bool {
        supportsDistanceGoals || isOutdoorWalking || isOutdoorCycling || isRowing || isTreadmill
    }

    /// Natação em piscina: comprimento, voltas e diário.
    var supportsSwimmingPool: Bool {
        name == "Natação"
    }

    /// Cardio outdoor com mapa GPS (Corrida, caminhada, bikes, água, remo).
    var supportsOutdoorGPS: Bool {
        Self.outdoorGPSNames.contains(name)
    }

    /// Mountain bike ou bicicleta pedal (não ergométrica).
    var isOutdoorCycling: Bool {
        Self.outdoorCyclingNames.contains(name)
    }

    /// Caminhada outdoor (mapa GPS + passos, sem metas de distância de corrida).
    var isOutdoorWalking: Bool {
        Self.outdoorWalkingNames.contains(name)
    }

    var isStationaryBike: Bool {
        name == "Bicicleta ergométrica"
    }

    /// Esteira ergométrica indoor (academia/casa) — sem mapa GPS.
    var isTreadmill: Bool {
        name == "Esteira Ergométrica" || name == "Esteira ergométrica"
    }

    var isSurf: Bool { name == "Surf" }

    var isKitesurf: Bool {
        name == "Kitesurf" || name == "Kite Surf"
    }

    var isWaterSport: Bool { isSurf || isKitesurf }

    /// Remo (água ou ergométrico): SPM, split /500 m, eficiência e simetria.
    var isRowing: Bool { name == "Remo" }

    /// Escalada: vias, graus, clima, detecção de movimento e inventário de equipamento.
    var isClimbing: Bool { name == "Escalada" }

    /// Gradientes “foto” para cards de modalidade (lista de cardio).
    var coverColors: [Color] {
        switch name {
        case "Corrida":
            return [Color(red: 0.92, green: 0.38, blue: 0.18), Color(red: 0.55, green: 0.12, blue: 0.08)]
        case "Caminhada", "Caminhada Rápida":
            return [Color(red: 0.28, green: 0.72, blue: 0.48), Color(red: 0.12, green: 0.38, blue: 0.28)]
        case "Mountain bike":
            return [Color(red: 0.35, green: 0.55, blue: 0.22), Color(red: 0.12, green: 0.22, blue: 0.10)]
        case "Bicicleta pedal":
            return [Color(red: 0.22, green: 0.55, blue: 0.92), Color(red: 0.08, green: 0.22, blue: 0.48)]
        case "Bicicleta ergométrica":
            return [Color(red: 0.40, green: 0.48, blue: 0.58), Color(red: 0.18, green: 0.22, blue: 0.30)]
        case "Esteira Ergométrica", "Esteira ergométrica":
            return [Color(red: 0.72, green: 0.18, blue: 0.28), Color(red: 0.12, green: 0.10, blue: 0.14)]
        case "Surf":
            return [Color(red: 0.15, green: 0.62, blue: 0.85), Color(red: 0.05, green: 0.22, blue: 0.48)]
        case "Kitesurf", "Kite Surf":
            return [Color(red: 0.20, green: 0.78, blue: 0.88), Color(red: 0.08, green: 0.35, blue: 0.55)]
        case "Elíptico":
            return [Color(red: 0.25, green: 0.68, blue: 0.72), Color(red: 0.10, green: 0.32, blue: 0.40)]
        case "Pular Corda":
            return [Color(red: 0.95, green: 0.45, blue: 0.35), Color(red: 0.55, green: 0.18, blue: 0.32)]
        case "Escada":
            return [Color(red: 0.72, green: 0.48, blue: 0.28), Color(red: 0.35, green: 0.22, blue: 0.14)]
        case "Escalada":
            return [Color(red: 0.58, green: 0.48, blue: 0.42), Color(red: 0.25, green: 0.20, blue: 0.18)]
        case "Remo":
            return [Color(red: 0.18, green: 0.48, blue: 0.68), Color(red: 0.06, green: 0.20, blue: 0.35)]
        case "Natação":
            return [Color(red: 0.12, green: 0.55, blue: 0.78), Color(red: 0.04, green: 0.22, blue: 0.45)]
        case "Polichinelo":
            return [Color(red: 0.95, green: 0.62, blue: 0.22), Color(red: 0.70, green: 0.28, blue: 0.12)]
        case "Burpees":
            return [Color(red: 0.88, green: 0.22, blue: 0.28), Color(red: 0.42, green: 0.08, blue: 0.14)]
        default:
            return [AppTheme.accentSecondary, AppTheme.accent.opacity(0.7)]
        }
    }

    /// Asset de capa no mesmo padrão de `WorkoutProgramMale` / `WorkoutProgramFemale`.
    var coverImageName: String {
        switch name {
        case "Corrida": return "CardioCoverCorrida"
        case "Caminhada", "Caminhada Rápida": return "CardioCoverCaminhada"
        case "Mountain bike": return "CardioCoverMountainBike"
        case "Bicicleta pedal": return "CardioCoverBicicletaPedal"
        case "Bicicleta ergométrica": return "CardioCoverBicicletaErgometrica"
        case "Esteira Ergométrica", "Esteira ergométrica": return "CardioCoverEsteira"
        case "Surf": return "CardioCoverSurf"
        case "Kitesurf", "Kite Surf": return "CardioCoverKitesurf"
        case "Elíptico": return "CardioCoverEliptico"
        case "Pular Corda": return "CardioCoverPularCorda"
        case "Escada": return "CardioCoverEscada"
        case "Escalada": return "CardioCoverEscalada"
        case "Remo": return "CardioCoverRemo"
        case "Natação": return "CardioCoverNatacao"
        case "Polichinelo": return "CardioCoverPolichinelo"
        case "Burpees": return "CardioCoverBurpees"
        default: return "CardioCoverCorrida"
        }
    }

    /// SF Symbol da modalidade Surf (listas, setup, badges, resumo).
    static let surfSystemImage = "figure.surfing"
    /// SF Symbol da modalidade Kitesurf — vento (esporte a vela / powerkite); sem `figure.kitesurfing` no SF Symbols.
    static let kitesurfSystemImage = "wind"

    private static let outdoorGPSNames: Set<String> = [
        "Corrida", "Caminhada", "Caminhada Rápida", "Bicicleta pedal", "Mountain bike",
        "Surf", "Kitesurf", "Kite Surf", "Remo"
    ]

    /// Inclui o nome legado "Caminhada Rápida" para sessões / reconstrução antigas.
    private static let outdoorWalkingNames: Set<String> = [
        "Caminhada", "Caminhada Rápida"
    ]

    private static let outdoorCyclingNames: Set<String> = [
        "Bicicleta pedal", "Mountain bike"
    ]

    static let catalog: [CardioExercise] = [
        CardioExercise(name: "Corrida", description: "Corrida ao ar livre com mapa GPS, ritmo e rota", icon: "figure.run", caloriesPerMinute: 10),
        CardioExercise(name: "Esteira Ergométrica", description: "Indoor · configure se tem elevação · sem mapa GPS", icon: "figure.run.treadmill", caloriesPerMinute: 9),
        CardioExercise(name: "Caminhada", description: "Caminhada outdoor com mapa GPS, ritmo e passos", icon: "figure.walk", caloriesPerMinute: 6),
        CardioExercise(name: "Mountain bike", description: "Mountain bike em trilha ou terreno irregular", icon: "bicycle", caloriesPerMinute: 10),
        CardioExercise(name: "Bicicleta pedal", description: "Ciclismo outdoor em rua ou ciclovia", icon: "figure.outdoor.cycle", caloriesPerMinute: 9),
        CardioExercise(name: "Bicicleta ergométrica", description: "Bike estacionária indoor, sem GPS", icon: "figure.indoor.cycle", caloriesPerMinute: 8),
        CardioExercise(name: "Surf", description: "Sessão de surf com GPS, spot e registro de condições", icon: surfSystemImage, caloriesPerMinute: 10),
        CardioExercise(name: "Kitesurf", description: "Kitesurf com equipamento, modos, saltos e mapa", icon: kitesurfSystemImage, caloriesPerMinute: 12),
        CardioExercise(name: "Elíptico", description: "Movimento fluido de corpo inteiro", icon: "figure.step.training", caloriesPerMinute: 8),
        CardioExercise(name: "Pular Corda", description: "Saltos contínuos com corda", icon: "figure.jumprope", caloriesPerMinute: 12),
        CardioExercise(name: "Escada", description: "Simulador de escadas ou degraus", icon: "figure.stair.stepper", caloriesPerMinute: 11),
        CardioExercise(name: "Escalada", description: "Escalada em parede indoor ou rocha", icon: "figure.climbing", caloriesPerMinute: 11),
        CardioExercise(name: "Remo", description: "Remo na água ou ergométrico · SPM, split /500 m, eficiência e simetria", icon: "figure.rower", caloriesPerMinute: 10),
        CardioExercise(name: "Natação", description: "Nados em piscina com voltas, distância e ritmo", icon: "figure.pool.swim", caloriesPerMinute: 11),
        CardioExercise(name: "Polichinelo", description: "Jumping jacks em ritmo constante", icon: "figure.mixed.cardio", caloriesPerMinute: 9),
        CardioExercise(name: "Burpees", description: "Exercício funcional de alta intensidade", icon: "figure.highintensity.intervaltraining", caloriesPerMinute: 13)
    ]
}

enum PoolLength: Int, CaseIterable, Identifiable, Codable, Hashable {
    case twentyFive = 25
    case thirtyThree = 33
    case fifty = 50

    var id: Int { rawValue }

    var meters: Double { Double(rawValue) }

    var label: String { "\(rawValue) m" }

    var description: String {
        switch self {
        case .twentyFive: return "Piscina olímpica curta / clube"
        case .thirtyThree: return "Comum em academias"
        case .fifty: return "Piscina olímpica"
        }
    }
}

struct CardioWorkoutConfig: Hashable, Codable {
    let exercise: CardioExercise
    let intensity: CardioIntensity
    let runningDistance: RunningDistance?
    let targetCalories: Int?
    let isFreeRun: Bool
    /// Comprimento da piscina em metros (natação).
    let poolLengthMeters: Double?
    /// Meta opcional de voltas (natação).
    let targetSwimLaps: Int?
    /// Meta de distância personalizada (km) — corrida, caminhada ou bike.
    let customTargetDistanceKm: Double?
    /// Setup Surf / Kitesurf (equipamento, spot, maré/vento).
    let waterSportSetup: WaterSportSetup?
    /// Setup de remo (embarcação Single / Double / Four / Erg).
    let rowingSetup: RowingSetup?
    /// Setup de escalada (modalidade, graduação, setor e detecção de movimento).
    let climbingSetup: ClimbingSetup?
    /// Setup de esteira ergométrica (elevação / inclinação).
    let treadmillSetup: TreadmillSetup?

    init(
        exercise: CardioExercise,
        intensity: CardioIntensity,
        runningDistance: RunningDistance? = nil,
        targetCalories: Int? = nil,
        isFreeRun: Bool = false,
        poolLengthMeters: Double? = nil,
        targetSwimLaps: Int? = nil,
        customTargetDistanceKm: Double? = nil,
        waterSportSetup: WaterSportSetup? = nil,
        rowingSetup: RowingSetup? = nil,
        climbingSetup: ClimbingSetup? = nil,
        treadmillSetup: TreadmillSetup? = nil
    ) {
        self.exercise = exercise
        self.intensity = intensity
        self.runningDistance = runningDistance
        self.targetCalories = targetCalories
        self.isFreeRun = isFreeRun
        self.poolLengthMeters = poolLengthMeters
        self.targetSwimLaps = targetSwimLaps
        self.customTargetDistanceKm = customTargetDistanceKm
        self.waterSportSetup = waterSportSetup
        self.rowingSetup = rowingSetup
        self.climbingSetup = climbingSetup
        self.treadmillSetup = treadmillSetup
    }

    /// Rebuilds a usable config from a persisted active session (app relaunch / stuck session).
    static func reconstruct(from session: WorkoutSession?) -> CardioWorkoutConfig? {
        guard let session, WeeklyProgressAnalyzer.isCardioSession(session) else { return nil }

        let title = session.workoutTitle
        let lower = title.lowercased()

        let exerciseName: String = {
            if lower.contains("natação") || lower.contains("natacao") { return "Natação" }
            if lower.contains("escalada") || session.climbing != nil { return "Escalada" }
            if lower.contains("remo") || session.rowing != nil { return "Remo" }
            if lower.contains("kitesurf") || lower.contains("kite surf") { return "Kitesurf" }
            if session.waterSport?.isKitesurf == true { return "Kitesurf" }
            if lower.contains("surf") || session.waterSport != nil { return "Surf" }
            if lower.contains("corrida") { return "Corrida" }
            if lower.contains("caminhada") || lower.contains("walk") { return "Caminhada" }
            if lower.contains("mountain bike") { return "Mountain bike" }
            if lower.contains("bicicleta pedal") { return "Bicicleta pedal" }
            if lower.contains("bicicleta ergométrica") || lower.contains("bicicleta ergometrica") {
                return "Bicicleta ergométrica"
            }
            if lower.contains("esteira") {
                return "Esteira Ergométrica"
            }
            if let afterDash = title.components(separatedBy: " — ").dropFirst().first?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !afterDash.isEmpty {
                if afterDash.lowercased().hasPrefix("corrida") { return "Corrida" }
                if afterDash.lowercased().hasPrefix("natação")
                    || afterDash.lowercased().hasPrefix("natacao") {
                    return "Natação"
                }
                if afterDash.lowercased().hasPrefix("caminhada")
                    || afterDash.lowercased().hasPrefix("walk") {
                    return "Caminhada"
                }
                if afterDash.lowercased().contains("mountain") { return "Mountain bike" }
                if afterDash.lowercased().contains("bicicleta pedal")
                    || afterDash.lowercased().contains("bike") {
                    return "Bicicleta pedal"
                }
                let withoutDistance = afterDash
                    .replacingOccurrences(of: #"\s+\d+([.,]\d+)?\s*km"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return withoutDistance.isEmpty ? afterDash : withoutDistance
            }
            return "Corrida"
        }()

        // `allKnown` inclui as lutas: sem isso "Cardio — Boxe" voltaria como Corrida (e com GPS).
        let exercise = CardioExercise.allKnown.first(where: { $0.name == exerciseName })
            ?? CardioExercise.catalog.first(where: { $0.name == "Corrida" })
            ?? CardioExercise(
                id: session.workoutSheetId,
                name: exerciseName,
                description: "",
                icon: "figure.run",
                caloriesPerMinute: 10
            )

        // "livre" only marks free-run for running/walk/bike — never for Surf/Kitesurf.
        let isFreeRunFromTitle = lower.contains("livre") && !exercise.isWaterSport

        let intensity = CardioIntensity(rawValue: session.cardioIntensityLabel ?? "") ?? .medium
        let customKm = session.targetDistanceKm
        let runningDistance: RunningDistance? = {
            guard exercise.supportsDistanceGoals, !isFreeRunFromTitle else { return nil }
            guard let km = customKm else { return nil }
            if let match = RunningDistance(rawValue: Int(km.rounded())), abs(match.kilometers - km) < 0.05 {
                return match
            }
            return nil
        }()

        let customTarget: Double? = {
            guard !isFreeRunFromTitle, let km = customKm, km > 0 else { return nil }
            if runningDistance != nil { return nil }
            if exercise.supportsCustomDistanceGoals { return km }
            return nil
        }()

        return CardioWorkoutConfig(
            exercise: exercise,
            intensity: intensity,
            runningDistance: runningDistance,
            targetCalories: session.targetCalories,
            isFreeRun: exercise.isWaterSport || isFreeRunFromTitle || (
                exercise.supportsCustomDistanceGoals
                    && runningDistance == nil
                    && customTarget == nil
                    && session.targetDistanceKm == nil
            ),
            poolLengthMeters: session.poolLengthMeters,
            targetSwimLaps: session.targetSwimLaps,
            customTargetDistanceKm: customTarget,
            waterSportSetup: session.waterSport.map { snap in
                WaterSportSetup(
                    kiteEquipment: snap.kiteEquipment,
                    boardType: snap.boardType,
                    ridingMode: snap.ridingMode,
                    spot: snap.spot ?? WaterSpotInfo(name: ""),
                    conditions: snap.conditions ?? .empty
                )
            },
            rowingSetup: session.rowing.map { RowingSetup(boatType: $0.boatType) }
                ?? (exercise.isRowing ? .default : nil),
            climbingSetup: session.climbing.map { snap in
                ClimbingSetup(
                    discipline: snap.discipline,
                    gradeSystem: snap.gradeSystem,
                    targetGrade: snap.targetGradeLabel.map {
                        ClimbingGrade(system: snap.gradeSystem, label: $0)
                    },
                    areaName: snap.areaName ?? "",
                    areaLatitude: snap.areaLatitude,
                    areaLongitude: snap.areaLongitude
                )
            } ?? (exercise.isClimbing ? .default : nil),
            treadmillSetup: session.treadmill.map {
                TreadmillSetup(hasElevation: $0.hasElevation, inclinePercent: $0.inclinePercent)
            } ?? (exercise.isTreadmill ? .default : nil)
        )
    }

    var isDistanceRun: Bool {
        exercise.supportsDistanceGoals && !isFreeRun && targetDistanceKm > 0
    }

    /// Qualquer meta em km (corrida, caminhada, bike outdoor).
    var hasDistanceTarget: Bool {
        !isFreeRun && targetDistanceKm > 0 && !isSwimmingSession
    }

    /// Sessão de Corrida (metas de distância / corrida livre).
    var isRunningSession: Bool { exercise.supportsDistanceGoals }

    /// Natação com contagem de voltas e piscina.
    var isSwimmingSession: Bool { exercise.supportsSwimmingPool }

    /// Corrida, caminhada ou bike outdoor — mapa GPS, rota e métricas de movimento.
    var isOutdoorGPSCardio: Bool { exercise.supportsOutdoorGPS }

    /// Mountain bike / Bicicleta pedal (velocidade em vez de ritmo).
    var isOutdoorCyclingSession: Bool { exercise.isOutdoorCycling }

    var isSurfSession: Bool { exercise.isSurf }
    var isKitesurfSession: Bool { exercise.isKitesurf }
    var isWaterSportSession: Bool { exercise.isWaterSport }
    var isRowingSession: Bool { exercise.isRowing }
    var isClimbingSession: Bool { exercise.isClimbing }
    /// Esteira ergométrica indoor — sem mapa.
    var isTreadmillSession: Bool { exercise.isTreadmill }
    /// Luta: só cronômetro de combate, sem meta de distância, ritmo ou GPS.
    var isFightSession: Bool { exercise.isFight }
    var fightModality: FightModality? { exercise.fightModality }
    /// Escalada em rocha — clima, mapa e GPS só fazem sentido fora do ginásio.
    var isOutdoorClimbingSession: Bool {
        isClimbingSession && (climbingSetup?.discipline.isOutdoor ?? true)
    }

    /// Remo com barco na água (GPS + equilíbrio); erg também usa sensores sem exigir rota.
    var isWaterRowingSession: Bool {
        isRowingSession && (rowingSetup?.boatType.isOnWater ?? true)
    }

    /// Caminhada outdoor (mapa + passos + ritmo; sem metas 5–40 km de corrida).
    var isOutdoorWalkingSession: Bool { exercise.isOutdoorWalking }

    /// Modalidade do `RunTrackingService` (passos ligados em corrida e caminhada).
    var outdoorTrackingModality: OutdoorCardioModality {
        if isKitesurfSession { return .kitesurfing }
        if isSurfSession { return .surfing }
        if isRowingSession { return .rowing }
        if isOutdoorCyclingSession { return .cycling }
        if isOutdoorWalkingSession { return .walking }
        return .running
    }

    var hasCalorieGoal: Bool {
        guard let targetCalories else { return false }
        return targetCalories > 0
    }

    var resolvedPoolLengthMeters: Double {
        max(poolLengthMeters ?? 25, 10)
    }

    private var formattedTargetKm: String {
        let km = targetDistanceKm
        if abs(km - km.rounded()) < 0.05 {
            return "\(Int(km.rounded())) km"
        }
        return String(format: "%.1f km", km)
    }

    var title: String {
        // Water sports before isFreeRun — kite/surf use free-session tracking but must not inherit "Corrida livre".
        if isKitesurfSession {
            let spot = waterSportSetup?.spot.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if let mode = waterSportSetup?.ridingMode {
                if !spot.isEmpty {
                    return "Cardio — Kitesurf · \(mode.rawValue) · \(spot)"
                }
                return "Cardio — Kitesurf · \(mode.rawValue)"
            }
            if !spot.isEmpty {
                return "Cardio — Kitesurf · \(spot)"
            }
            return "Cardio — Kitesurf"
        }
        if isSurfSession {
            let spot = waterSportSetup?.spot.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if let board = waterSportSetup?.boardType {
                if !spot.isEmpty {
                    return "Cardio — Surf · \(board.rawValue) · \(spot)"
                }
                return "Cardio — Surf · \(board.rawValue)"
            }
            if !spot.isEmpty {
                return "Cardio — Surf · \(spot)"
            }
            return "Cardio — Surf"
        }
        if isRowingSession {
            let boat = rowingSetup?.boatType.rawValue ?? "Remo"
            if isFreeRun {
                return "Cardio — Remo · \(boat) livre"
            }
            if hasDistanceTarget {
                return "Cardio — Remo · \(boat) · \(formattedTargetKm)"
            }
            return "Cardio — Remo · \(boat)"
        }
        if isClimbingSession {
            let discipline = climbingSetup?.discipline.rawValue ?? "Escalada"
            let area = climbingSetup?.areaName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !area.isEmpty {
                return "Cardio — Escalada · \(discipline) · \(area)"
            }
            return "Cardio — Escalada · \(discipline)"
        }
        if isTreadmillSession {
            let elev: String
            if let setup = treadmillSetup, setup.hasElevation {
                let incline = setup.resolvedInclinePercent
                elev = incline > 0.05
                    ? String(format: "elevação %.0f%%", incline)
                    : "com elevação"
            } else {
                elev = "sem elevação"
            }
            if hasDistanceTarget {
                return "Cardio — Esteira · \(elev) · \(formattedTargetKm)"
            }
            return "Cardio — Esteira · \(elev)"
        }
        if isFightSession {
            return "Luta — \(exercise.name)"
        }
        if isFreeRun {
            if isOutdoorCyclingSession || isOutdoorWalkingSession || isRunningSession {
                return "Cardio — \(exercise.name) livre"
            }
            return "Cardio — Corrida livre"
        }
        if hasDistanceTarget {
            return "Cardio — \(exercise.name) \(formattedTargetKm)"
        }
        if isSwimmingSession {
            let pool = Int(resolvedPoolLengthMeters.rounded())
            if let laps = targetSwimLaps, laps > 0 {
                return "Cardio — Natação · \(pool) m · \(laps) voltas"
            }
            return "Cardio — Natação · \(pool) m"
        }
        return "Cardio — \(exercise.name)"
    }

    /// Métrica de desempenho da rota: ritmo (corrida/caminhada) ou velocidade (bike/água/remo).
    var routePerformanceMetric: RoutePerformanceMetric {
        if isOutdoorCyclingSession || isWaterSportSession || isRowingSession { return .speed }
        return .pace
    }

    var targetDistanceKm: Double {
        if isSwimmingSession, let laps = targetSwimLaps, laps > 0 {
            return (Double(laps) * resolvedPoolLengthMeters) / 1000.0
        }
        if let custom = customTargetDistanceKm, custom > 0 {
            return custom
        }
        return runningDistance?.kilometers ?? 0
    }

    var targetDurationSeconds: Int {
        // Meta de calorias é sessão aberta: o treino só encerra quando o usuário tocar em Finalizar.
        if hasCalorieGoal {
            return 0
        }
        if isFreeRun {
            return 0
        }
        if isSwimmingSession {
            let targetMeters = targetDistanceKm * 1000
            if targetMeters > 0 {
                let basePacePer100m = Double(intensity.swimPaceSecondsPer100m)
                return max(60, Int((targetMeters / 100.0) * basePacePer100m))
            }
            return intensity.durationMinutes * 60
        }
        if hasDistanceTarget {
            if isOutdoorCyclingSession {
                // Velocidade ref. ~18/22/28 km/h conforme intensidade.
                let speedKmh: Double
                switch intensity {
                case .low: speedKmh = 18
                case .medium: speedKmh = 22
                case .high: speedKmh = 28
                }
                return max(60, Int((targetDistanceKm / speedKmh) * 3600))
            }
            return Int(targetDistanceKm * Double(intensity.paceSecondsPerKm))
        }
        return intensity.durationMinutes * 60
    }

    func estimatedCalories(for elapsedSeconds: Int) -> Double {
        let minutes = Double(elapsedSeconds) / 60.0
        var kcal = exercise.caloriesPerMinute * intensity.multiplier * minutes
        if isTreadmillSession, let setup = treadmillSetup, setup.hasElevation {
            // Inclinação típica de esteira aumenta o gasto (~3% por ponto percentual).
            let incline = setup.resolvedInclinePercent
            kcal *= 1.0 + (incline * 0.03)
        }
        return kcal
    }

    /// Estimativa de kcal na natação por distância + intensidade (além do tempo).
    func estimatedSwimCalories(elapsedSeconds: Int, distanceMeters: Double, weightKg: Double = 70) -> Double {
        let timeBased = estimatedCalories(for: elapsedSeconds)
        let per100m = 0.45 + (intensity.multiplier - 0.75) * 0.25
        let distanceBased = (distanceMeters / 100.0) * per100m * weightKg
        return max(timeBased, distanceBased)
    }

    func estimatedDistanceKm(elapsedSeconds: Int) -> Double {
        if isOutdoorCyclingSession {
            let speedKmh: Double
            switch intensity {
            case .low: speedKmh = 18
            case .medium: speedKmh = 22
            case .high: speedKmh = 28
            }
            return (Double(elapsedSeconds) / 3600.0) * speedKmh
        }
        guard intensity.paceSecondsPerKm > 0 else { return 0 }
        return Double(elapsedSeconds) / Double(intensity.paceSecondsPerKm)
    }

    func paceSecondsPerKm(elapsedSeconds: Int, distanceKm: Double) -> Int {
        guard distanceKm > 0 else { return intensity.paceSecondsPerKm }
        return Int((Double(elapsedSeconds) / distanceKm).rounded())
    }

    func swimDistanceMeters(laps: Int) -> Double {
        Double(max(0, laps)) * resolvedPoolLengthMeters
    }

    /// Voltas a partir da distância de natação (HealthKit / Watch).
    static func swimLaps(fromDistanceMeters distance: Double, poolLengthMeters: Double) -> Int {
        let pool = max(poolLengthMeters, 1)
        guard distance > 0 else { return 0 }
        return max(0, Int((distance / pool).rounded(.down)))
    }

    func swimPaceSecondsPer100m(elapsedSeconds: Int, distanceMeters: Double) -> Int? {
        guard distanceMeters >= 25, elapsedSeconds > 0 else { return nil }
        return max(1, Int((Double(elapsedSeconds) / (distanceMeters / 100.0)).rounded()))
    }
}

extension CardioIntensity {
    /// Ritmo de referência em natação (segundos por 100 m).
    var swimPaceSecondsPer100m: Int {
        switch self {
        case .low: return 150
        case .medium: return 120
        case .high: return 95
        }
    }

    func formattedSwimPace() -> String {
        PaceFormatting.formatSwimPace(secondsPer100m: swimPaceSecondsPer100m)
    }
}

enum PaceFormatting {
    static let marathonDistanceKm = 42.195
    static let halfMarathonDistanceKm = 21.0975

    static func format(secondsPerKm: Int) -> String {
        let minutes = secondsPerKm / 60
        let seconds = secondsPerKm % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    static func formatSwimPace(secondsPer100m: Int) -> String {
        let minutes = secondsPer100m / 60
        let seconds = secondsPer100m % 60
        return String(format: "%d:%02d /100m", minutes, seconds)
    }

    static func formatDuration(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    static func projectedFinish(secondsPerKm: Int, distanceKm: Double) -> Int {
        Int((Double(secondsPerKm) * distanceKm).rounded())
    }
}

// MARK: - Esteira ergométrica

/// Configuração da esteira: se possui elevação/inclinação e o % usado.
struct TreadmillSetup: Hashable, Codable {
    /// A esteira tem controle de elevação (incline).
    var hasElevation: Bool
    /// Inclinação em % (0–15). Ignorado quando `hasElevation` é falso.
    var inclinePercent: Double

    static let `default` = TreadmillSetup(hasElevation: false, inclinePercent: 0)

    var resolvedInclinePercent: Double {
        guard hasElevation else { return 0 }
        return min(max(inclinePercent, 0), 15)
    }

    func snapshot(finalInclinePercent: Double? = nil) -> TreadmillSessionSnapshot {
        let incline = hasElevation
            ? min(max(finalInclinePercent ?? inclinePercent, 0), 15)
            : 0
        return TreadmillSessionSnapshot(
            hasElevation: hasElevation,
            inclinePercent: incline
        )
    }
}

/// Snapshot persistido da sessão de esteira.
struct TreadmillSessionSnapshot: Codable, Hashable {
    var hasElevation: Bool
    var inclinePercent: Double
}
