import Foundation
import SwiftUI

/// Nível de dificuldade das séries guiadas em Treinos.
enum WorkoutLevel: String, CaseIterable, Codable, Identifiable, Hashable {
    case beginner = "Iniciante"
    case intermediate = "Intermediário"
    case advanced = "Avançado"

    var id: String { rawValue }

    var pluralTitle: String {
        switch self {
        case .beginner: return "Iniciantes"
        case .intermediate: return "Intermediários"
        case .advanced: return "Avançados"
        }
    }

    var subtitle: String {
        switch self {
        case .beginner: return "Técnica, carga leve e volume controlado"
        case .intermediate: return "Volume moderado e progressão de carga"
        case .advanced: return "Alta intensidade, volume e complexidade"
        }
    }

    var icon: String {
        switch self {
        case .beginner: return "leaf.fill"
        case .intermediate: return "flame.fill"
        case .advanced: return "bolt.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .beginner: return Color(red: 0.35, green: 0.72, blue: 0.55)
        case .intermediate: return AppTheme.accentSecondary
        case .advanced: return Color(red: 0.92, green: 0.38, blue: 0.38)
        }
    }
}

/// Foco do treino guiado — também dirige o ajuste do cardápio.
enum WorkoutFocus: String, CaseIterable, Codable, Identifiable, Hashable {
    case muscleGain = "Ganho de massa muscular"
    case fatLoss = "Perda de gordura"
    case legs = "Foco em pernas"
    case competition = "Foco em competição"
    case arms = "Foco em braços"
    case back = "Costas"

    var id: String { rawValue }

    var shortTitle: String { rawValue }

    var subtitle: String {
        switch self {
        case .muscleGain: return "Hipertrofia com superávit calórico"
        case .fatLoss: return "Déficit proteico e treino metabólico"
        case .legs: return "Quadríceps, posteriores e glúteos"
        case .competition: return "Performance, potência e recuperação"
        case .arms: return "Bíceps, tríceps e volume de braços"
        case .back: return "Largura, espessura e postura"
        }
    }

    var icon: String {
        switch self {
        case .muscleGain: return "dumbbell.fill"
        case .fatLoss: return "flame.fill"
        case .legs: return "figure.run"
        case .competition: return "trophy.fill"
        case .arms: return "figure.strengthtraining.functional"
        case .back: return "figure.climbing"
        }
    }

    var accentColor: Color {
        switch self {
        case .muscleGain: return AppTheme.accent
        case .fatLoss: return Color(red: 0.92, green: 0.38, blue: 0.38)
        case .legs: return Color(red: 0.45, green: 0.62, blue: 0.95)
        case .competition: return AppTheme.accentSecondary
        case .arms: return Color(red: 0.72, green: 0.48, blue: 0.92)
        case .back: return Color(red: 0.35, green: 0.72, blue: 0.75)
        }
    }
}

/// Template curado do catálogo guiado (nível e/ou foco).
struct GuidedWorkoutTemplate: Identifiable, Hashable {
    let id: UUID
    let title: String
    let description: String
    let level: WorkoutLevel?
    let focus: WorkoutFocus?
    let exercises: [Exercise]

    func makeSheet(targetGender: Gender? = nil) -> WorkoutSheet {
        let scaled = exercises.map { exercise in
            GuidedWorkoutCatalog.scaledExercise(exercise, for: targetGender)
        }
        return WorkoutSheet(
            id: id,
            title: title,
            description: description,
            exercises: scaled,
            isUserCreated: false,
            targetGender: targetGender,
            createdByAssistant: false
        )
    }
}

enum GuidedWorkoutCatalog {
    static var allTitles: Set<String> {
        Set(all.map(\.title))
    }

    static func templates(for level: WorkoutLevel) -> [GuidedWorkoutTemplate] {
        all.filter { $0.level == level }
    }

    static func templates(for focus: WorkoutFocus) -> [GuidedWorkoutTemplate] {
        all.filter { $0.focus == focus }
    }

    static func template(matchingTitle title: String) -> GuidedWorkoutTemplate? {
        all.first { $0.title == title }
    }

    static func sheets(for gender: Gender?) -> [WorkoutSheet] {
        all.map { $0.makeSheet(targetGender: gender) }
    }

