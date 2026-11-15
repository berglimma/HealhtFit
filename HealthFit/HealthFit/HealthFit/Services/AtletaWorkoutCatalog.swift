import Foundation

/// **Método Atleta** — musculação PPL 2× (Push / Pull / Legs × 2) para masculino e feminino.
/// Estrutura: Push 1 · Pull 1 · Legs 1 · Push 2 · Pull 2 · Legs 2 (dias da semana são só referência).
/// Exercícios originais HealthFit com demos em GIF na ficha e no treino ativo.
enum AtletaWorkoutCatalog {
    private static let nearFailure = "Próximo da falha"
    private static let athleteCadence = "Cadência controlada · amplitude completa"
    private static let methodNote =
        "Método Atleta · divisão PPL 2× (Push / Pull / Legs)"

    // MARK: - Public API

    static var allMaleSheets: [WorkoutSheet] { maleSheets }
    static var allFemaleSheets: [WorkoutSheet] { femaleSheets }

    static var allTitles: Set<String> {
        Set((allMaleSheets + allFemaleSheets).map(\.title))
    }

    static func sheets(for gender: Gender) -> [WorkoutSheet] {
        gender == .female ? allFemaleSheets : allMaleSheets
    }

    // MARK: - Masculino — 6 fichas PPL 2×

    private static let maleSheets: [WorkoutSheet] = [
        sheet(
            title: "Atleta Masculino A — Push 1 (Peitoral)",
            description: "\(methodNote). Empurrar com foco inicial em peitoral, ombro lateral/anterior e dois exercícios de tríceps.",
            gender: .male,
            stretch: .upper,
            exercises: [
                ex("Supino Inclinado com Halteres", sets: 4, reps: 10, notes: athleteCadence, group: .chest),
                ex("Supino Reto", sets: 3, reps: 8, group: .chest),
                ex("Crossover", sets: 3, reps: 12, notes: nearFailure, group: .chest),
                ex("Elevação Lateral com Halteres", sets: 4, reps: 12, group: .shoulders),
                ex("Desenvolvimento com Halteres", sets: 3, reps: 10, group: .shoulders),
                ex("Tríceps Corda", sets: 3, reps: 12, group: .arms),
                ex("Tríceps Pulley Barra W", sets: 3, reps: 12, notes: nearFailure, group: .arms),
            ]
        ),
        sheet(
            title: "Atleta Masculino B — Pull 1 (Largura)",
            description: "\(methodNote). Puxar com foco em puxadas (largura), posterior de ombro, trapézio e bíceps.",
            gender: .male,
            stretch: .upper,
            exercises: [
                ex("Puxada Alta Frente", sets: 4, reps: 10, notes: athleteCadence, group: .back),
                ex("Puxada Aberta", sets: 3, reps: 10, group: .back),
                ex("Remada Unilateral", sets: 3, reps: 10, group: .back),
                ex("Crucifixo Inverso Máquina", sets: 3, reps: 12, group: .shoulders),
                ex("Encolhimento com Halteres", sets: 3, reps: 12, group: .shoulders),
                ex("Rosca Direta Barra W", sets: 3, reps: 10, group: .arms),
                ex("Rosca Direta Corda (Martelo)", sets: 3, reps: 12, notes: nearFailure, group: .arms),
            ]
        ),
        sheet(
            title: "Atleta Masculino C — Legs 1 (Quadríceps)",
            description: "\(methodNote). Perna completa com ênfase em quadríceps.",
            gender: .male,
            stretch: .lower,
            exercises: [
                ex("Agachamento Livre", sets: 4, reps: 8, notes: athleteCadence, group: .legs),
                ex("Leg Press 45", sets: 4, reps: 10, group: .legs),
                ex("Hack Squat", sets: 3, reps: 10, group: .legs),
                ex("Cadeira Extensora", sets: 3, reps: 12, notes: nearFailure, group: .legs),
                ex("Mesa Flexora", sets: 3, reps: 10, group: .legs),
                ex("Gêmeos em Pé", sets: 4, reps: 15, group: .legs),
                ex("Abdominal Reto", sets: 3, reps: 15, group: .core),
            ]
        ),
        sheet(
            title: "Atleta Masculino D — Push 2 (Ombros)",
            description: "\(methodNote). Empurrar priorizando ombro no início, depois peitoral e tríceps.",
            gender: .male,
            stretch: .upper,
            exercises: [
                ex("Desenvolvimento Militar", sets: 4, reps: 8, notes: athleteCadence, group: .shoulders),
                ex("Elevação Lateral com Halteres", sets: 4, reps: 12, group: .shoulders),
                ex("Elevação Frontal com Halteres", sets: 3, reps: 12, group: .shoulders),
                ex("Supino Inclinado com Halteres", sets: 3, reps: 10, group: .chest),
                ex("Crucifixo Inclinado com Halteres", sets: 3, reps: 12, group: .chest),
                ex("Tríceps Testa Barra W", sets: 3, reps: 10, group: .arms),
                ex("Tríceps Corda", sets: 3, reps: 12, notes: nearFailure, group: .arms),
            ]
        ),
        sheet(
            title: "Atleta Masculino E — Pull 2 (Espessura)",
            description: "\(methodNote). Puxar com foco em remadas (espessura), posterior, trapézio e bíceps.",
            gender: .male,
            stretch: .upper,
            exercises: [
                ex("Remada Curvada Pronada", sets: 4, reps: 8, notes: athleteCadence, group: .back),
                ex("Remada Baixa", sets: 3, reps: 10, group: .back),
                ex("Remada Curvada com Halteres", sets: 3, reps: 10, group: .back),
                ex("Crucifixo Inverso Máquina", sets: 3, reps: 12, group: .shoulders),
                ex("Encolhimento com Barra", sets: 3, reps: 12, group: .shoulders),
                ex("Rosca Scott", sets: 3, reps: 10, group: .arms),
                ex("Rosca Martelo em Pé Alternado", sets: 3, reps: 12, notes: nearFailure, group: .arms),
            ]
        ),
        sheet(
            title: "Atleta Masculino F — Legs 2 (Posterior)",
            description: "\(methodNote). Perna completa com ênfase em glúteos e posteriores.",
            gender: .male,
            stretch: .lower,
            exercises: [
                ex("Stiff", sets: 4, reps: 8, notes: athleteCadence, group: .legs),
                ex("Levantamento Terra Romeno", sets: 3, reps: 8, group: .legs),
                ex("Mesa Flexora", sets: 3, reps: 10, group: .legs),
                ex("Cadeira Flexora", sets: 3, reps: 12, notes: nearFailure, group: .legs),
                ex("Elevação Pélvica", sets: 3, reps: 12, group: .legs),
                ex("Agachamento Livre", sets: 3, reps: 10, notes: "Volume moderado", group: .legs),
                ex("Gêmeos Sentado", sets: 4, reps: 15, group: .legs),
            ]
        ),
    ]

