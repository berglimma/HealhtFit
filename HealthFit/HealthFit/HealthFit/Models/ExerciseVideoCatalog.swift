import Foundation

struct ExerciseDemoVideo: Equatable {
    let exerciseName: String
    let title: String
    let storagePath: String
    var fallbackMuscleGroup: MuscleGroup?

    static func make(
        exerciseName: String,
        title: String,
        muscleGroup: MuscleGroup,
        usesGroupFallback: Bool = true
    ) -> ExerciseDemoVideo {
        ExerciseDemoVideo(
            exerciseName: exerciseName,
            title: title,
            storagePath: ExerciseVideoStorageService.storagePath(for: exerciseName, muscleGroup: muscleGroup),
            fallbackMuscleGroup: usesGroupFallback ? muscleGroup : nil
        )
    }

    static func groupFallback(for muscleGroup: MuscleGroup) -> ExerciseDemoVideo {
        ExerciseDemoVideo(
            exerciseName: muscleGroup.rawValue,
            title: "Demonstração — \(muscleGroup.rawValue)",
            storagePath: ExerciseVideoStorageService.groupStoragePath(for: muscleGroup),
            fallbackMuscleGroup: nil
        )
    }
}

enum ExerciseVideoCatalog {
    static func bundledVideos() -> [String: ExerciseDemoVideo] {
        videos
    }

    static func bundledKeywordRules() -> [(keywords: [String], video: ExerciseDemoVideo)] {
        keywordVideos
    }

    static func bundledMuscleGroupFallbacks() -> [MuscleGroup: ExerciseDemoVideo] {
        muscleGroupFallbacks
    }

    static func seedRecords() -> [ExerciseVideoRecord] {
        videos.map { exerciseName, video in
            ExerciseVideoRecord(
                exerciseName: exerciseName,
                title: video.title,
                keywords: keywords(for: exerciseName),
                muscleGroup: muscleGroup(for: exerciseName),
                storagePath: video.storagePath
            )
        }
    }

    static func localVideo(for exercise: Exercise) -> ExerciseDemoVideo? {
        if let exact = videos[exercise.name] {
            return exact
        }

        let normalized = exercise.name.lowercased()
        for rule in keywordVideos {
            if rule.keywords.contains(where: { normalized.contains($0) }) {
                return rule.video
            }
        }

        return muscleGroupFallbacks[exercise.muscleGroup]
    }

    private static func keywords(for exerciseName: String) -> [String] {
        let normalized = exerciseName.lowercased()
        return keywordVideos
            .filter { rule in rule.keywords.contains { normalized.contains($0) } }
            .flatMap(\.keywords)
    }

    private static func muscleGroup(for exerciseName: String) -> String {
        inferredMuscleGroup(for: exerciseName).rawValue
    }

    private static func inferredMuscleGroup(for exerciseName: String) -> MuscleGroup {
        let normalized = exerciseName.lowercased()
        if normalized.contains("supino") || normalized.contains("crucifixo") || normalized.contains("crossover") || normalized.contains("flexão") || normalized.contains("flexao") {
            return .chest
        }
        if normalized.contains("rosca") || normalized.contains("tríceps") || normalized.contains("triceps") || normalized.contains("mergulho") {
            return .arms
        }
        if normalized.contains("remada") || normalized.contains("puxada") || normalized.contains("barra fixa") || normalized.contains("face pull") || normalized.contains("encolhimento") {
            return .back
        }
        if normalized.contains("agachamento") || normalized.contains("leg press") || normalized.contains("hack") || normalized.contains("extensora") || normalized.contains("flexora") || normalized.contains("stiff") || normalized.contains("afundo") || normalized.contains("panturrilha") {
            return .legs
        }
        if normalized.contains("desenvolvimento") || normalized.contains("elevação") || normalized.contains("elevacao") || normalized.contains("arnold") {
            return .shoulders
        }
        if normalized.contains("abdominal") || normalized.contains("prancha") || normalized.contains("mountain") || normalized.contains("russian") {
            return .core
        }
        return .fullBody
    }

    private static func entry(_ name: String, _ title: String, _ group: MuscleGroup) -> (String, ExerciseDemoVideo) {
        (name, .make(exerciseName: name, title: title, muscleGroup: group))
    }