    /// Ajusta cargas sugeridas para o perfil do programa.
    static func scaledExercise(_ exercise: Exercise, for gender: Gender?) -> Exercise {
        guard let weight = exercise.weight else { return exercise }
        let factor: Double
        switch gender {
        case .female: factor = 0.55
        case .male, .none: factor = 1.0
        }
        let scaled = (weight * factor * 2).rounded() / 2
        return Exercise(
            id: exercise.id,
            name: exercise.name,
            sets: exercise.sets,
            reps: exercise.reps,
            weight: max(scaled, 2.5),
            restSeconds: exercise.restSeconds,
            notes: exercise.notes,
            muscleGroup: exercise.muscleGroup
        )
    }

    // MARK: - Aquecimento e abdômen

    static let warmupNote = "Aquecimento"

    enum WarmupStyle {
        /// Aquecimento de membros superiores (2 exercícios).
        case upper
        /// Aquecimento de membros inferiores (2 exercícios).
        case lower
    }

    enum AbsPair {
        case plankCrunch
        case legsBicycle
        case plankOblique
        case infraBicycle
        case plankLegs
        case crunchBicycle
    }

    /// Monta a ficha: aquecimento + trabalho principal (sem core) + 2 exercícios de abdômen.
    static func withWarmupAndAbs(
        _ main: [Exercise],
        level: WorkoutLevel?,
        warmup: WarmupStyle = .upper,
        abs: AbsPair = .plankCrunch
    ) -> [Exercise] {
        let mainWork = main.filter { $0.muscleGroup != .core && $0.notes != warmupNote }
        return warmupBlock(style: warmup, level: level) + mainWork + absBlock(pair: abs, level: level)
    }

    static func warmupBlock(style: WarmupStyle, level: WorkoutLevel?) -> [Exercise] {
        let volume = warmupVolume(for: level)
        switch style {
        case .upper:
            return [
                Exercise(name: "Polichinelo", sets: volume.sets, reps: 20, restSeconds: volume.rest, notes: warmupNote, muscleGroup: .fullBody),
                Exercise(name: "Círculos de Braços", sets: volume.sets, reps: 15, restSeconds: volume.rest, notes: warmupNote, muscleGroup: .shoulders)
            ]
        case .lower:
            return [
                Exercise(name: "Abertura de Quadril", sets: volume.sets, reps: 12, restSeconds: volume.rest, notes: warmupNote, muscleGroup: .legs),
                Exercise(name: "Agachamento Corporal", sets: volume.sets, reps: 12, restSeconds: volume.rest, notes: warmupNote, muscleGroup: .legs)
            ]
        }
    }

    static func absBlock(pair: AbsPair, level: WorkoutLevel?) -> [Exercise] {
        let volume = absVolume(for: level)
        switch pair {
        case .plankCrunch:
            return [
                Exercise(name: "Prancha", sets: volume.sets, reps: volume.holdReps, restSeconds: volume.rest, muscleGroup: .core),
                Exercise(name: "Abdominal Crunch", sets: volume.sets, reps: volume.crunchReps, restSeconds: volume.rest, muscleGroup: .core)
            ]
        case .legsBicycle:
            return [
                Exercise(name: "Elevação de Pernas", sets: volume.sets, reps: volume.crunchReps, restSeconds: volume.rest, muscleGroup: .core),
                Exercise(name: "Abdominal Bicicleta", sets: volume.sets, reps: volume.crunchReps, restSeconds: volume.rest, muscleGroup: .core)
            ]
        case .plankOblique:
            return [
                Exercise(name: "Prancha", sets: volume.sets, reps: volume.holdReps, restSeconds: volume.rest, muscleGroup: .core),
                Exercise(name: "Abdominal Oblíquo", sets: volume.sets, reps: volume.crunchReps, restSeconds: volume.rest, muscleGroup: .core)
            ]
        case .infraBicycle:
            return [
                Exercise(name: "Abdominal Infra", sets: volume.sets, reps: volume.crunchReps, restSeconds: volume.rest, muscleGroup: .core),
                Exercise(name: "Abdominal Bicicleta", sets: volume.sets, reps: volume.crunchReps, restSeconds: volume.rest, muscleGroup: .core)
            ]
        case .plankLegs:
            return [
                Exercise(name: "Prancha", sets: volume.sets, reps: volume.holdReps, restSeconds: volume.rest, muscleGroup: .core),
                Exercise(name: "Elevação de Pernas", sets: volume.sets, reps: volume.crunchReps, restSeconds: volume.rest, muscleGroup: .core)
            ]
        case .crunchBicycle:
            return [
                Exercise(name: "Abdominal Crunch", sets: volume.sets, reps: volume.crunchReps, restSeconds: volume.rest, muscleGroup: .core),
                Exercise(name: "Abdominal Bicicleta", sets: volume.sets, reps: volume.crunchReps, restSeconds: volume.rest, muscleGroup: .core)
            ]
        }
    }

