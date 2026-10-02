import Foundation

/// **Método Militar** — fichas masculino e feminino inspiradas na estrutura pública
/// do estilo Tenente Breno (Projeto Selva): Push · Pull · Inferiores · Condicionamento,
/// com progressão Soldado (Nível 1) → Cabo (Nível 2).
/// Exercícios e volumes são originais do HealthFit (não copiam PDF proprietário).
enum MilitarWorkoutCatalog {
    private static let nearFailure = "Próximo da falha"
    private static let warmupLight = "Aquecimento (peso leve)"
    private static let militaryCadence = "Cadência controlada · sem balanço"
    private static let finisherNote = "Finalizador · mantenha ritmo firme"
    private static let methodNote =
        "Método Militar · estrutura Push / Pull / Inferiores + condicionamento (estilo Projeto Selva)"

    // MARK: - Public API

    static var allMaleSheets: [WorkoutSheet] { maleLevel1 + maleLevel2 }
    static var allFemaleSheets: [WorkoutSheet] { femaleLevel1 + femaleLevel2 }

    static var allTitles: Set<String> {
        Set((allMaleSheets + allFemaleSheets).map(\.title))
    }

    static func sheets(for gender: Gender) -> [WorkoutSheet] {
        gender == .female ? allFemaleSheets : allMaleSheets
    }

    // MARK: - Feminino Soldado (Nível 1) — 4 fichas

    private static let femaleLevel1: [WorkoutSheet] = [
        sheet(
            title: "Militar Feminino A — Peito Ombros Tríceps (Soldado)",
            description: "\(methodNote). Push superior · base Soldado.",
            gender: .female,
            exercises: [
                ex("Elevação Lateral com Halteres", sets: 2, reps: 12, notes: warmupLight, group: .shoulders),
                ex("Supino Inclinado com Halteres", sets: 3, notes: militaryCadence, group: .chest),
                ex("Crucifixo Inclinado com Halteres", sets: 3, group: .chest),
                ex("Desenvolvimento com Halteres", sets: 3, group: .shoulders),
                ex("Elevação Lateral com Halteres", sets: 3, group: .shoulders),
                ex("Tríceps Corda", sets: 3, group: .arms),
                ex("Tríceps Pulley Barra W", sets: 2, group: .arms),
                ex("Prancha", sets: 2, reps: 30, notes: "Isometria 20–30 s", group: .core),
            ]
        ),
        sheet(
            title: "Militar Feminino B — Costas Posterior Bíceps (Soldado)",
            description: "\(methodNote). Pull · dorsal e deltoide posterior.",
            gender: .female,
            exercises: [
                ex("Rotação Externa Polia Unilateral", sets: 2, reps: 12, notes: warmupLight, group: .shoulders),
                ex("Puxada Alta Frente", sets: 3, notes: militaryCadence, group: .back),
                ex("Remada Baixa Pronada", sets: 3, group: .back),
                ex("Remada Unilateral", sets: 3, group: .back),
                ex("Crucifixo Inverso Máquina", sets: 3, group: .shoulders),
                ex("Rosca Direta Barra W", sets: 3, group: .arms),
                ex("Rosca Direta Corda (Martelo)", sets: 2, group: .arms),
                ex("Abdominal Reto", sets: 3, group: .core),
            ]
        ),
        sheet(
            title: "Militar Feminino C — Inferiores e Glúteo (Soldado)",
            description: "\(methodNote). Pernas + glúteo · base Soldado.",
            gender: .female,
            exercises: [
                ex("Agachamento Corporal", sets: 1, reps: 15, notes: "Aquecimento", group: .legs),
                ex("Agachamento Livre", sets: 3, notes: militaryCadence, group: .legs),
                ex("Leg Press 45", sets: 3, group: .legs),
                ex("Cadeira Extensora", sets: 3, group: .legs),
                ex("Cadeira Flexora", sets: 3, group: .legs),
                ex("Elevação Pélvica", sets: 3, notes: nearFailure, group: .legs),
                ex("Cadeira Abdutora", sets: 3, group: .legs),
                ex("Gêmeos em Pé", sets: 3, group: .legs),
            ]
        ),
        sheet(
            title: "Militar Feminino D — Condicionamento AEJ (Soldado)",
            description: "\(methodNote). Condicionamento estilo AEJ + core.",
            gender: .female,
            exercises: [
                ex("Polichinelo", sets: 3, reps: 30, notes: finisherNote, group: .fullBody),
                ex("Agachamento Livre", sets: 3, reps: 15, notes: "Peso leve · ritmo", group: .legs),
                ex("Flexão de Braços", sets: 3, reps: 10, notes: "Joelhos se precisar", group: .chest),
                ex("Afundo", sets: 3, reps: 12, group: .legs),
                ex("Mountain Climber", sets: 3, reps: 20, notes: finisherNote, group: .fullBody),
                ex("Prancha", sets: 3, reps: 35, notes: "Isometria", group: .core),
                ex("Abdominal Infra", sets: 3, group: .core),
                ex("Burpee", sets: 2, reps: 8, notes: finisherNote, group: .fullBody),
            ]
        ),
    ]

