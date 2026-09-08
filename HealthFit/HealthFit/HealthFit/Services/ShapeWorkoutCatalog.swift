import Foundation

/// Fichas do **Método Shape de Respeito** (Fernando Cantarelli) — Semana 2 / Macrociclo 1.
/// Nível 1 e Nível 2, masculino e feminino, conforme as fichas do PDF.
enum ShapeWorkoutCatalog {
    private static let nearFailure = "Próximo da falha"
    private static let warmupLight = "Aquecimento (peso leve)"
    private static let noHeavyLoads = "Não utilize cargas altas"
    private static let dropSetLast = "Drop set ao final da última série"
    private static let methodNote =
        "Baseado no Método Shape de Respeito (Fernando Cantarelli) — Semana 2, Macrociclo 1"

    // MARK: - Public API

    static var allMaleSheets: [WorkoutSheet] { maleLevel1 + maleLevel2 }
    static var allFemaleSheets: [WorkoutSheet] { femaleLevel1 + femaleLevel2 }

    static var allTitles: Set<String> {
        Set((allMaleSheets + allFemaleSheets).map(\.title))
    }

    static var allMaleTitles: Set<String> {
        Set(allMaleSheets.map(\.title))
    }

    static var allFemaleTitles: Set<String> {
        Set(allFemaleSheets.map(\.title))
    }

    static func sheets(for gender: Gender) -> [WorkoutSheet] {
        gender == .female ? allFemaleSheets : allMaleSheets
    }

    // MARK: - Feminino Nível 1 (4 dias ativos)

    private static let femaleLevel1: [WorkoutSheet] = [
        sheet(
            title: "Shape Feminino A — Inferiores (Nível 1)",
            description: "\(methodNote). Ênfase em quadríceps.",
            gender: .female,
            exercises: [
                ex("Agachamento Corporal", sets: 1, reps: 15, notes: "Aquecimento", group: .legs),
                ex("Agachamento Livre", sets: 3, notes: noHeavyLoads, group: .legs),
                ex("Leg Press 45", sets: 3, group: .legs),
                ex("Cadeira Extensora", sets: 2, group: .legs),
                ex("Gêmeos em Pé", sets: 3, group: .legs),
            ]
        ),
        sheet(
            title: "Shape Feminino B — Superiores (Nível 1)",
            description: "\(methodNote). Costas, peito, ombros e braços.",
            gender: .female,
            exercises: [
                ex("Rotação Externa Polia Unilateral", sets: 2, reps: 10, notes: warmupLight, group: .shoulders),
                ex("Puxada Alta Frente", sets: 3, group: .back),
                ex("Supino Inclinado com Halteres", sets: 3, group: .chest),
                ex("Elevação Lateral com Halteres", sets: 3, group: .shoulders),
                ex("Tríceps Pulley Barra W", sets: 3, group: .arms),
                ex("Rosca Direta Corda (Martelo)", sets: 3, group: .arms),
                ex("Abdominal Reto", sets: 3, group: .core),
                ex("Prancha", sets: 2, reps: 30, notes: "Isometria 20–30 s", group: .core),
            ]
        ),
        sheet(
            title: "Shape Feminino C — Posterior e Abdutora (Nível 1)",
            description: "\(methodNote). Posterior de coxa, abdutora e panturrilha.",
            gender: .female,
            exercises: [
                ex("Cadeira Flexora", sets: 3, group: .legs),
                ex("Mesa Flexora", sets: 3, group: .legs),
                ex("Leg Press", sets: 3, group: .legs),
                ex("Cadeira Abdutora", sets: 3, group: .legs),
                ex("Gêmeos em Pé", sets: 3, group: .legs),
                ex("Abdominal Infra", sets: 3, group: .core),
            ]
        ),
        sheet(
            title: "Shape Feminino D — Costas e Braços (Nível 1)",
            description: "\(methodNote). Remada, peito e braços.",
            gender: .female,
            exercises: [
                ex("Rotação Externa Polia Unilateral", sets: 2, reps: 10, notes: warmupLight, group: .shoulders),
                ex("Remada Baixa Pronada", sets: 3, group: .back),
                ex("Crossover", sets: 3, group: .chest),
                ex("Crucifixo Inverso Máquina", sets: 3, group: .shoulders),
                ex("Rosca Direta Cabo Barra W", sets: 3, group: .arms),
                ex("Tríceps Corda", sets: 3, group: .arms),
                ex("Prancha", sets: 3, reps: 30, notes: "Isometria", group: .core),
            ]
        ),
    ]

    // MARK: - Feminino Nível 2 (5 dias ativos)

