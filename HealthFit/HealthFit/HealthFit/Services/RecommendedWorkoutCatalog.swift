import Foundation

/// Cohortes de fichas **Recomendados** (masculino/feminino), trocadas a cada 30 dias.
enum RecommendedWorkoutCatalog {
    static let rotationIntervalDays = 30

    private static let anchorKey = "healthfit.recommendedRotation.anchor"
    private static let appliedCohortKey = "healthfit.recommendedRotation.appliedCohort"

    // MARK: - Public API

    static func cohortCount(for gender: Gender) -> Int {
        switch gender {
        case .male: return maleCohorts.count
        case .female: return femaleCohorts.count
        }
    }

    static func cohortIndex(at date: Date = .now, anchor: Date) -> Int {
        let days = Calendar.current.dateComponents([.day], from: startOfDay(anchor), to: startOfDay(date)).day ?? 0
        let safeDays = max(0, days)
        let count = max(maleCohorts.count, 1)
        return (safeDays / rotationIntervalDays) % count
    }

    static func sheets(for gender: Gender, cohort: Int) -> [WorkoutSheet] {
        let cohorts = gender == .female ? femaleCohorts : maleCohorts
        guard !cohorts.isEmpty else { return [] }
        let index = ((cohort % cohorts.count) + cohorts.count) % cohorts.count
        return cohorts[index]
    }

    static func titles(for gender: Gender, cohort: Int) -> Set<String> {
        Set(sheets(for: gender, cohort: cohort).map(\.title))
    }

    static var allMaleTitles: Set<String> {
        Set(maleCohorts.flatMap { $0.map(\.title) })
    }

    static var allFemaleTitles: Set<String> {
        Set(femaleCohorts.flatMap { $0.map(\.title) })
    }

    static var allRecommendedTitles: Set<String> {
        allMaleTitles.union(allFemaleTitles)
    }

    /// Fichas usadas no seed inicial (coorte 0).
    static var baselineMaleSheets: [WorkoutSheet] { sheets(for: .male, cohort: 0) }
    static var baselineFemaleSheets: [WorkoutSheet] { sheets(for: .female, cohort: 0) }

    static func ensureAnchor() -> Date {
        if let stored = UserDefaults.standard.object(forKey: anchorKey) as? Date {
            return stored
        }
        let now = Date()
        UserDefaults.standard.set(now, forKey: anchorKey)
        UserDefaults.standard.set(0, forKey: appliedCohortKey)
        return now
    }

    static func appliedCohort() -> Int {
        UserDefaults.standard.object(forKey: appliedCohortKey) as? Int ?? 0
    }

    static func setAppliedCohort(_ cohort: Int) {
        UserDefaults.standard.set(cohort, forKey: appliedCohortKey)
    }

    static func daysUntilNextRotation(now: Date = .now) -> Int {
        let anchor = ensureAnchor()
        let days = Calendar.current.dateComponents([.day], from: startOfDay(anchor), to: startOfDay(now)).day ?? 0
        let elapsedInCycle = max(0, days) % rotationIntervalDays
        return rotationIntervalDays - elapsedInCycle
    }

    private static func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    // MARK: - Cohorts (male)