    private static func warmupVolume(for level: WorkoutLevel?) -> (sets: Int, rest: Int) {
        switch level {
        case .beginner, .none: return (2, 30)
        case .intermediate: return (2, 25)
        case .advanced: return (3, 20)
        }
    }

    private static func absVolume(for level: WorkoutLevel?) -> (sets: Int, holdReps: Int, crunchReps: Int, rest: Int) {
        switch level {
        case .beginner, .none: return (3, 30, 15, 40)
        case .intermediate: return (3, 40, 18, 40)
        case .advanced: return (3, 45, 20, 45)
        }
    }

    // MARK: - Catalog

    static let all: [GuidedWorkoutTemplate] = levelSeries + focusSeries

    private static let levelSeries: [GuidedWorkoutTemplate] = [
        GuidedWorkoutTemplate(
            id: uuid("g-lvl-beg-full"),
            title: "Guiado — Iniciante Full Body",
            description: "Introdução à musculação com movimentos fundamentais e descanso generoso.",
            level: .beginner,
            focus: nil,
            exercises: withWarmupAndAbs([
                Exercise(name: "Agachamento Livre", sets: 3, reps: 12, weight: 40, restSeconds: 90, muscleGroup: .legs),
                Exercise(name: "Supino Reto", sets: 3, reps: 12, weight: 30, restSeconds: 90, muscleGroup: .chest),
                Exercise(name: "Remada Unilateral", sets: 3, reps: 12, weight: 12, restSeconds: 75, muscleGroup: .back),
                Exercise(name: "Desenvolvimento com Halteres", sets: 3, reps: 12, weight: 10, restSeconds: 75, muscleGroup: .shoulders),
                Exercise(name: "Rosca Direta", sets: 2, reps: 12, weight: 8, restSeconds: 60, muscleGroup: .arms),
                Exercise(name: "Tríceps Pulley", sets: 2, reps: 12, weight: 15, restSeconds: 60, muscleGroup: .arms)
            ], level: .beginner, warmup: .upper, abs: .plankCrunch)
        ),
        GuidedWorkoutTemplate(
            id: uuid("g-lvl-beg-upper"),
            title: "Guiado — Iniciante Superiores",
            description: "Peito, costas e ombros com técnica prioritária para quem está começando.",
            level: .beginner,
            focus: nil,
            exercises: withWarmupAndAbs([
                Exercise(name: "Supino Inclinado", sets: 3, reps: 12, weight: 25, restSeconds: 90, muscleGroup: .chest),
                Exercise(name: "Puxada Frontal", sets: 3, reps: 12, weight: 30, restSeconds: 90, muscleGroup: .back),
                Exercise(name: "Elevação Lateral", sets: 3, reps: 15, weight: 6, restSeconds: 60, muscleGroup: .shoulders),
                Exercise(name: "Remada Curvada", sets: 3, reps: 12, weight: 30, restSeconds: 75, muscleGroup: .back),
                Exercise(name: "Flexão de Braços", sets: 3, reps: 10, restSeconds: 60, muscleGroup: .chest),
                Exercise(name: "Rosca Martelo", sets: 2, reps: 12, weight: 8, restSeconds: 60, muscleGroup: .arms)
            ], level: .beginner, warmup: .upper, abs: .crunchBicycle)
        ),
        GuidedWorkoutTemplate(
            id: uuid("g-lvl-int-ab"),
            title: "Guiado — Intermediário Push/Pull",
            description: "Volume intermediário com empurrar e puxar no mesmo ciclo semanal.",
            level: .intermediate,
            focus: nil,
            exercises: withWarmupAndAbs([
                Exercise(name: "Supino Reto", sets: 4, reps: 8, weight: 60, restSeconds: 90, muscleGroup: .chest),
                Exercise(name: "Supino Inclinado", sets: 3, reps: 10, weight: 45, restSeconds: 75, muscleGroup: .chest),
                Exercise(name: "Desenvolvimento Militar", sets: 4, reps: 8, weight: 40, restSeconds: 90, muscleGroup: .shoulders),
                Exercise(name: "Tríceps Testa", sets: 3, reps: 10, weight: 22, restSeconds: 60, muscleGroup: .arms),
                Exercise(name: "Barra Fixa", sets: 4, reps: 8, restSeconds: 90, muscleGroup: .back),
                Exercise(name: "Remada Curvada", sets: 4, reps: 8, weight: 55, restSeconds: 90, muscleGroup: .back),
                Exercise(name: "Rosca Direta", sets: 3, reps: 10, weight: 14, restSeconds: 60, muscleGroup: .arms),
                Exercise(name: "Face Pull", sets: 3, reps: 15, weight: 18, restSeconds: 45, muscleGroup: .back)
            ], level: .intermediate, warmup: .upper, abs: .plankOblique)
        ),
        GuidedWorkoutTemplate(
            id: uuid("g-lvl-int-legs"),
            title: "Guiado — Intermediário Pernas",
            description: "Quadríceps e posteriores com volume clássico de intermediário.",
            level: .intermediate,
            focus: nil,
            exercises: withWarmupAndAbs([
                Exercise(name: "Agachamento Livre", sets: 4, reps: 8, weight: 80, restSeconds: 120, muscleGroup: .legs),
                Exercise(name: "Leg Press 45°", sets: 4, reps: 10, weight: 160, restSeconds: 90, muscleGroup: .legs),
                Exercise(name: "Cadeira Extensora", sets: 3, reps: 12, weight: 40, restSeconds: 60, muscleGroup: .legs),
                Exercise(name: "Mesa Flexora", sets: 3, reps: 12, weight: 35, restSeconds: 60, muscleGroup: .legs),
                Exercise(name: "Stiff", sets: 3, reps: 10, weight: 50, restSeconds: 75, muscleGroup: .legs),
                Exercise(name: "Afundo", sets: 3, reps: 10, weight: 20, restSeconds: 75, muscleGroup: .legs),
                Exercise(name: "Panturrilha em Pé", sets: 4, reps: 15, weight: 80, restSeconds: 45, muscleGroup: .legs)
            ], level: .intermediate, warmup: .lower, abs: .legsBicycle)
        ),
        GuidedWorkoutTemplate(
            id: uuid("g-lvl-adv-power"),
            title: "Guiado — Avançado Força",
            description: "Baixas repetições, cargas altas e descanso longo para força máxima.",
            level: .advanced,
            focus: nil,
            exercises: withWarmupAndAbs([
                Exercise(name: "Agachamento Livre", sets: 5, reps: 5, weight: 110, restSeconds: 180, muscleGroup: .legs),
                Exercise(name: "Supino Reto", sets: 5, reps: 5, weight: 90, restSeconds: 180, muscleGroup: .chest),
                Exercise(name: "Levantamento Terra Romeno", sets: 4, reps: 5, weight: 120, restSeconds: 180, muscleGroup: .back),
                Exercise(name: "Desenvolvimento Militar", sets: 4, reps: 6, weight: 55, restSeconds: 150, muscleGroup: .shoulders),
                Exercise(name: "Barra Fixa", sets: 4, reps: 6, restSeconds: 120, muscleGroup: .back),
                Exercise(name: "Remada Curvada", sets: 4, reps: 6, weight: 80, restSeconds: 120, muscleGroup: .back)
            ], level: .advanced, warmup: .upper, abs: .plankLegs)
        ),
        GuidedWorkoutTemplate(
            id: uuid("g-lvl-adv-hyper"),
            title: "Guiado — Avançado Hipertrofia",
            description: "Alto volume, séries densas e ênfase em pico de contração.",
            level: .advanced,
            focus: nil,
            exercises: withWarmupAndAbs([
                Exercise(name: "Supino Inclinado", sets: 4, reps: 8, weight: 65, restSeconds: 90, muscleGroup: .chest),
                Exercise(name: "Crossover", sets: 4, reps: 12, weight: 14, restSeconds: 60, muscleGroup: .chest),
                Exercise(name: "Puxada Alta", sets: 4, reps: 10, weight: 55, restSeconds: 75, muscleGroup: .back),
                Exercise(name: "Remada Unilateral", sets: 4, reps: 10, weight: 28, restSeconds: 60, muscleGroup: .back),
                Exercise(name: "Hack Squat", sets: 4, reps: 10, weight: 140, restSeconds: 90, muscleGroup: .legs),
                Exercise(name: "Elevação Lateral", sets: 4, reps: 15, weight: 12, restSeconds: 45, muscleGroup: .shoulders),
                Exercise(name: "Rosca Scott", sets: 3, reps: 12, weight: 16, restSeconds: 60, muscleGroup: .arms),
                Exercise(name: "Tríceps Francês", sets: 3, reps: 12, weight: 18, restSeconds: 60, muscleGroup: .arms)
            ], level: .advanced, warmup: .upper, abs: .legsBicycle)
        )
    ]