    private static let femaleLevel2: [WorkoutSheet] = [
        sheet(
            title: "Shape Feminino E — Posterior e Glúteo (Nível 2)",
            description: "\(methodNote). Posterior, glúteo e panturrilha.",
            gender: .female,
            exercises: [
                ex("Stiff", sets: 3, group: .legs),
                ex("Cadeira Flexora", sets: 3, group: .legs),
                ex("Mesa Flexora", sets: 3, reps: 15, group: .legs),
                ex("Leg Press 45", sets: 3, group: .legs),
                ex("Elevação Pélvica", sets: 3, notes: "\(nearFailure) — pode fazer na máquina", group: .legs),
                ex("Gêmeos em Pé", sets: 4, group: .legs),
            ]
        ),
        sheet(
            title: "Shape Feminino F — Superiores Completo (Nível 2)",
            description: "\(methodNote). Costas, ombros, braços e abdômen.",
            gender: .female,
            exercises: [
                ex("Elevação Lateral", sets: 2, reps: 10, notes: warmupLight, group: .shoulders),
                ex("Puxada Alta Frente", sets: 3, group: .back),
                ex("Remada Curvada com Halteres", sets: 3, group: .back),
                ex("Remada Baixa", sets: 3, group: .back),
                ex("Desenvolvimento com Halteres", sets: 3, group: .shoulders),
                ex("Rosca Direta Barra W", sets: 3, group: .arms),
                ex("Tríceps Pulley Barra W", sets: 3, group: .arms),
                ex("Abdominal Reto", sets: 3, group: .core),
                ex("Abdominal Infra", sets: 3, group: .core),
            ]
        ),
        sheet(
            title: "Shape Feminino G — Quadríceps (Nível 2)",
            description: "\(methodNote). Ênfase em quadríceps.",
            gender: .female,
            exercises: [
                ex("Agachamento Búlgaro", sets: 2, reps: 10, notes: "\(warmupLight) — se não conseguir, faça afundo", group: .legs),
                ex("Agachamento Livre", sets: 3, group: .legs),
                ex("Leg Press", sets: 3, group: .legs),
                ex("Cadeira Extensora", sets: 3, group: .legs),
            ]
        ),
        sheet(
            title: "Shape Feminino H — Peito Ombros Braços (Nível 2)",
            description: "\(methodNote). Push superior com abdômen.",
            gender: .female,
            exercises: [
                ex("Elevação Lateral", sets: 2, reps: 10, notes: warmupLight, group: .shoulders),
                ex("Desenvolvimento com Halteres", sets: 3, group: .shoulders),
                ex("Crucifixo Inclinado com Halteres", sets: 3, group: .chest),
                ex("Rosca Martelo Corda", sets: 3, group: .arms),
                ex("Tríceps Testa Barra W", sets: 3, group: .arms),
                ex("Abdominal Reto", sets: 3, group: .core),
                ex("Abdominal Infra", sets: 3, group: .core),
            ]
        ),
        sheet(
            title: "Shape Feminino I — Glúteo (Nível 2)",
            description: "\(methodNote). Abdutora, sumô e elevação pélvica.",
            gender: .female,
            exercises: [
                ex("Abdução Lateral Polia Baixa", sets: 3, group: .legs),
                ex("Sumô com Halteres", sets: 3, group: .legs),
                ex("Abdução Lateral Caneleira", sets: 3, group: .legs),
                ex("Elevação Pélvica", sets: 3, notes: "\(nearFailure) — pode fazer na máquina", group: .legs),
                ex("Cadeira Abdutora", sets: 3, group: .legs),
            ]
        ),
    ]

    // MARK: - Masculino Nível 1 (4 dias ativos)

    private static let maleLevel1: [WorkoutSheet] = [
        sheet(
            title: "Shape Masculino A — Superiores (Nível 1)",
            description: "\(methodNote). Costas, peito, ombros e braços.",
            gender: .male,
            exercises: [
                ex("Rotação Externa Polia Unilateral", sets: 2, reps: 10, notes: warmupLight, group: .shoulders),
                ex("Puxada Alta Frente", sets: 3, group: .back),
                ex("Supino Inclinado com Halteres", sets: 3, group: .chest),
                ex("Elevação Lateral com Halteres", sets: 3, group: .shoulders),
                ex("Tríceps Pulley Barra W", sets: 3, group: .arms),
                ex("Rosca Direta Corda (Martelo)", sets: 3, group: .arms),
            ]
        ),
        sheet(
            title: "Shape Masculino B — Inferiores (Nível 1)",
            description: "\(methodNote). Pernas e abdômen.",
            gender: .male,
            exercises: [
                ex("Leg Press 45", sets: 3, group: .legs),
                ex("Mesa Flexora", sets: 3, group: .legs),
                ex("Cadeira Extensora", sets: 3, group: .legs),
                ex("Gêmeos em Pé", sets: 3, group: .legs),
                ex("Abdominal Reto", sets: 3, group: .core),
                ex("Prancha", sets: 2, reps: 30, notes: "Isometria 20–30 s", group: .core),
            ]
        ),
        sheet(
            title: "Shape Masculino C — Costas e Braços (Nível 1)",
            description: "\(methodNote). Remada, peito e braços.",
            gender: .male,
            exercises: [
                ex("Rotação Externa Polia Unilateral", sets: 2, reps: 10, notes: warmupLight, group: .shoulders),
                ex("Remada Baixa Pronada", sets: 3, group: .back),
                ex("Crossover", sets: 3, group: .chest),
                ex("Crucifixo Inverso Máquina", sets: 3, group: .shoulders),
                ex("Rosca Direta Cabo", sets: 3, group: .arms),
                ex("Tríceps Corda", sets: 3, group: .arms),
            ]
        ),
        sheet(
            title: "Shape Masculino D — Inferiores 2 (Nível 1)",
            description: "\(methodNote). Flexora, hack e abdutora.",
            gender: .male,
            exercises: [
                ex("Cadeira Flexora", sets: 3, group: .legs),
                ex("Hack Squat", sets: 3, group: .legs),
                ex("Cadeira Abdutora", sets: 3, group: .legs),
                ex("Gêmeos em Pé", sets: 3, group: .legs),
                ex("Abdominal Infra", sets: 3, group: .core),
            ]
        ),
    ]