    // MARK: - Feminino Cabo (Nível 2) — 5 fichas

    private static let femaleLevel2: [WorkoutSheet] = [
        sheet(
            title: "Militar Feminino E — Peito Ombros Tríceps (Cabo)",
            description: "\(methodNote). Push avançado · patente Cabo.",
            gender: .female,
            exercises: [
                ex("Elevação Lateral", sets: 2, reps: 12, notes: warmupLight, group: .shoulders),
                ex("Supino Inclinado com Halteres", sets: 4, notes: militaryCadence, group: .chest),
                ex("Crucifixo Inclinado com Halteres", sets: 3, notes: nearFailure, group: .chest),
                ex("Crossover", sets: 3, group: .chest),
                ex("Desenvolvimento Militar", sets: 3, group: .shoulders),
                ex("Elevação Lateral com Halteres", sets: 4, group: .shoulders),
                ex("Tríceps Corda", sets: 3, notes: "Drop set na última", group: .arms),
                ex("Tríceps Testa Barra W", sets: 3, group: .arms),
            ]
        ),
        sheet(
            title: "Militar Feminino F — Costas Posterior Bíceps (Cabo)",
            description: "\(methodNote). Pull denso · Cabo.",
            gender: .female,
            exercises: [
                ex("Rotação Externa Polia Unilateral", sets: 2, reps: 12, notes: warmupLight, group: .shoulders),
                ex("Puxada Alta Frente", sets: 4, notes: militaryCadence, group: .back),
                ex("Remada Curvada com Halteres", sets: 3, group: .back),
                ex("Remada Baixa", sets: 3, group: .back),
                ex("Remada Unilateral", sets: 3, group: .back),
                ex("Crucifixo Inverso Máquina", sets: 3, group: .shoulders),
                ex("Rosca Direta Barra W", sets: 3, group: .arms),
                ex("Rosca Martelo Corda", sets: 3, group: .arms),
            ]
        ),
        sheet(
            title: "Militar Feminino G — Inferiores Força (Cabo)",
            description: "\(methodNote). Quadríceps e força · Cabo.",
            gender: .female,
            exercises: [
                ex("Agachamento Búlgaro", sets: 2, reps: 10, notes: warmupLight, group: .legs),
                ex("Agachamento Livre", sets: 4, notes: militaryCadence, group: .legs),
                ex("Hack Squat", sets: 3, group: .legs),
                ex("Leg Press", sets: 4, group: .legs),
                ex("Cadeira Extensora", sets: 3, notes: nearFailure, group: .legs),
                ex("Gêmeos em Pé", sets: 4, group: .legs),
                ex("Abdominal Reto", sets: 3, group: .core),
            ]
        ),
        sheet(
            title: "Militar Feminino H — Posterior e Glúteo (Cabo)",
            description: "\(methodNote). Posterior + glúteo · Cabo.",
            gender: .female,
            exercises: [
                ex("Stiff", sets: 4, notes: militaryCadence, group: .legs),
                ex("Mesa Flexora", sets: 3, group: .legs),
                ex("Cadeira Flexora", sets: 3, group: .legs),
                ex("Elevação Pélvica", sets: 4, notes: nearFailure, group: .legs),
                ex("Sumô com Halteres", sets: 3, group: .legs),
                ex("Cadeira Abdutora", sets: 3, group: .legs),
                ex("Abdução Lateral Polia Baixa", sets: 3, group: .legs),
                ex("Gêmeos em Pé", sets: 3, group: .legs),
            ]
        ),
        sheet(
            title: "Militar Feminino I — Condicionamento Missão (Cabo)",
            description: "\(methodNote). Missão de condicionamento + core.",
            gender: .female,
            exercises: [
                ex("Burpee", sets: 3, reps: 10, notes: finisherNote, group: .fullBody),
                ex("Mountain Climber", sets: 3, reps: 24, group: .fullBody),
                ex("Afundo", sets: 3, reps: 14, group: .legs),
                ex("Flexão de Braços", sets: 3, reps: 12, group: .chest),
                ex("Polichinelo", sets: 3, reps: 40, notes: finisherNote, group: .fullBody),
                ex("Prancha", sets: 3, reps: 40, notes: "Isometria", group: .core),
                ex("Abdominal Infra", sets: 3, group: .core),
                ex("Abdômen Corda", sets: 3, group: .core),
            ]
        ),
    ]