    private static let focusSeries: [GuidedWorkoutTemplate] = [
        GuidedWorkoutTemplate(
            id: uuid("g-foc-mass-a"),
            title: "Guiado — Massa Peito/Costas",
            description: "Hipertrofia clássica de tronco com volume alto e descanso moderado.",
            level: .intermediate,
            focus: .muscleGain,
            exercises: withWarmupAndAbs([
                Exercise(name: "Supino Reto", sets: 4, reps: 8, weight: 70, restSeconds: 90, muscleGroup: .chest),
                Exercise(name: "Supino Inclinado", sets: 4, reps: 10, weight: 55, restSeconds: 75, muscleGroup: .chest),
                Exercise(name: "Crucifixo Reto", sets: 3, reps: 12, weight: 14, restSeconds: 60, muscleGroup: .chest),
                Exercise(name: "Barra Fixa", sets: 4, reps: 8, restSeconds: 90, muscleGroup: .back),
                Exercise(name: "Remada Curvada", sets: 4, reps: 8, weight: 60, restSeconds: 90, muscleGroup: .back),
                Exercise(name: "Pulldown Triângulo", sets: 3, reps: 12, weight: 45, restSeconds: 60, muscleGroup: .back),
                Exercise(name: "Rosca Direta", sets: 3, reps: 10, weight: 16, restSeconds: 60, muscleGroup: .arms),
                Exercise(name: "Tríceps Pulley", sets: 3, reps: 10, weight: 28, restSeconds: 60, muscleGroup: .arms)
            ], level: .intermediate, warmup: .upper, abs: .plankCrunch)
        ),
        GuidedWorkoutTemplate(
            id: uuid("g-foc-mass-b"),
            title: "Guiado — Massa Pernas/Ombros",
            description: "Volume de membros inferiores e deltoides para ganho de massa.",
            level: .intermediate,
            focus: .muscleGain,
            exercises: withWarmupAndAbs([
                Exercise(name: "Agachamento Livre", sets: 4, reps: 8, weight: 90, restSeconds: 120, muscleGroup: .legs),
                Exercise(name: "Leg Press 45°", sets: 4, reps: 10, weight: 180, restSeconds: 90, muscleGroup: .legs),
                Exercise(name: "Stiff", sets: 3, reps: 10, weight: 60, restSeconds: 75, muscleGroup: .legs),
                Exercise(name: "Desenvolvimento com Halteres", sets: 4, reps: 10, weight: 20, restSeconds: 75, muscleGroup: .shoulders),
                Exercise(name: "Elevação Lateral", sets: 4, reps: 12, weight: 12, restSeconds: 60, muscleGroup: .shoulders),
                Exercise(name: "Arnold Press", sets: 3, reps: 10, weight: 14, restSeconds: 60, muscleGroup: .shoulders),
                Exercise(name: "Panturrilha Sentado", sets: 4, reps: 15, weight: 50, restSeconds: 45, muscleGroup: .legs)
            ], level: .intermediate, warmup: .upper, abs: .legsBicycle)
        ),
        GuidedWorkoutTemplate(
            id: uuid("g-foc-fat-a"),
            title: "Guiado — Emagrecimento Circuito",
            description: "Séries curtas, pouco descanso e estímulo metabólico para perda de gordura.",
            level: .intermediate,
            focus: .fatLoss,
            exercises: withWarmupAndAbs([
                Exercise(name: "Agachamento Livre", sets: 3, reps: 15, weight: 40, restSeconds: 45, muscleGroup: .legs),
                Exercise(name: "Flexão de Braços", sets: 3, reps: 15, restSeconds: 40, muscleGroup: .chest),
                Exercise(name: "Remada Unilateral", sets: 3, reps: 15, weight: 14, restSeconds: 40, muscleGroup: .back),
                Exercise(name: "Afundo", sets: 3, reps: 12, weight: 12, restSeconds: 40, muscleGroup: .legs),
                Exercise(name: "Elevação Lateral", sets: 3, reps: 15, weight: 6, restSeconds: 35, muscleGroup: .shoulders),
                Exercise(name: "Kettlebell Swing", sets: 3, reps: 20, weight: 16, restSeconds: 45, muscleGroup: .fullBody)
            ], level: .intermediate, warmup: .upper, abs: .infraBicycle)
        ),
        GuidedWorkoutTemplate(
            id: uuid("g-foc-fat-b"),
            title: "Guiado — Emagrecimento Full Body",
            description: "Corpo inteiro com densidade alta para maximizar gasto calórico.",
            level: .beginner,
            focus: .fatLoss,
            exercises: withWarmupAndAbs([
                Exercise(name: "Leg Press 45°", sets: 3, reps: 15, weight: 100, restSeconds: 50, muscleGroup: .legs),
                Exercise(name: "Puxada Frontal", sets: 3, reps: 15, weight: 35, restSeconds: 50, muscleGroup: .back),
                Exercise(name: "Supino Inclinado", sets: 3, reps: 15, weight: 30, restSeconds: 50, muscleGroup: .chest),
                Exercise(name: "Desenvolvimento na Máquina", sets: 3, reps: 15, weight: 30, restSeconds: 45, muscleGroup: .shoulders),
                Exercise(name: "Cadeira Extensora", sets: 3, reps: 15, weight: 30, restSeconds: 40, muscleGroup: .legs),
                Exercise(name: "Tríceps Pulley", sets: 3, reps: 15, weight: 18, restSeconds: 40, muscleGroup: .arms)
            ], level: .beginner, warmup: .upper, abs: .plankOblique)
        ),
        GuidedWorkoutTemplate(
            id: uuid("g-foc-legs-a"),
            title: "Guiado — Pernas Volume",
            description: "Ênfase em quadríceps, posteriores, glúteos e panturrilhas.",
            level: .intermediate,
            focus: .legs,
            exercises: withWarmupAndAbs([
                Exercise(name: "Agachamento Livre", sets: 4, reps: 8, weight: 95, restSeconds: 120, muscleGroup: .legs),
                Exercise(name: "Hack Squat", sets: 4, reps: 10, weight: 130, restSeconds: 90, muscleGroup: .legs),
                Exercise(name: "Leg Press 45°", sets: 4, reps: 12, weight: 200, restSeconds: 90, muscleGroup: .legs),
                Exercise(name: "Cadeira Extensora", sets: 3, reps: 15, weight: 45, restSeconds: 60, muscleGroup: .legs),
                Exercise(name: "Mesa Flexora", sets: 4, reps: 12, weight: 40, restSeconds: 60, muscleGroup: .legs),
                Exercise(name: "Stiff", sets: 3, reps: 10, weight: 65, restSeconds: 75, muscleGroup: .legs),
                Exercise(name: "Cadeira Abdutora", sets: 3, reps: 15, weight: 45, restSeconds: 45, muscleGroup: .legs),
                Exercise(name: "Panturrilha em Pé", sets: 4, reps: 15, weight: 90, restSeconds: 45, muscleGroup: .legs)
            ], level: .intermediate, warmup: .lower, abs: .plankLegs)
        ),
        GuidedWorkoutTemplate(
            id: uuid("g-foc-legs-b"),
            title: "Guiado — Pernas e Posterior",
            description: "Cadeia posterior e unilateral para equilíbrio e potência de pernas.",
            level: .advanced,
            focus: .legs,
            exercises: withWarmupAndAbs([
                Exercise(name: "Levantamento Terra Romeno", sets: 4, reps: 6, weight: 110, restSeconds: 150, muscleGroup: .back),
                Exercise(name: "Agachamento Livre", sets: 4, reps: 6, weight: 105, restSeconds: 150, muscleGroup: .legs),
                Exercise(name: "Afundo", sets: 3, reps: 10, weight: 24, restSeconds: 75, muscleGroup: .legs),
                Exercise(name: "Mesa Flexora", sets: 4, reps: 10, weight: 45, restSeconds: 60, muscleGroup: .legs),
                Exercise(name: "Cadeira Adutora", sets: 3, reps: 15, weight: 50, restSeconds: 45, muscleGroup: .legs),
                Exercise(name: "Panturrilha Sentado", sets: 4, reps: 20, weight: 55, restSeconds: 40, muscleGroup: .legs)
            ], level: .advanced, warmup: .lower, abs: .infraBicycle)
        ),
        GuidedWorkoutTemplate(
            id: uuid("g-foc-comp-a"),
            title: "Guiado — Competição Potência",
            description: "Força explosiva e compostos pesados orientados a performance.",
            level: .advanced,
            focus: .competition,
            exercises: withWarmupAndAbs([
                Exercise(name: "Agachamento Livre", sets: 5, reps: 3, weight: 120, restSeconds: 180, muscleGroup: .legs),
                Exercise(name: "Supino Reto", sets: 5, reps: 3, weight: 95, restSeconds: 180, muscleGroup: .chest),
                Exercise(name: "Levantamento Terra Romeno", sets: 4, reps: 3, weight: 130, restSeconds: 180, muscleGroup: .back),
                Exercise(name: "Desenvolvimento Militar", sets: 4, reps: 5, weight: 50, restSeconds: 150, muscleGroup: .shoulders),
                Exercise(name: "Barra Fixa", sets: 4, reps: 5, restSeconds: 120, muscleGroup: .back)
            ], level: .advanced, warmup: .upper, abs: .plankCrunch)
        ),
        GuidedWorkoutTemplate(
            id: uuid("g-foc-comp-b"),
            title: "Guiado — Competição Atleta",
            description: "Mistura de força, estabilidade e condicionamento para competir.",
            level: .advanced,
            focus: .competition,
            exercises: withWarmupAndAbs([
                Exercise(name: "Agachamento Livre", sets: 4, reps: 5, weight: 100, restSeconds: 150, muscleGroup: .legs),
                Exercise(name: "Supino Inclinado", sets: 4, reps: 6, weight: 70, restSeconds: 120, muscleGroup: .chest),
                Exercise(name: "Remada Curvada", sets: 4, reps: 6, weight: 75, restSeconds: 120, muscleGroup: .back),
                Exercise(name: "Desenvolvimento com Halteres", sets: 3, reps: 8, weight: 22, restSeconds: 90, muscleGroup: .shoulders),
                Exercise(name: "Afundo", sets: 3, reps: 8, weight: 28, restSeconds: 75, muscleGroup: .legs),
                Exercise(name: "Face Pull", sets: 3, reps: 15, weight: 20, restSeconds: 45, muscleGroup: .back)
            ], level: .advanced, warmup: .upper, abs: .legsBicycle)
        ),
        GuidedWorkoutTemplate(
            id: uuid("g-foc-arms-a"),
            title: "Guiado — Braços Pump",
            description: "Bíceps e tríceps com alto volume e descanso curto.",
            level: .intermediate,
            focus: .arms,
            exercises: withWarmupAndAbs([
                Exercise(name: "Rosca Direta", sets: 4, reps: 10, weight: 16, restSeconds: 60, muscleGroup: .arms),
                Exercise(name: "Rosca Martelo", sets: 3, reps: 12, weight: 14, restSeconds: 45, muscleGroup: .arms),
                Exercise(name: "Rosca Scott", sets: 3, reps: 12, weight: 12, restSeconds: 45, muscleGroup: .arms),
                Exercise(name: "Rosca Concentrada", sets: 3, reps: 12, weight: 10, restSeconds: 45, muscleGroup: .arms),
                Exercise(name: "Tríceps Pulley", sets: 4, reps: 12, weight: 28, restSeconds: 45, muscleGroup: .arms),
                Exercise(name: "Tríceps Testa", sets: 3, reps: 10, weight: 24, restSeconds: 60, muscleGroup: .arms),
                Exercise(name: "Tríceps Francês", sets: 3, reps: 12, weight: 16, restSeconds: 45, muscleGroup: .arms),
                Exercise(name: "Mergulho no Banco", sets: 3, reps: 12, restSeconds: 60, muscleGroup: .arms)
            ], level: .intermediate, warmup: .upper, abs: .plankOblique)
        ),
        GuidedWorkoutTemplate(
            id: uuid("g-foc-arms-b"),
            title: "Guiado — Braços e Ombros",
            description: "Braços com suporte de deltoides para silhueta e volume.",
            level: .intermediate,
            focus: .arms,
            exercises: withWarmupAndAbs([
                Exercise(name: "Desenvolvimento com Halteres", sets: 3, reps: 10, weight: 18, restSeconds: 75, muscleGroup: .shoulders),
                Exercise(name: "Elevação Lateral", sets: 4, reps: 15, weight: 10, restSeconds: 45, muscleGroup: .shoulders),
                Exercise(name: "Rosca Direta", sets: 4, reps: 10, weight: 14, restSeconds: 60, muscleGroup: .arms),
                Exercise(name: "Rosca Martelo", sets: 3, reps: 12, weight: 12, restSeconds: 45, muscleGroup: .arms),
                Exercise(name: "Tríceps Pulley", sets: 4, reps: 12, weight: 25, restSeconds: 45, muscleGroup: .arms),
                Exercise(name: "Mergulho no Banco", sets: 3, reps: 12, restSeconds: 60, muscleGroup: .arms),
                Exercise(name: "Elevação Frontal", sets: 3, reps: 12, weight: 10, restSeconds: 45, muscleGroup: .shoulders)
            ], level: .intermediate, warmup: .upper, abs: .crunchBicycle)
        ),
        GuidedWorkoutTemplate(
            id: uuid("g-foc-back-a"),
            title: "Guiado — Costas Largura",
            description: "Puxadas e verticais para largura dorsal e postura.",
            level: .intermediate,
            focus: .back,
            exercises: withWarmupAndAbs([
                Exercise(name: "Barra Fixa", sets: 4, reps: 8, restSeconds: 90, muscleGroup: .back),
                Exercise(name: "Puxada Frontal", sets: 4, reps: 10, weight: 50, restSeconds: 75, muscleGroup: .back),
                Exercise(name: "Puxada Alta", sets: 3, reps: 12, weight: 45, restSeconds: 60, muscleGroup: .back),
                Exercise(name: "Pulldown Triângulo", sets: 3, reps: 12, weight: 45, restSeconds: 60, muscleGroup: .back),
                Exercise(name: "Face Pull", sets: 3, reps: 15, weight: 18, restSeconds: 45, muscleGroup: .back),
                Exercise(name: "Crucifixo Inverso", sets: 3, reps: 12, weight: 10, restSeconds: 45, muscleGroup: .shoulders),
                Exercise(name: "Encolhimento com Halteres", sets: 3, reps: 15, weight: 24, restSeconds: 60, muscleGroup: .back)
            ], level: .intermediate, warmup: .upper, abs: .plankCrunch)
        ),
        GuidedWorkoutTemplate(
            id: uuid("g-foc-back-b"),
            title: "Guiado — Costas Espessura",
            description: "Remadas e horizontais para densidade e força de puxada.",
            level: .advanced,
            focus: .back,
            exercises: withWarmupAndAbs([
                Exercise(name: "Remada Curvada", sets: 4, reps: 6, weight: 75, restSeconds: 120, muscleGroup: .back),
                Exercise(name: "Remada Unilateral", sets: 4, reps: 8, weight: 30, restSeconds: 75, muscleGroup: .back),
                Exercise(name: "Levantamento Terra Romeno", sets: 4, reps: 6, weight: 100, restSeconds: 120, muscleGroup: .back),
                Exercise(name: "Puxada Frontal", sets: 3, reps: 10, weight: 55, restSeconds: 75, muscleGroup: .back),
                Exercise(name: "Remada Alta", sets: 3, reps: 10, weight: 35, restSeconds: 60, muscleGroup: .shoulders),
                Exercise(name: "Encolhimento com Barra", sets: 4, reps: 12, weight: 70, restSeconds: 60, muscleGroup: .back),
                Exercise(name: "Face Pull", sets: 3, reps: 15, weight: 20, restSeconds: 45, muscleGroup: .back)
            ], level: .advanced, warmup: .upper, abs: .plankLegs)
        )
    ]

    /// UUID estável a partir de uma chave curta (determinístico o bastante para o catálogo).
    private static func uuid(_ key: String) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        let data = Array(key.utf8)
        for (index, byte) in data.enumerated() {
            bytes[index % 16] ^= byte &+ UInt8(index)
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
