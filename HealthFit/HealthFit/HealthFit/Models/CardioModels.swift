import Foundation
import SwiftUI

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

    static let catalog: [CardioExercise] = [
        CardioExercise(name: "Corrida", description: "Corrida contínua em esteira ou ao ar livre", icon: "figure.run", caloriesPerMinute: 10),
        CardioExercise(name: "Caminhada Rápida", description: "Caminhada acelerada com inclinação moderada", icon: "figure.walk", caloriesPerMinute: 6),
        CardioExercise(name: "Bicicleta", description: "Bike ergométrica ou ciclismo", icon: "bicycle", caloriesPerMinute: 9),
        CardioExercise(name: "Elíptico", description: "Movimento fluido de corpo inteiro", icon: "figure.step.training", caloriesPerMinute: 8),
        CardioExercise(name: "Pular Corda", description: "Saltos contínuos com corda", icon: "figure.jumprope", caloriesPerMinute: 12),
        CardioExercise(name: "Escada", description: "Simulador de escadas ou degraus", icon: "figure.stair.stepper", caloriesPerMinute: 11),
        CardioExercise(name: "Remo", description: "Remo ergométrico de alta eficiência", icon: "figure.rower", caloriesPerMinute: 10),
        CardioExercise(name: "Natação", description: "Nados contínuos em piscina", icon: "figure.pool.swim", caloriesPerMinute: 11),
        CardioExercise(name: "Polichinelo", description: "Jumping jacks em ritmo constante", icon: "figure.mixed.cardio", caloriesPerMinute: 9),
        CardioExercise(name: "Burpees", description: "Exercício funcional de alta intensidade", icon: "figure.highintensity.intervaltraining", caloriesPerMinute: 13)
    ]
}

struct CardioWorkoutConfig: Hashable {
    let exercise: CardioExercise
    let intensity: CardioIntensity

    var title: String { "Cardio — \(exercise.name)" }
    var targetDurationSeconds: Int { intensity.durationMinutes * 60 }

    func estimatedCalories(for elapsedSeconds: Int) -> Double {
        let minutes = Double(elapsedSeconds) / 60.0
        return exercise.caloriesPerMinute * intensity.multiplier * minutes
    }
}