    // MARK: - Masculino Soldado (Nível 1) — 4 fichas

    private static let maleLevel1: [WorkoutSheet] = [
        sheet(
            title: "Militar Masculino A — Peito Ombros Tríceps (Soldado)",
            description: "\(methodNote). Push clássico · base Soldado.",
            gender: .male,
            exercises: [
                ex("Elevação Lateral com Halteres", sets: 2, reps: 12, notes: warmupLight, group: .shoulders),
                ex("Supino Inclinado com Halteres", sets: 3, notes: militaryCadence, group: .chest),
                ex("Supino Reto", sets: 3, group: .chest),
                ex("Desenvolvimento Militar", sets: 3, group: .shoulders),
                ex("Elevação Lateral com Halteres", sets: 3, group: .shoulders),
                ex("Tríceps Corda", sets: 3, group: .arms),
                ex("Tríceps Pulley Barra W", sets: 3, group: .arms),
                ex("Prancha", sets: 2, reps: 35, notes: "Isometria", group: .core),
            ]
        ),
        sheet(
            title: "Militar Masculino B — Costas Posterior Bíceps (Soldado)",
            description: "\(methodNote). Pull · dorsal e bíceps.",
            gender: .male,
            exercises: [
                ex("Rotação Externa Polia Unilateral", sets: 2, reps: 12, notes: warmupLight, group: .shoulders),
                ex("Puxada Alta Frente", sets: 3, notes: militaryCadence, group: .back),
                ex("Remada Curvada Pronada", sets: 3, group: .back),
                ex("Remada Unilateral", sets: 3, group: .back),
                ex("Crucifixo Inverso Máquina", sets: 3, group: .shoulders),
                ex("Rosca Direta Barra W", sets: 3, group: .arms),
                ex("Rosca Direta Corda (Martelo)", sets: 3, group: .arms),
                ex("Abdominal Reto", sets: 3, group: .core),
            ]
        ),
        sheet(
            title: "Militar Masculino C — Inferiores (Soldado)",
            description: "\(methodNote). Pernas completas · base Soldado.",
            gender: .male,
            exercises: [
                ex("Agachamento Corporal", sets: 1, reps: 15, notes: "Aquecimento", group: .legs),
                ex("Agachamento Livre", sets: 3, notes: militaryCadence, group: .legs),
                ex("Leg Press 45", sets: 3, group: .legs),
                ex("Cadeira Extensora", sets: 3, group: .legs),
                ex("Mesa Flexora", sets: 3, group: .legs),
                ex("Stiff", sets: 3, group: .legs),
                ex("Gêmeos em Pé", sets: 3, group: .legs),
                ex("Abdominal Infra", sets: 3, group: .core),
            ]
        ),
        sheet(
            title: "Militar Masculino D — Condicionamento AEJ (Soldado)",
            description: "\(methodNote). Condicionamento estilo AEJ + core.",
            gender: .male,
            exercises: [
                ex("Polichinelo", sets: 3, reps: 40, notes: finisherNote, group: .fullBody),
                ex("Burpee", sets: 3, reps: 10, notes: finisherNote, group: .fullBody),
                ex("Flexão de Braços", sets: 3, reps: 15, group: .chest),
                ex("Agachamento Livre", sets: 3, reps: 15, notes: "Peso leve · ritmo", group: .legs),
                ex("Mountain Climber", sets: 3, reps: 24, group: .fullBody),
                ex("Prancha", sets: 3, reps: 40, notes: "Isometria", group: .core),
                ex("Abdominal Reto", sets: 3, group: .core),
                ex("Afundo", sets: 2, reps: 12, group: .legs),
            ]
        ),
    ]

    // MARK: - Masculino Cabo (Nível 2) — 5 fichas