    // MARK: - Masculino Nível 2 (5 dias ativos)

    private static let maleLevel2: [WorkoutSheet] = [
        sheet(
            title: "Shape Masculino E — Peito Ombros Tríceps (Nível 2)",
            description: "\(methodNote). Push clássico.",
            gender: .male,
            exercises: [
                ex("Rotação Externa Polia Unilateral", sets: 2, reps: 15, notes: "Aquecimento", group: .shoulders),
                ex("Supino Inclinado com Halteres", sets: 3, group: .chest),
                ex("Crucifixo Inclinado com Halteres", sets: 3, notes: "\(nearFailure) — cabo ou máquina também serve", group: .chest),
                ex("Voador", sets: 3, group: .chest),
                ex("Crossover", sets: 3, group: .chest),
                ex("Elevação Lateral com Halteres", sets: 3, group: .shoulders),
                ex("Tríceps Corda", sets: 4, notes: dropSetLast, group: .arms),
            ]
        ),
        sheet(
            title: "Shape Masculino F — Inferiores e Abdômen (Nível 2)",
            description: "\(methodNote). Pernas completas + core.",
            gender: .male,
            exercises: [
                ex("Agachamento Corporal", sets: 1, reps: 15, notes: "Aquecimento", group: .legs),
                ex("Agachamento Livre", sets: 3, group: .legs),
                ex("Leg Press", sets: 4, group: .legs),
                ex("Cadeira Flexora", sets: 3, group: .legs),
                ex("Mesa Flexora", sets: 3, group: .legs),
                ex("Gêmeos em Pé", sets: 4, group: .legs),
                ex("Abdominal Reto", sets: 3, group: .core),
                ex("Abdominal Infra", sets: 3, group: .core),
            ]
        ),
        sheet(
            title: "Shape Masculino G — Costas Bíceps (Nível 2)",
            description: "\(methodNote). Dorsais, deltoide posterior e bíceps.",
            gender: .male,
            exercises: [
                ex("Rotação Externa Polia Unilateral", sets: 1, reps: 10, notes: "Aquecimento — cada lado", group: .shoulders),
                ex("Puxada Alta Frente", sets: 3, group: .back),
                ex("Remada Curvada Pronada", sets: 4, group: .back),
                ex("Remada Unilateral", sets: 3, group: .back),
                ex("Crucifixo Inverso Máquina", sets: 3, group: .shoulders),
                ex("Rosca Direta Barra W", sets: 3, group: .arms),
                ex("Rosca com Halteres Banco Inclinado", sets: 3, group: .arms),
            ]
        ),
        sheet(
            title: "Shape Masculino H — Inferiores Completo (Nível 2)",
            description: "\(methodNote). Posterior, press, sumô e panturrilha.",
            gender: .male,
            exercises: [
                ex("Mesa Flexora", sets: 4, group: .legs),
                ex("Stiff", sets: 3, group: .legs),
                ex("Leg Press", sets: 3, group: .legs),
                ex("Sumô com Halteres", sets: 3, group: .legs),
                ex("Cadeira Abdutora", sets: 3, group: .legs),
                ex("Gêmeos em Pé", sets: 4, group: .legs),
                ex("Abdômen Corda", sets: 3, group: .core),
                ex("Abdominal Infra", sets: 3, group: .core),
            ]
        ),
        sheet(
            title: "Shape Masculino I — Ombros Bíceps Tríceps (Nível 2)",
            description: "\(methodNote). Ênfase em ombros e braços.",
            gender: .male,
            exercises: [
                ex("Desenvolvimento com Halteres", sets: 3, group: .shoulders),
                ex("Elevação Lateral com Halteres", sets: 4, group: .shoulders),
                ex("Rosca Direta Cabo Baixo", sets: 4, group: .arms),
                ex("Rosca Martelo em Pé Alternado", sets: 3, group: .arms),
                ex("Tríceps Testa Barra W", sets: 4, group: .arms),
                ex("Tríceps Pulley Barra W", sets: 3, group: .arms),
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