    private static let videos: [String: ExerciseDemoVideo] = Dictionary(uniqueKeysWithValues: [
        entry("Supino Reto", "Supino reto com barra", .chest),
        entry("Supino Inclinado", "Supino inclinado", .chest),
        entry("Supino Declinado", "Supino declinado", .chest),
        entry("Crucifixo Reto", "Crucifixo com halteres", .chest),
        entry("Crucifixo Inclinado", "Crucifixo inclinado", .chest),
        entry("Crossover", "Crossover na polia", .chest),
        entry("Flexão de Braços", "Flexão de braços", .chest),
        entry("Tríceps Pulley", "Tríceps na polia", .arms),
        entry("Tríceps Testa", "Tríceps testa", .arms),
        entry("Tríceps Francês", "Tríceps francês", .arms),
        entry("Mergulho no Banco", "Mergulho no banco", .arms),
        entry("Barra Fixa", "Barra fixa", .back),
        entry("Remada Curvada", "Remada curvada", .back),
        entry("Puxada Frontal", "Puxada frontal", .back),
        entry("Remada Unilateral", "Remada unilateral", .back),
        entry("Pulldown Triângulo", "Puxada com triângulo", .back),
        entry("Levantamento Terra Romeno", "Levantamento terra romeno", .back),
        entry("Puxada Alta", "Puxada alta", .back),
        entry("Rosca Direta", "Rosca direta", .arms),
        entry("Rosca Martelo", "Rosca martelo", .arms),
        entry("Rosca Scott", "Rosca Scott", .arms),
        entry("Rosca Concentrada", "Rosca concentrada", .arms),
        entry("Agachamento Livre", "Agachamento livre", .legs),
        entry("Leg Press 45°", "Leg press", .legs),
        entry("Hack Squat", "Hack squat", .legs),
        entry("Cadeira Extensora", "Cadeira extensora", .legs),
        entry("Mesa Flexora", "Mesa flexora", .legs),
        entry("Stiff", "Stiff", .legs),
        entry("Afundo", "Afundo", .legs),
        entry("Cadeira Adutora", "Cadeira adutora", .legs),
        entry("Cadeira Abdutora", "Cadeira abdutora", .legs),
        entry("Panturrilha em Pé", "Panturrilha em pé", .legs),
        entry("Panturrilha Sentado", "Panturrilha sentado", .legs),
        entry("Encolhimento com Barra", "Encolhimento com barra", .back),
        entry("Desenvolvimento Militar", "Desenvolvimento militar", .shoulders),
        entry("Elevação Lateral", "Elevação lateral", .shoulders),
        entry("Remada Alta", "Remada alta", .shoulders),
        entry("Encolhimento com Halteres", "Encolhimento com halteres", .back),
        entry("Elevação Frontal", "Elevação frontal", .shoulders),
        entry("Crucifixo Inverso", "Crucifixo inverso", .back),
        entry("Face Pull", "Face pull", .back),
        entry("Desenvolvimento com Halteres", "Desenvolvimento com halteres", .shoulders),
        entry("Arnold Press", "Arnold press", .shoulders),
        entry("Elevação Posterior", "Elevação posterior", .shoulders),
        entry("Elevação Lateral na Polia", "Elevação lateral na polia", .shoulders),
        entry("Desenvolvimento na Máquina", "Desenvolvimento na máquina", .shoulders),
        entry("Crucifixo Inverso no Cabo", "Crucifixo inverso no cabo", .shoulders),
        entry("Prancha", "Prancha", .core),
        entry("Abdominal Crunch", "Abdominal crunch", .core),
        entry("Abdominal Infra", "Abdominal infra", .core),
        entry("Abdominal Oblíquo", "Abdominal oblíquo", .core),
        entry("Elevação de Pernas", "Elevação de pernas", .core),
        entry("Russian Twist", "Russian twist", .core),
        entry("Mountain Climber", "Mountain climber", .core),
        entry("Abdominal na Polia", "Abdominal na polia", .core),
        entry("Prancha Lateral", "Prancha lateral", .core),
        entry("Bicicleta no Ar", "Bicicleta no ar", .core),
        entry("Burpee", "Burpee", .fullBody),
        entry("Levantamento Terra", "Levantamento terra", .fullBody),
        entry("Thruster", "Thruster", .fullBody),
        entry("Kettlebell Swing", "Kettlebell swing", .fullBody),
        entry("Farmer's Walk", "Farmer's walk", .fullBody),
    ])

    private static let keywordVideos: [(keywords: [String], video: ExerciseDemoVideo)] = [
        (["supino"], .groupFallback(for: .chest)),
        (["crucifixo", "crossover"], .groupFallback(for: .chest)),
        (["flexão", "flexao"], .groupFallback(for: .chest)),
        (["tríceps", "triceps", "mergulho"], .groupFallback(for: .arms)),
        (["rosca", "curl"], .groupFallback(for: .arms)),
        (["remada", "row"], .groupFallback(for: .back)),
        (["puxada", "pulldown", "barra fixa", "pull"], .groupFallback(for: .back)),
        (["agachamento", "squat", "leg press", "hack"], .groupFallback(for: .legs)),
        (["extensora", "flexora", "stiff", "afundo", "adutora", "abdutora"], .groupFallback(for: .legs)),
        (["panturrilha", "calf"], .groupFallback(for: .legs)),
        (["desenvolvimento", "elevação", "elevacao", "militar", "arnold"], .groupFallback(for: .shoulders)),
        (["encolhimento"], .groupFallback(for: .back)),
        (["face pull"], .groupFallback(for: .back)),
        (["prancha", "plank"], .groupFallback(for: .core)),
        (["abdominal", "crunch", "infra", "oblíquo", "oblicuo"], .groupFallback(for: .core)),
        (["burpee", "thruster", "kettlebell", "farmer"], .groupFallback(for: .fullBody)),
        (["terra", "deadlift"], .groupFallback(for: .fullBody)),
    ]

    private static let muscleGroupFallbacks: [MuscleGroup: ExerciseDemoVideo] = [
        .chest: .groupFallback(for: .chest),
        .back: .groupFallback(for: .back),
        .legs: .groupFallback(for: .legs),
        .shoulders: .groupFallback(for: .shoulders),
        .arms: .groupFallback(for: .arms),
        .core: .groupFallback(for: .core),
        .fullBody: .groupFallback(for: .fullBody),
    ]
}

extension Exercise {
    @MainActor
    var demoVideo: ExerciseDemoVideo? {
        ExerciseVideoRepository.shared.video(for: self)
    }
}