    private static let maleLevel2: [WorkoutSheet] = [
        sheet(
            title: "Militar Masculino E — Peito Ombros Tríceps (Cabo)",
            description: "\(methodNote). Push intenso · patente Cabo.",
            gender: .male,
            exercises: [
                ex("Rotação Externa Polia Unilateral", sets: 2, reps: 12, notes: warmupLight, group: .shoulders),
                ex("Supino Inclinado com Halteres", sets: 4, notes: militaryCadence, group: .chest),
                ex("Crucifixo Inclinado com Halteres", sets: 3, notes: nearFailure, group: .chest),
                ex("Voador", sets: 3, group: .chest),
                ex("Crossover", sets: 3, group: .chest),
                ex("Desenvolvimento Militar", sets: 4, group: .shoulders),
                ex("Elevação Lateral com Halteres", sets: 4, group: .shoulders),
                ex("Tríceps Corda", sets: 4, notes: "Drop set na última", group: .arms),
            ]
        ),
        sheet(
            title: "Militar Masculino F — Costas Posterior Bíceps (Cabo)",
            description: "\(methodNote). Pull denso · Cabo.",
            gender: .male,
            exercises: [
                ex("Rotação Externa Polia Unilateral", sets: 2, reps: 12, notes: warmupLight, group: .shoulders),
                ex("Puxada Alta Frente", sets: 4, notes: militaryCadence, group: .back),
                ex("Remada Curvada Pronada", sets: 4, group: .back),
                ex("Remada Unilateral", sets: 3, group: .back),
                ex("Remada Baixa Pronada", sets: 3, group: .back),
                ex("Crucifixo Inverso Máquina", sets: 3, group: .shoulders),
                ex("Rosca Direta Barra W", sets: 3, group: .arms),
                ex("Rosca com Halteres Banco Inclinado", sets: 3, group: .arms),
            ]
        ),
        sheet(
            title: "Militar Masculino G — Inferiores Força (Cabo)",
            description: "\(methodNote). Força de pernas · Cabo.",
            gender: .male,
            exercises: [
                ex("Agachamento Corporal", sets: 1, reps: 15, notes: "Aquecimento", group: .legs),
                ex("Agachamento Livre", sets: 4, notes: militaryCadence, group: .legs),
                ex("Hack Squat", sets: 3, group: .legs),
                ex("Leg Press", sets: 4, group: .legs),
                ex("Cadeira Extensora", sets: 3, notes: nearFailure, group: .legs),
                ex("Cadeira Flexora", sets: 3, group: .legs),
                ex("Gêmeos em Pé", sets: 4, group: .legs),
                ex("Abdominal Reto", sets: 3, group: .core),
            ]
        ),
        sheet(
            title: "Militar Masculino H — Inferiores Posterior (Cabo)",
            description: "\(methodNote). Posterior e volume · Cabo.",
            gender: .male,
            exercises: [
                ex("Mesa Flexora", sets: 4, notes: militaryCadence, group: .legs),
                ex("Stiff", sets: 4, group: .legs),
                ex("Leg Press", sets: 3, group: .legs),
                ex("Sumô com Halteres", sets: 3, group: .legs),
                ex("Cadeira Abdutora", sets: 3, group: .legs),
                ex("Gêmeos em Pé", sets: 4, group: .legs),
                ex("Abdômen Corda", sets: 3, group: .core),
                ex("Abdominal Infra", sets: 3, group: .core),
            ]
        ),
        sheet(
            title: "Militar Masculino I — Condicionamento Missão (Cabo)",
            description: "\(methodNote). Missão de condicionamento + ombros/braços.",
            gender: .male,
            exercises: [
                ex("Burpee", sets: 3, reps: 12, notes: finisherNote, group: .fullBody),
                ex("Desenvolvimento Militar", sets: 3, notes: militaryCadence, group: .shoulders),
                ex("Elevação Lateral com Halteres", sets: 3, group: .shoulders),
                ex("Flexão de Braços", sets: 3, reps: 15, group: .chest),
                ex("Rosca Martelo em Pé Alternado", sets: 3, group: .arms),
                ex("Tríceps Pulley Barra W", sets: 3, group: .arms),
                ex("Mountain Climber", sets: 3, reps: 30, notes: finisherNote, group: .fullBody),
                ex("Prancha", sets: 3, reps: 45, notes: "Isometria", group: .core),
            ]
        ),
    ]

    // MARK: - Helpers

    private static func sheet(
        title: String,
        description: String,
        gender: Gender,
        exercises: [Exercise]
    ) -> WorkoutSheet {
        WorkoutSheet(
            title: title,
            description: description,
            exercises: exercises,
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
