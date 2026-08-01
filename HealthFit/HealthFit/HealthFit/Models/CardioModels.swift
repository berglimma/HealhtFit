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

    /// Corrida com metas de distância (livre / 5–40 km).
    var supportsDistanceGoals: Bool {
        name == "Corrida"
    }

    /// Cardio outdoor com mapa GPS (Corrida e bikes ao ar livre).
    var supportsOutdoorGPS: Bool {
        Self.outdoorGPSNames.contains(name)
    }

    /// Mountain bike ou bicicleta pedal (não ergométrica).
    var isOutdoorCycling: Bool {
        Self.outdoorCyclingNames.contains(name)
    }

    var isStationaryBike: Bool {
        name == "Bicicleta ergométrica"
    }

    private static let outdoorGPSNames: Set<String> = [
        "Corrida", "Bicicleta pedal", "Mountain bike"
    ]

    private static let outdoorCyclingNames: Set<String> = [
        "Bicicleta pedal", "Mountain bike"
    ]

    static let catalog: [CardioExercise] = [
        CardioExercise(name: "Corrida", description: "Corrida contínua em esteira ou ao ar livre", icon: "figure.run", caloriesPerMinute: 10),
        CardioExercise(name: "Caminhada Rápida", description: "Caminhada acelerada com inclinação moderada", icon: "figure.walk", caloriesPerMinute: 6),
        CardioExercise(name: "Mountain bike", description: "Mountain bike em trilha ou terreno irregular", icon: "bicycle", caloriesPerMinute: 10),
        CardioExercise(name: "Bicicleta pedal", description: "Ciclismo outdoor em rua ou ciclovia", icon: "figure.outdoor.cycle", caloriesPerMinute: 9),
        CardioExercise(name: "Bicicleta ergométrica", description: "Bike estacionária indoor, sem GPS", icon: "figure.indoor.cycle", caloriesPerMinute: 8),
        CardioExercise(name: "Elíptico", description: "Movimento fluido de corpo inteiro", icon: "figure.step.training", caloriesPerMinute: 8),
        CardioExercise(name: "Pular Corda", description: "Saltos contínuos com corda", icon: "figure.jumprope", caloriesPerMinute: 12),
        CardioExercise(name: "Escada", description: "Simulador de escadas ou degraus", icon: "figure.stair.stepper", caloriesPerMinute: 11),
        CardioExercise(name: "Escalada", description: "Escalada em parede indoor ou rocha", icon: "figure.climbing", caloriesPerMinute: 11),
        CardioExercise(name: "Remo", description: "Remo ergométrico de alta eficiência", icon: "figure.rower", caloriesPerMinute: 10),
        CardioExercise(name: "Natação", description: "Nados contínuos em piscina", icon: "figure.pool.swim", caloriesPerMinute: 11),
        CardioExercise(name: "Polichinelo", description: "Jumping jacks em ritmo constante", icon: "figure.mixed.cardio", caloriesPerMinute: 9),
        CardioExercise(name: "Burpees", description: "Exercício funcional de alta intensidade", icon: "figure.highintensity.intervaltraining", caloriesPerMinute: 13)
    ]
}

struct CardioWorkoutConfig: Hashable {
    let exercise: CardioExercise
    let intensity: CardioIntensity
    let runningDistance: RunningDistance?
    let targetCalories: Int?
    let isFreeRun: Bool

    init(
        exercise: CardioExercise,
        intensity: CardioIntensity,
        runningDistance: RunningDistance? = nil,
        targetCalories: Int? = nil,
        isFreeRun: Bool = false
    ) {
        self.exercise = exercise
        self.intensity = intensity
        self.runningDistance = runningDistance
        self.targetCalories = targetCalories
        self.isFreeRun = isFreeRun
    }

    var isDistanceRun: Bool { runningDistance != nil && !isFreeRun }

    /// Sessão de Corrida (metas de distância / corrida livre).
    var isRunningSession: Bool { exercise.supportsDistanceGoals }

    /// Corrida ou bike outdoor — mapa GPS, rota e métricas de movimento.
    var isOutdoorGPSCardio: Bool { exercise.supportsOutdoorGPS }

    /// Mountain bike / Bicicleta pedal (velocidade em vez de ritmo).
    var isOutdoorCyclingSession: Bool { exercise.isOutdoorCycling }

    var hasCalorieGoal: Bool {
        guard let targetCalories else { return false }
        return targetCalories > 0
    }

    var title: String {
        if isFreeRun {
            return "Cardio — Corrida livre"
        }
        if let distance = runningDistance {
            return "Cardio — Corrida \(distance.label)"
        }
        return "Cardio — \(exercise.name)"
    }

    /// Métrica de desempenho da rota: ritmo (corrida) ou velocidade (bike).
    var routePerformanceMetric: RoutePerformanceMetric {
        isOutdoorCyclingSession ? .speed : .pace
    }

    var targetDistanceKm: Double {
        runningDistance?.kilometers ?? 0
    }

    var targetDurationSeconds: Int {
        if isFreeRun {
            return 0
        }
        if let distance = runningDistance {
            return Int(distance.kilometers * Double(intensity.paceSecondsPerKm))
        }
        return intensity.durationMinutes * 60
    }

    func estimatedCalories(for elapsedSeconds: Int) -> Double {
        let minutes = Double(elapsedSeconds) / 60.0
        return exercise.caloriesPerMinute * intensity.multiplier * minutes
    }

    func estimatedDistanceKm(elapsedSeconds: Int) -> Double {
        guard intensity.paceSecondsPerKm > 0 else { return 0 }
        return Double(elapsedSeconds) / Double(intensity.paceSecondsPerKm)
    }

    func paceSecondsPerKm(elapsedSeconds: Int, distanceKm: Double) -> Int {
        guard distanceKm > 0 else { return intensity.paceSecondsPerKm }
        return Int((Double(elapsedSeconds) / distanceKm).rounded())
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