    // MARK: - Feminino — 6 fichas PPL 2× (mesma divisão, ênfase em glúteo/pernas)

    private static let femaleSheets: [WorkoutSheet] = [
        sheet(
            title: "Atleta Feminino A — Push 1 (Peitoral)",
            description: "\(methodNote). Empurrar com foco em peitoral, ombro lateral/anterior e dois tríceps.",
            gender: .female,
            stretch: .upper,
            exercises: [
                ex("Supino Inclinado com Halteres", sets: 3, reps: 12, notes: athleteCadence, group: .chest),
                ex("Crucifixo Inclinado com Halteres", sets: 3, reps: 12, group: .chest),
                ex("Crossover", sets: 3, reps: 12, notes: nearFailure, group: .chest),
                ex("Elevação Lateral com Halteres", sets: 4, reps: 12, group: .shoulders),
                ex("Desenvolvimento com Halteres", sets: 3, reps: 10, group: .shoulders),
                ex("Tríceps Corda", sets: 3, reps: 12, group: .arms),
                ex("Tríceps Pulley Barra W", sets: 3, reps: 12, notes: nearFailure, group: .arms),
            ]
        ),
        sheet(
            title: "Atleta Feminino B — Pull 1 (Largura)",
            description: "\(methodNote). Puxar com puxadas para largura, posterior de ombro, trapézio e bíceps.",
            gender: .female,
            stretch: .upper,
            exercises: [
                ex("Puxada Alta Frente", sets: 4, reps: 12, notes: athleteCadence, group: .back),
                ex("Puxada Aberta", sets: 3, reps: 12, group: .back),
                ex("Remada Unilateral", sets: 3, reps: 10, group: .back),
                ex("Crucifixo Inverso Máquina", sets: 3, reps: 12, group: .shoulders),
                ex("Encolhimento com Halteres", sets: 3, reps: 12, group: .shoulders),
                ex("Rosca Direta Barra W", sets: 3, reps: 12, group: .arms),
                ex("Rosca Direta Corda (Martelo)", sets: 3, reps: 12, notes: nearFailure, group: .arms),
            ]
        ),
        sheet(
            title: "Atleta Feminino C — Legs 1 (Quadríceps)",
            description: "\(methodNote). Perna completa com ênfase em quadríceps e glúteo.",
            gender: .female,
            stretch: .lower,
            exercises: [
                ex("Agachamento Livre", sets: 4, reps: 10, notes: athleteCadence, group: .legs),
                ex("Leg Press 45", sets: 4, reps: 12, group: .legs),
                ex("Cadeira Extensora", sets: 3, reps: 12, notes: nearFailure, group: .legs),
                ex("Afundo", sets: 3, reps: 12, group: .legs),
                ex("Cadeira Flexora", sets: 3, reps: 12, group: .legs),
                ex("Elevação Pélvica", sets: 3, reps: 12, group: .legs),
                ex("Gêmeos em Pé", sets: 3, reps: 15, group: .legs),
            ]
        ),
        sheet(
            title: "Atleta Feminino D — Push 2 (Ombros)",
            description: "\(methodNote). Empurrar priorizando ombro, depois peitoral e tríceps.",
            gender: .female,
            stretch: .upper,
            exercises: [
                ex("Desenvolvimento Militar", sets: 3, reps: 10, notes: athleteCadence, group: .shoulders),
                ex("Elevação Lateral com Halteres", sets: 4, reps: 12, group: .shoulders),
                ex("Elevação Frontal com Halteres", sets: 3, reps: 12, group: .shoulders),
                ex("Supino Inclinado com Halteres", sets: 3, reps: 12, group: .chest),
                ex("Crucifixo Inclinado com Halteres", sets: 3, reps: 12, group: .chest),
                ex("Tríceps Testa Barra W", sets: 3, reps: 12, group: .arms),
                ex("Tríceps Corda", sets: 3, reps: 12, notes: nearFailure, group: .arms),
            ]
        ),
        sheet(
            title: "Atleta Feminino E — Pull 2 (Espessura)",
            description: "\(methodNote). Puxar com remadas para espessura, posterior, trapézio e bíceps.",
            gender: .female,
            stretch: .upper,
            exercises: [
                ex("Remada Baixa Pronada", sets: 4, reps: 10, notes: athleteCadence, group: .back),
                ex("Remada Curvada com Halteres", sets: 3, reps: 10, group: .back),
                ex("Remada Unilateral", sets: 3, reps: 10, group: .back),
                ex("Crucifixo Inverso Máquina", sets: 3, reps: 12, group: .shoulders),
                ex("Encolhimento com Halteres", sets: 3, reps: 12, group: .shoulders),
                ex("Rosca Scott", sets: 3, reps: 12, group: .arms),
                ex("Rosca Martelo Corda", sets: 3, reps: 12, notes: nearFailure, group: .arms),
            ]
        ),
        sheet(
            title: "Atleta Feminino F — Legs 2 (Glúteo e Posterior)",
            description: "\(methodNote). Perna completa com ênfase em glúteos e posteriores.",
            gender: .female,
            stretch: .lower,
            exercises: [
                ex("Elevação Pélvica", sets: 4, reps: 12, notes: athleteCadence, group: .legs),
                ex("Stiff", sets: 4, reps: 10, group: .legs),
                ex("Cadeira Flexora", sets: 3, reps: 12, group: .legs),
                ex("Sumô com Halteres", sets: 3, reps: 12, group: .legs),
                ex("Cadeira Abdutora", sets: 3, reps: 15, notes: nearFailure, group: .legs),
                ex("Abdução Lateral Polia Baixa", sets: 3, reps: 12, group: .legs),
                ex("Gêmeos em Pé", sets: 3, reps: 15, group: .legs),
            ]
        ),
    ]

    // MARK: - Helpers

    private static func sheet(
        title: String,
        description: String,
        gender: Gender,
        stretch: GuidedWorkoutCatalog.WarmupStyle,
        exercises: [Exercise]
    ) -> WorkoutSheet {
        let stretches = GuidedWorkoutCatalog.stretchBlock(style: stretch, level: .intermediate)
        return WorkoutSheet(
            title: title,
            description: description,
            exercises: stretches + exercises,
            targetGender: gender
        )
    }

    private static func ex(
        _ name: String,
        sets: Int,
        reps: Int = 12,
        restSeconds: Int = 60,
        notes: String = nearFailure,
        group: MuscleGroup
    ) -> Exercise {
        Exercise(
            name: name,
            sets: sets,
            reps: reps,
            restSeconds: restSeconds,
            notes: notes,
            muscleGroup: group
        )
    }
}