    private static let maleCohorts: [[WorkoutSheet]] = [
        // Coorte 0 — clássico
        [
            sheet(
                title: "Masculino A — Peito e Tríceps",
                description: "Hipertrofia de peitoral e tríceps — perfil masculino",
                gender: .male,
                warmup: .upper,
                abs: .plankCrunch,
                main: [
                    Exercise(name: "Supino Reto", sets: 4, reps: 8, weight: 70, restSeconds: 90, muscleGroup: .chest),
                    Exercise(name: "Supino Inclinado", sets: 4, reps: 10, weight: 55, restSeconds: 90, muscleGroup: .chest),
                    Exercise(name: "Supino Declinado", sets: 3, reps: 10, weight: 60, restSeconds: 75, muscleGroup: .chest),
                    Exercise(name: "Crucifixo Reto", sets: 3, reps: 12, weight: 16, restSeconds: 60, muscleGroup: .chest),
                    Exercise(name: "Crossover", sets: 3, reps: 12, weight: 12, restSeconds: 60, muscleGroup: .chest),
                    Exercise(name: "Flexão de Braços", sets: 3, reps: 15, restSeconds: 60, muscleGroup: .chest),
                    Exercise(name: "Tríceps Pulley", sets: 4, reps: 10, weight: 30, restSeconds: 60, muscleGroup: .arms),
                    Exercise(name: "Tríceps Testa", sets: 3, reps: 10, weight: 25, restSeconds: 60, muscleGroup: .arms),
                    Exercise(name: "Tríceps Francês", sets: 3, reps: 12, weight: 16, restSeconds: 60, muscleGroup: .arms),
                    Exercise(name: "Mergulho no Banco", sets: 3, reps: 12, restSeconds: 60, muscleGroup: .arms)
                ]
            ),
            sheet(
                title: "Masculino B — Costas e Bíceps",
                description: "Largura dorsal e bíceps — perfil masculino",
                gender: .male,
                warmup: .upper,
                abs: .legsBicycle,
                main: [
                    Exercise(name: "Barra Fixa", sets: 4, reps: 8, restSeconds: 90, muscleGroup: .back),
                    Exercise(name: "Remada Curvada", sets: 4, reps: 8, weight: 60, restSeconds: 90, muscleGroup: .back),
                    Exercise(name: "Puxada Frontal", sets: 4, reps: 10, weight: 50, restSeconds: 75, muscleGroup: .back),
                    Exercise(name: "Remada Unilateral", sets: 3, reps: 10, weight: 26, restSeconds: 60, muscleGroup: .back),
                    Exercise(name: "Pulldown Triângulo", sets: 3, reps: 12, weight: 45, restSeconds: 60, muscleGroup: .back),
                    Exercise(name: "Levantamento Terra", sets: 3, reps: 6, weight: 90, restSeconds: 120, muscleGroup: .fullBody),
                    Exercise(name: "Rosca Direta", sets: 4, reps: 10, weight: 16, restSeconds: 60, muscleGroup: .arms),
                    Exercise(name: "Rosca Martelo", sets: 3, reps: 10, weight: 14, restSeconds: 60, muscleGroup: .arms),
                    Exercise(name: "Rosca Scott", sets: 3, reps: 12, weight: 12, restSeconds: 60, muscleGroup: .arms),
                    Exercise(name: "Rosca Concentrada", sets: 3, reps: 12, weight: 10, restSeconds: 45, muscleGroup: .arms)
                ]
            ),
            sheet(
                title: "Masculino C — Pernas",
                description: "Força e volume de membros inferiores — perfil masculino",
                gender: .male,
                warmup: .lower,
                abs: .plankOblique,
                main: [
                    Exercise(name: "Agachamento Livre", sets: 4, reps: 8, weight: 90, restSeconds: 120, muscleGroup: .legs),
                    Exercise(name: "Leg Press 45°", sets: 4, reps: 10, weight: 180, restSeconds: 90, muscleGroup: .legs),
                    Exercise(name: "Hack Squat", sets: 3, reps: 10, weight: 120, restSeconds: 90, muscleGroup: .legs),
                    Exercise(name: "Cadeira Extensora", sets: 3, reps: 12, weight: 45, restSeconds: 60, muscleGroup: .legs),
                    Exercise(name: "Mesa Flexora", sets: 4, reps: 10, weight: 40, restSeconds: 60, muscleGroup: .legs),
                    Exercise(name: "Stiff", sets: 3, reps: 10, weight: 60, restSeconds: 75, muscleGroup: .legs),
                    Exercise(name: "Afundo", sets: 3, reps: 10, weight: 24, restSeconds: 75, muscleGroup: .legs),
                    Exercise(name: "Panturrilha em Pé", sets: 4, reps: 15, weight: 90, restSeconds: 45, muscleGroup: .legs),
                    Exercise(name: "Panturrilha Sentado", sets: 4, reps: 15, weight: 55, restSeconds: 45, muscleGroup: .legs)
                ]
            ),
            sheet(
                title: "Masculino D — Ombros e Trapézio",
                description: "Deltoides e trapézio para estrutura — perfil masculino",
                gender: .male,
                warmup: .upper,
                abs: .infraBicycle,
                main: [
                    Exercise(name: "Desenvolvimento Militar", sets: 4, reps: 8, weight: 45, restSeconds: 90, muscleGroup: .shoulders),
                    Exercise(name: "Desenvolvimento com Halteres", sets: 3, reps: 10, weight: 20, restSeconds: 75, muscleGroup: .shoulders),
                    Exercise(name: "Elevação Lateral", sets: 4, reps: 12, weight: 12, restSeconds: 60, muscleGroup: .shoulders),
                    Exercise(name: "Elevação Frontal", sets: 3, reps: 12, weight: 12, restSeconds: 60, muscleGroup: .shoulders),
                    Exercise(name: "Remada Alta", sets: 4, reps: 10, weight: 35, restSeconds: 75, muscleGroup: .shoulders),
                    Exercise(name: "Encolhimento com Barra", sets: 4, reps: 12, weight: 70, restSeconds: 75, muscleGroup: .back),
                    Exercise(name: "Encolhimento com Halteres", sets: 3, reps: 15, weight: 26, restSeconds: 60, muscleGroup: .back),
                    Exercise(name: "Face Pull", sets: 3, reps: 15, weight: 22, restSeconds: 60, muscleGroup: .back),
                    Exercise(name: "Crucifixo Inverso", sets: 3, reps: 12, weight: 10, restSeconds: 60, muscleGroup: .shoulders)
                ]
            )
        ],
        // Coorte 1 — variação push/pull/legs
        [
            sheet(
                title: "Masculino A — Peito e Ombros",
                description: "Presses e laterais — ciclo mensal 2",
                gender: .male,
                warmup: .upper,
                abs: .plankCrunch,
                main: [
                    Exercise(name: "Supino Reto", sets: 4, reps: 8, weight: 70, restSeconds: 90, muscleGroup: .chest),
                    Exercise(name: "Supino Inclinado com Halteres", sets: 4, reps: 10, weight: 28, restSeconds: 75, muscleGroup: .chest),
                    Exercise(name: "Crucifixo Inclinado", sets: 3, reps: 12, weight: 14, restSeconds: 60, muscleGroup: .chest),
                    Exercise(name: "Crossover", sets: 3, reps: 15, weight: 12, restSeconds: 45, muscleGroup: .chest),
                    Exercise(name: "Desenvolvimento com Halteres", sets: 4, reps: 10, weight: 20, restSeconds: 75, muscleGroup: .shoulders),
                    Exercise(name: "Elevação Lateral", sets: 4, reps: 12, weight: 10, restSeconds: 45, muscleGroup: .shoulders),
                    Exercise(name: "Elevação Frontal", sets: 3, reps: 12, weight: 10, restSeconds: 45, muscleGroup: .shoulders),
                    Exercise(name: "Tríceps Pulley", sets: 3, reps: 12, weight: 28, restSeconds: 45, muscleGroup: .arms)
                ]
            ),
            sheet(
                title: "Masculino B — Costas e Posterior",
                description: "Puxadas e cadeia posterior — ciclo mensal 2",
                gender: .male,
                warmup: .upper,
                abs: .legsBicycle,
                main: [
                    Exercise(name: "Puxada Frontal", sets: 4, reps: 10, weight: 50, restSeconds: 75, muscleGroup: .back),
                    Exercise(name: "Remada Curvada", sets: 4, reps: 8, weight: 60, restSeconds: 90, muscleGroup: .back),
                    Exercise(name: "Remada Unilateral", sets: 3, reps: 10, weight: 26, restSeconds: 60, muscleGroup: .back),
                    Exercise(name: "Pulldown Triângulo", sets: 3, reps: 12, weight: 45, restSeconds: 60, muscleGroup: .back),
                    Exercise(name: "Stiff", sets: 4, reps: 8, weight: 70, restSeconds: 90, muscleGroup: .legs),
                    Exercise(name: "Mesa Flexora", sets: 3, reps: 12, weight: 40, restSeconds: 60, muscleGroup: .legs),
                    Exercise(name: "Face Pull", sets: 3, reps: 15, weight: 20, restSeconds: 45, muscleGroup: .back),
                    Exercise(name: "Rosca Direta", sets: 3, reps: 12, weight: 16, restSeconds: 45, muscleGroup: .arms)
                ]
            ),
            sheet(
                title: "Masculino C — Pernas e Core",
                description: "Volume de pernas com estabilidade — ciclo mensal 2",
                gender: .male,
                warmup: .lower,
                abs: .plankLegs,
                main: [
                    Exercise(name: "Agachamento Livre", sets: 4, reps: 10, weight: 80, restSeconds: 120, muscleGroup: .legs),
                    Exercise(name: "Leg Press 45°", sets: 4, reps: 12, weight: 160, restSeconds: 90, muscleGroup: .legs),
                    Exercise(name: "Afundo", sets: 3, reps: 12, weight: 20, restSeconds: 60, muscleGroup: .legs),
                    Exercise(name: "Cadeira Extensora", sets: 3, reps: 15, weight: 40, restSeconds: 45, muscleGroup: .legs),
                    Exercise(name: "Mesa Flexora", sets: 3, reps: 12, weight: 35, restSeconds: 45, muscleGroup: .legs),
                    Exercise(name: "Elevação Pélvica (Hip Thrust)", sets: 3, reps: 12, weight: 60, restSeconds: 60, muscleGroup: .legs),
                    Exercise(name: "Panturrilha em Pé", sets: 4, reps: 15, weight: 80, restSeconds: 40, muscleGroup: .legs)
                ]
            ),
            sheet(
                title: "Masculino D — Braços e Trapézio",
                description: "Bíceps, tríceps e trapézio — ciclo mensal 2",
                gender: .male,
                warmup: .upper,
                abs: .crunchBicycle,
                main: [
                    Exercise(name: "Rosca Direta", sets: 4, reps: 10, weight: 18, restSeconds: 60, muscleGroup: .arms),
                    Exercise(name: "Rosca Martelo", sets: 3, reps: 12, weight: 14, restSeconds: 45, muscleGroup: .arms),
                    Exercise(name: "Rosca Scott", sets: 3, reps: 12, weight: 12, restSeconds: 45, muscleGroup: .arms),
                    Exercise(name: "Tríceps Pulley", sets: 4, reps: 12, weight: 30, restSeconds: 45, muscleGroup: .arms),
                    Exercise(name: "Tríceps Testa", sets: 3, reps: 10, weight: 25, restSeconds: 60, muscleGroup: .arms),
                    Exercise(name: "Mergulho no Banco", sets: 3, reps: 12, restSeconds: 60, muscleGroup: .arms),
                    Exercise(name: "Encolhimento com Halteres", sets: 4, reps: 15, weight: 28, restSeconds: 45, muscleGroup: .back),
                    Exercise(name: "Remada Alta", sets: 3, reps: 12, weight: 30, restSeconds: 60, muscleGroup: .shoulders)
                ]
            )
        ],
        // Coorte 2 — força / full body
        [
            sheet(
                title: "Masculino A — Full Body Força",
                description: "Movimentos compostos — ciclo mensal 3",
                gender: .male,
                warmup: .lower,
                abs: .plankCrunch,
                main: [
                    Exercise(name: "Agachamento Livre", sets: 4, reps: 6, weight: 100, restSeconds: 150, muscleGroup: .legs),
                    Exercise(name: "Supino Reto", sets: 4, reps: 6, weight: 75, restSeconds: 150, muscleGroup: .chest),
                    Exercise(name: "Levantamento Terra", sets: 3, reps: 5, weight: 110, restSeconds: 180, muscleGroup: .fullBody),
                    Exercise(name: "Barra Fixa", sets: 3, reps: 6, restSeconds: 120, muscleGroup: .back),
                    Exercise(name: "Desenvolvimento Militar", sets: 3, reps: 8, weight: 40, restSeconds: 90, muscleGroup: .shoulders),
                    Exercise(name: "Remada Curvada", sets: 3, reps: 8, weight: 60, restSeconds: 90, muscleGroup: .back)
                ]
            ),
            sheet(
                title: "Masculino B — Push",
                description: "Peito, ombros e tríceps — ciclo mensal 3",
                gender: .male,
                warmup: .upper,
                abs: .plankOblique,
                main: [
                    Exercise(name: "Supino Reto", sets: 4, reps: 8, weight: 70, restSeconds: 90, muscleGroup: .chest),
                    Exercise(name: "Supino Inclinado", sets: 3, reps: 10, weight: 55, restSeconds: 75, muscleGroup: .chest),
                    Exercise(name: "Desenvolvimento com Halteres", sets: 4, reps: 10, weight: 20, restSeconds: 75, muscleGroup: .shoulders),
                    Exercise(name: "Elevação Lateral", sets: 3, reps: 15, weight: 10, restSeconds: 45, muscleGroup: .shoulders),
                    Exercise(name: "Tríceps Pulley", sets: 3, reps: 12, weight: 30, restSeconds: 45, muscleGroup: .arms),
                    Exercise(name: "Tríceps Francês", sets: 3, reps: 12, weight: 16, restSeconds: 45, muscleGroup: .arms),
                    Exercise(name: "Flexão de Braços", sets: 3, reps: 15, restSeconds: 45, muscleGroup: .chest)
                ]
            ),
            sheet(
                title: "Masculino C — Pull",
                description: "Costas e bíceps — ciclo mensal 3",
                gender: .male,
                warmup: .upper,
                abs: .legsBicycle,
                main: [
                    Exercise(name: "Barra Fixa", sets: 4, reps: 8, restSeconds: 90, muscleGroup: .back),
                    Exercise(name: "Remada Curvada", sets: 4, reps: 8, weight: 60, restSeconds: 90, muscleGroup: .back),
                    Exercise(name: "Puxada Frontal", sets: 3, reps: 10, weight: 50, restSeconds: 75, muscleGroup: .back),
                    Exercise(name: "Remada Unilateral", sets: 3, reps: 10, weight: 26, restSeconds: 60, muscleGroup: .back),
                    Exercise(name: "Face Pull", sets: 3, reps: 15, weight: 20, restSeconds: 45, muscleGroup: .back),
                    Exercise(name: "Rosca Direta", sets: 3, reps: 10, weight: 16, restSeconds: 45, muscleGroup: .arms),
                    Exercise(name: "Rosca Martelo", sets: 3, reps: 12, weight: 14, restSeconds: 45, muscleGroup: .arms)
                ]
            ),
            sheet(
                title: "Masculino D — Legs Power",
                description: "Potência de pernas — ciclo mensal 3",
                gender: .male,
                warmup: .lower,
                abs: .infraBicycle,
                main: [
                    Exercise(name: "Agachamento Livre", sets: 4, reps: 6, weight: 100, restSeconds: 150, muscleGroup: .legs),
                    Exercise(name: "Hack Squat", sets: 3, reps: 8, weight: 130, restSeconds: 120, muscleGroup: .legs),
                    Exercise(name: "Leg Press 45°", sets: 3, reps: 10, weight: 200, restSeconds: 90, muscleGroup: .legs),
                    Exercise(name: "Stiff", sets: 3, reps: 8, weight: 70, restSeconds: 90, muscleGroup: .legs),
                    Exercise(name: "Afundo Búlgaro", sets: 3, reps: 10, weight: 20, restSeconds: 60, muscleGroup: .legs),
                    Exercise(name: "Panturrilha em Pé", sets: 4, reps: 12, weight: 100, restSeconds: 40, muscleGroup: .legs)
                ]
            )
        ]
    ]

    // MARK: - Cohorts (female)

    private static let femaleCohorts: [[WorkoutSheet]] = [
        [
            sheet(
                title: "Feminino A — Glúteos e Posteriores",
                description: "Ativação e hipertrofia de glúteos e cadeia posterior — perfil feminino",
                gender: .female,
                warmup: .lower,
                abs: .plankCrunch,
                main: [
                    Exercise(name: "Elevação Pélvica (Hip Thrust)", sets: 4, reps: 12, weight: 40, restSeconds: 75, muscleGroup: .legs),
                    Exercise(name: "Agachamento Sumô", sets: 4, reps: 12, weight: 40, restSeconds: 90, muscleGroup: .legs),
                    Exercise(name: "Stiff", sets: 4, reps: 12, weight: 30, restSeconds: 75, muscleGroup: .legs),
                    Exercise(name: "Afundo Búlgaro", sets: 3, reps: 12, weight: 12, restSeconds: 75, muscleGroup: .legs),
                    Exercise(name: "Cadeira Abdutora", sets: 4, reps: 15, weight: 40, restSeconds: 45, muscleGroup: .legs),
                    Exercise(name: "Coice na Polia", sets: 3, reps: 15, weight: 15, restSeconds: 45, muscleGroup: .legs),
                    Exercise(name: "Mesa Flexora", sets: 3, reps: 12, weight: 25, restSeconds: 60, muscleGroup: .legs),
                    Exercise(name: "Panturrilha em Pé", sets: 3, reps: 15, weight: 40, restSeconds: 45, muscleGroup: .legs)
                ]
            ),
            sheet(
                title: "Feminino B — Pernas e Core",
                description: "Quadríceps, adutores e abdômen — perfil feminino",
                gender: .female,
                warmup: .lower,
                abs: .infraBicycle,
                main: [
                    Exercise(name: "Agachamento Livre", sets: 4, reps: 12, weight: 35, restSeconds: 90, muscleGroup: .legs),
                    Exercise(name: "Leg Press 45°", sets: 4, reps: 15, weight: 80, restSeconds: 75, muscleGroup: .legs),
                    Exercise(name: "Cadeira Extensora", sets: 4, reps: 15, weight: 30, restSeconds: 60, muscleGroup: .legs),
                    Exercise(name: "Cadeira Adutora", sets: 3, reps: 15, weight: 40, restSeconds: 45, muscleGroup: .legs),
                    Exercise(name: "Afundo", sets: 3, reps: 12, weight: 10, restSeconds: 60, muscleGroup: .legs),
                    Exercise(name: "Panturrilha Sentado", sets: 3, reps: 20, weight: 30, restSeconds: 45, muscleGroup: .legs)
                ]
            ),
            sheet(
                title: "Feminino C — Costas e Postura",
                description: "Costas, ombros posteriores e braços leves — perfil feminino",
                gender: .female,
                warmup: .upper,
                abs: .plankOblique,
                main: [
                    Exercise(name: "Puxada Frontal", sets: 4, reps: 12, weight: 30, restSeconds: 75, muscleGroup: .back),
                    Exercise(name: "Remada Unilateral", sets: 3, reps: 12, weight: 12, restSeconds: 60, muscleGroup: .back),
                    Exercise(name: "Pulldown Triângulo", sets: 3, reps: 12, weight: 25, restSeconds: 60, muscleGroup: .back),
                    Exercise(name: "Remada Curvada", sets: 3, reps: 12, weight: 25, restSeconds: 75, muscleGroup: .back),
                    Exercise(name: "Face Pull", sets: 3, reps: 15, weight: 12, restSeconds: 45, muscleGroup: .back),
                    Exercise(name: "Crucifixo Inverso", sets: 3, reps: 15, weight: 6, restSeconds: 45, muscleGroup: .shoulders),
                    Exercise(name: "Elevação Lateral", sets: 3, reps: 15, weight: 6, restSeconds: 45, muscleGroup: .shoulders),
                    Exercise(name: "Rosca Direta", sets: 3, reps: 12, weight: 8, restSeconds: 45, muscleGroup: .arms),
                    Exercise(name: "Tríceps Pulley", sets: 3, reps: 12, weight: 15, restSeconds: 45, muscleGroup: .arms)
                ]
            ),
            sheet(
                title: "Feminino D — Full Body e Ombros",
                description: "Corpo inteiro com ênfase em ombros e core — perfil feminino",
                gender: .female,
                warmup: .upper,
                abs: .crunchBicycle,
                main: [
                    Exercise(name: "Agachamento Livre", sets: 3, reps: 12, weight: 30, restSeconds: 75, muscleGroup: .legs),
                    Exercise(name: "Elevação Pélvica (Hip Thrust)", sets: 3, reps: 12, weight: 35, restSeconds: 60, muscleGroup: .legs),
                    Exercise(name: "Puxada Frontal", sets: 3, reps: 12, weight: 25, restSeconds: 60, muscleGroup: .back),
                    Exercise(name: "Desenvolvimento com Halteres", sets: 3, reps: 12, weight: 8, restSeconds: 60, muscleGroup: .shoulders),
                    Exercise(name: "Elevação Lateral", sets: 3, reps: 15, weight: 5, restSeconds: 45, muscleGroup: .shoulders),
                    Exercise(name: "Flexão de Braços", sets: 3, reps: 10, restSeconds: 60, muscleGroup: .chest),
                    Exercise(name: "Remada Unilateral", sets: 3, reps: 12, weight: 10, restSeconds: 60, muscleGroup: .back),
                    Exercise(name: "Kettlebell Swing", sets: 3, reps: 15, weight: 12, restSeconds: 60, muscleGroup: .fullBody)
                ]
            )
        ],
        [
            sheet(
                title: "Feminino A — Glúteos Power",
                description: "Ênfase em glúteo máximo e médio — ciclo mensal 2",
                gender: .female,
                warmup: .lower,
                abs: .plankCrunch,
                main: [
                    Exercise(name: "Elevação Pélvica (Hip Thrust)", sets: 4, reps: 10, weight: 45, restSeconds: 75, muscleGroup: .legs),
                    Exercise(name: "Agachamento Sumô", sets: 4, reps: 12, weight: 35, restSeconds: 75, muscleGroup: .legs),
                    Exercise(name: "Coice na Polia", sets: 4, reps: 15, weight: 12, restSeconds: 40, muscleGroup: .legs),
                    Exercise(name: "Cadeira Abdutora", sets: 4, reps: 15, weight: 35, restSeconds: 40, muscleGroup: .legs),
                    Exercise(name: "Afundo Búlgaro", sets: 3, reps: 12, weight: 10, restSeconds: 60, muscleGroup: .legs),
                    Exercise(name: "Stiff", sets: 3, reps: 12, weight: 25, restSeconds: 60, muscleGroup: .legs)
                ]
            ),
            sheet(
                title: "Feminino B — Inferiores Metabólico",
                description: "Pernas com densidade e pouco descanso — ciclo mensal 2",
                gender: .female,
                warmup: .lower,
                abs: .legsBicycle,
                main: [
                    Exercise(name: "Leg Press 45°", sets: 4, reps: 15, weight: 70, restSeconds: 60, muscleGroup: .legs),
                    Exercise(name: "Cadeira Extensora", sets: 3, reps: 15, weight: 28, restSeconds: 40, muscleGroup: .legs),
                    Exercise(name: "Mesa Flexora", sets: 3, reps: 15, weight: 25, restSeconds: 40, muscleGroup: .legs),
                    Exercise(name: "Afundo", sets: 3, reps: 14, weight: 8, restSeconds: 45, muscleGroup: .legs),
                    Exercise(name: "Cadeira Adutora", sets: 3, reps: 15, weight: 35, restSeconds: 40, muscleGroup: .legs),
                    Exercise(name: "Panturrilha Sentado", sets: 3, reps: 20, weight: 25, restSeconds: 30, muscleGroup: .legs)
                ]
            ),
            sheet(
                title: "Feminino C — Superiores Leve",
                description: "Costas e ombros com carga moderada — ciclo mensal 2",
                gender: .female,
                warmup: .upper,
                abs: .plankOblique,
                main: [
                    Exercise(name: "Puxada Frontal", sets: 4, reps: 12, weight: 25, restSeconds: 60, muscleGroup: .back),
                    Exercise(name: "Remada Unilateral", sets: 3, reps: 12, weight: 10, restSeconds: 45, muscleGroup: .back),
                    Exercise(name: "Elevação Lateral", sets: 4, reps: 15, weight: 5, restSeconds: 40, muscleGroup: .shoulders),
                    Exercise(name: "Desenvolvimento com Halteres", sets: 3, reps: 12, weight: 6, restSeconds: 50, muscleGroup: .shoulders),
                    Exercise(name: "Face Pull", sets: 3, reps: 15, weight: 10, restSeconds: 40, muscleGroup: .back),
                    Exercise(name: "Tríceps Pulley", sets: 3, reps: 12, weight: 12, restSeconds: 40, muscleGroup: .arms),
                    Exercise(name: "Rosca Direta", sets: 3, reps: 12, weight: 6, restSeconds: 40, muscleGroup: .arms)
                ]
            ),
            sheet(
                title: "Feminino D — Full Body Circuito",
                description: "Corpo inteiro em ritmo contínuo — ciclo mensal 2",
                gender: .female,
                warmup: .lower,
                abs: .crunchBicycle,
                main: [
                    Exercise(name: "Agachamento Livre", sets: 3, reps: 15, weight: 25, restSeconds: 45, muscleGroup: .legs),
                    Exercise(name: "Elevação Pélvica (Hip Thrust)", sets: 3, reps: 15, weight: 30, restSeconds: 45, muscleGroup: .legs),
                    Exercise(name: "Remada Unilateral", sets: 3, reps: 12, weight: 10, restSeconds: 45, muscleGroup: .back),
                    Exercise(name: "Elevação Lateral", sets: 3, reps: 15, weight: 4, restSeconds: 35, muscleGroup: .shoulders),
                    Exercise(name: "Flexão de Braços", sets: 3, reps: 10, restSeconds: 45, muscleGroup: .chest),
                    Exercise(name: "Kettlebell Swing", sets: 3, reps: 15, weight: 10, restSeconds: 45, muscleGroup: .fullBody),
                    Exercise(name: "Mountain Climber", sets: 3, reps: 20, restSeconds: 35, muscleGroup: .fullBody)
                ]
            )
        ],
        [
            sheet(
                title: "Feminino A — Posterior e Postura",
                description: "Cadeia posterior e escápulas — ciclo mensal 3",
                gender: .female,
                warmup: .lower,
                abs: .plankLegs,
                main: [
                    Exercise(name: "Stiff", sets: 4, reps: 10, weight: 30, restSeconds: 75, muscleGroup: .legs),
                    Exercise(name: "Elevação Pélvica (Hip Thrust)", sets: 4, reps: 12, weight: 40, restSeconds: 60, muscleGroup: .legs),
                    Exercise(name: "Mesa Flexora", sets: 3, reps: 12, weight: 25, restSeconds: 45, muscleGroup: .legs),
                    Exercise(name: "Remada Unilateral", sets: 3, reps: 12, weight: 12, restSeconds: 45, muscleGroup: .back),
                    Exercise(name: "Face Pull", sets: 3, reps: 15, weight: 10, restSeconds: 40, muscleGroup: .back),
                    Exercise(name: "Crucifixo Inverso", sets: 3, reps: 15, weight: 5, restSeconds: 40, muscleGroup: .shoulders)
                ]
            ),
            sheet(
                title: "Feminino B — Quadríceps Focus",
                description: "Ênfase em quadríceps e adutores — ciclo mensal 3",
                gender: .female,
                warmup: .lower,
                abs: .infraBicycle,
                main: [
                    Exercise(name: "Agachamento Livre", sets: 4, reps: 10, weight: 35, restSeconds: 90, muscleGroup: .legs),
                    Exercise(name: "Hack Squat", sets: 3, reps: 12, weight: 50, restSeconds: 75, muscleGroup: .legs),
                    Exercise(name: "Cadeira Extensora", sets: 4, reps: 15, weight: 28, restSeconds: 45, muscleGroup: .legs),
                    Exercise(name: "Afundo", sets: 3, reps: 12, weight: 10, restSeconds: 50, muscleGroup: .legs),
                    Exercise(name: "Cadeira Adutora", sets: 3, reps: 15, weight: 35, restSeconds: 40, muscleGroup: .legs),
                    Exercise(name: "Panturrilha em Pé", sets: 3, reps: 15, weight: 35, restSeconds: 30, muscleGroup: .legs)
                ]
            ),
            sheet(
                title: "Feminino C — Costas e Braços",
                description: "Largura dorsal e definição de braços — ciclo mensal 3",
                gender: .female,
                warmup: .upper,
                abs: .plankCrunch,
                main: [
                    Exercise(name: "Puxada Frontal", sets: 4, reps: 10, weight: 30, restSeconds: 70, muscleGroup: .back),
                    Exercise(name: "Pulldown Triângulo", sets: 3, reps: 12, weight: 25, restSeconds: 55, muscleGroup: .back),
                    Exercise(name: "Remada Curvada", sets: 3, reps: 12, weight: 20, restSeconds: 60, muscleGroup: .back),
                    Exercise(name: "Rosca Direta", sets: 3, reps: 12, weight: 8, restSeconds: 40, muscleGroup: .arms),
                    Exercise(name: "Rosca Martelo", sets: 3, reps: 12, weight: 6, restSeconds: 40, muscleGroup: .arms),
                    Exercise(name: "Tríceps Pulley", sets: 3, reps: 12, weight: 12, restSeconds: 40, muscleGroup: .arms),
                    Exercise(name: "Elevação Lateral", sets: 3, reps: 15, weight: 4, restSeconds: 35, muscleGroup: .shoulders)
                ]
            ),
            sheet(
                title: "Feminino D — Ombros e Core",
                description: "Deltoides e estabilidade — ciclo mensal 3",
                gender: .female,
                warmup: .upper,
                abs: .crunchBicycle,
                main: [
                    Exercise(name: "Desenvolvimento com Halteres", sets: 4, reps: 10, weight: 8, restSeconds: 60, muscleGroup: .shoulders),
                    Exercise(name: "Elevação Lateral", sets: 4, reps: 15, weight: 5, restSeconds: 40, muscleGroup: .shoulders),
                    Exercise(name: "Elevação Frontal", sets: 3, reps: 12, weight: 5, restSeconds: 40, muscleGroup: .shoulders),
                    Exercise(name: "Crucifixo Inverso", sets: 3, reps: 15, weight: 5, restSeconds: 40, muscleGroup: .shoulders),
                    Exercise(name: "Puxada Frontal", sets: 3, reps: 12, weight: 25, restSeconds: 55, muscleGroup: .back),
                    Exercise(name: "Agachamento Livre", sets: 3, reps: 12, weight: 25, restSeconds: 50, muscleGroup: .legs)
                ]
            )
        ]
    ]

    private static func sheet(
        title: String,
        description: String,
        gender: Gender,
        warmup: GuidedWorkoutCatalog.WarmupStyle,
        abs: GuidedWorkoutCatalog.AbsPair,
        main: [Exercise]
    ) -> WorkoutSheet {
        WorkoutSheet(
            title: title,
            description: description,
            exercises: GuidedWorkoutCatalog.withWarmupAndAbs(
                main,
                level: .intermediate,
                warmup: warmup,
                abs: abs
            ),
            targetGender: gender
        )
    }
}
