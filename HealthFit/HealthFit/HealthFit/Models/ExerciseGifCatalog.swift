import Foundation

enum ExerciseGifCatalog {
    /// ExerciseGymGifsDB — 1.300+ GIFs demonstrativos via jsDelivr CDN.
    static let cdnBaseURL = "https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/"

    static func gifURL(for exercise: Exercise) -> URL? {
        remoteGifURL(for: exercise) ?? bundledGifURL(for: exercise)
    }

    static func remoteGifURL(for exercise: Exercise) -> URL? {
        remoteGifURL(forExerciseName: exercise.name, muscleGroup: exercise.muscleGroup)
    }

    static func remoteGifURL(forExerciseName name: String, muscleGroup: MuscleGroup) -> URL? {
        guard let filePath = filePath(forExerciseName: name, muscleGroup: muscleGroup) else {
            return nil
        }
        return URL(string: "\(cdnBaseURL)\(filePath)")
    }

    static func bundledGifURL(for exercise: Exercise) -> URL? {
        let resourceName = bundleResourceName(forExerciseName: exercise.name, muscleGroup: exercise.muscleGroup)
        return bundleURL(forResourceName: resourceName)
    }

    static func bundleResourceName(forExerciseName name: String, muscleGroup: MuscleGroup) -> String {
        if let focus = CustomWorkoutFocusGroup.focusGroup(for: name) {
            return focus.bundleResourceName
        }
        return muscleGroup.bundleResourceName
    }

    static func filePath(forExerciseName name: String, muscleGroup: MuscleGroup) -> String? {
        if let exact = exerciseFilePaths[name] {
            return exact
        }

        let normalized = name
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))

        for rule in keywordFilePaths {
            if rule.keywords.contains(where: { normalized.contains($0) }) {
                return rule.filePath
            }
        }

        return groupFallbackFilePaths[muscleGroup]
    }

    private static func bundleURL(forResourceName name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "gif", subdirectory: "ExerciseGifs")
            ?? Bundle.main.url(forResource: name, withExtension: "gif")
    }

    private static let groupFallbackFilePaths: [MuscleGroup: String] = [
        .chest: "pectorals/barbell-bench-press.gif",
        .back: "upper-back/barbell-bent-over-row.gif",
        .legs: "glutes/barbell-full-squat.gif",
        .shoulders: "delts/dumbbell-lateral-raise.gif",
        .arms: "biceps/barbell-curl.gif",
        .core: "abs/crunch.gif",
        .fullBody: "glutes/barbell-deadlift.gif",
    ]

    private static let keywordFilePaths: [(keywords: [String], filePath: String)] = [
        (["supino reto"], "pectorals/barbell-bench-press.gif"),
        (["supino inclinado"], "pectorals/barbell-incline-bench-press.gif"),
        (["supino declinado"], "pectorals/barbell-decline-bench-press.gif"),
        (["crucifixo"], "pectorals/dumbbell-fly.gif"),
        (["crossover"], "pectorals/cable-standing-up-straight-crossovers.gif"),
        (["flexao", "flexão"], "pectorals/push-up.gif"),
        (["triceps pulley", "tríceps pulley"], "triceps/cable-pushdown.gif"),
        (["triceps testa", "tríceps testa"], "triceps/barbell-lying-triceps-extension-skull-crusher.gif"),
        (["triceps frances", "tríceps francês"], "triceps/cable-overhead-triceps-extension-rope-attachment.gif"),
        (["mergulho"], "triceps/bench-dip-knees-bent.gif"),
        (["rosca"], "biceps/barbell-curl.gif"),
        (["remada"], "upper-back/barbell-bent-over-row.gif"),
        (["puxada", "pulldown", "barra fixa"], "lats/cable-pulldown.gif"),
        (["agachamento", "leg press", "hack"], "glutes/barbell-full-squat.gif"),
        (["extensora", "flexora", "stiff", "afundo", "adutora", "abdutora"], "quads/lever-leg-extension.gif"),
        (["panturrilha"], "calves/lever-standing-calf-raise.gif"),
        (["desenvolvimento", "elevacao", "elevação", "arnold"], "delts/dumbbell-lateral-raise.gif"),
        (["encolhimento"], "traps/barbell-shrug.gif"),
        (["face pull"], "delts/cable-standing-rear-delt-row-with-rope.gif"),
        (["abdominal", "prancha", "mountain", "russian"], "abs/crunch.gif"),
        (["burpee", "thruster", "kettlebell", "farmer", "terra"], "glutes/barbell-deadlift.gif"),
    ]

    private static let exerciseFilePaths: [String: String] = [
        "Supino Reto": "pectorals/barbell-bench-press.gif",
        "Supino Inclinado": "pectorals/barbell-incline-bench-press.gif",
        "Supino Declinado": "pectorals/barbell-decline-bench-press.gif",
        "Crucifixo Reto": "pectorals/dumbbell-fly.gif",
        "Crucifixo Inclinado": "pectorals/dumbbell-incline-fly.gif",
        "Crossover": "pectorals/cable-standing-up-straight-crossovers.gif",
        "Flexão de Braços": "pectorals/push-up.gif",
        "Tríceps Pulley": "triceps/cable-pushdown.gif",
        "Tríceps Testa": "triceps/barbell-lying-triceps-extension-skull-crusher.gif",
        "Tríceps Francês": "triceps/cable-overhead-triceps-extension-rope-attachment.gif",
        "Mergulho no Banco": "triceps/bench-dip-knees-bent.gif",
        "Barra Fixa": "lats/pull-up.gif",
        "Remada Curvada": "upper-back/barbell-bent-over-row.gif",
        "Puxada Frontal": "lats/cable-pulldown.gif",
        "Remada Unilateral": "upper-back/dumbbell-bent-over-row.gif",
        "Pulldown Triângulo": "lats/cable-pulldown.gif",
        "Levantamento Terra Romeno": "glutes/barbell-romanian-deadlift.gif",
        "Puxada Alta": "lats/cable-lat-pulldown-full-range-of-motion.gif",
        "Rosca Direta": "biceps/barbell-curl.gif",
        "Rosca Martelo": "biceps/dumbbell-hammer-curl.gif",
        "Rosca Scott": "biceps/barbell-lying-preacher-curl.gif",
        "Rosca Concentrada": "biceps/dumbbell-concentration-curl.gif",
        "Agachamento Livre": "glutes/barbell-full-squat.gif",
        "Leg Press 45°": "glutes/sled-45-leg-press.gif",
        "Hack Squat": "glutes/sled-hack-squat.gif",
        "Cadeira Extensora": "quads/lever-leg-extension.gif",
        "Mesa Flexora": "hamstrings/lever-lying-leg-curl.gif",
        "Stiff": "glutes/barbell-romanian-deadlift.gif",
        "Afundo": "glutes/dumbbell-lunge.gif",
        "Cadeira Adutora": "adductors/lever-seated-hip-adduction.gif",
        "Cadeira Abdutora": "abductors/lever-seated-hip-abduction.gif",
        "Panturrilha em Pé": "calves/lever-standing-calf-raise.gif",
        "Panturrilha Sentado": "calves/lever-seated-calf-raise.gif",
        "Encolhimento com Barra": "traps/barbell-shrug.gif",
        "Desenvolvimento Militar": "delts/barbell-standing-wide-military-press.gif",
        "Elevação Lateral": "delts/dumbbell-lateral-raise.gif",
        "Remada Alta": "delts/barbell-upright-row.gif",
        "Encolhimento com Halteres": "traps/dumbbell-shrug.gif",
        "Elevação Frontal": "delts/barbell-front-raise.gif",
        "Crucifixo Inverso": "delts/dumbbell-reverse-fly.gif",
        "Face Pull": "delts/cable-standing-rear-delt-row-with-rope.gif",
        "Desenvolvimento com Halteres": "delts/dumbbell-seated-shoulder-press.gif",
        "Arnold Press": "delts/dumbbell-arnold-press.gif",
        "Elevação Posterior": "delts/dumbbell-rear-lateral-raise.gif",
        "Elevação Lateral na Polia": "delts/cable-lateral-raise.gif",
        "Desenvolvimento na Máquina": "delts/lever-shoulder-press.gif",
        "Crucifixo Inverso no Cabo": "delts/cable-rear-delt-row-with-rope.gif",
        "Prancha": "abs/front-plank-with-twist.gif",
        "Abdominal Crunch": "abs/band-bicycle-crunch.gif",
        "Abdominal Infra": "abs/assisted-lying-leg-raise-with-lateral-throw-down.gif",
        "Abdominal Oblíquo": "abs/russian-twist.gif",
        "Elevação de Pernas": "abs/hanging-leg-raise.gif",
        "Russian Twist": "abs/russian-twist.gif",
        "Mountain Climber": "cardio/mountain-climber.gif",
        "Abdominal na Polia": "abs/cable-kneeling-crunch.gif",
        "Prancha Lateral": "abs/bodyweight-incline-side-plank.gif",
        "Bicicleta no Ar": "abs/air-bike.gif",
        "Burpee": "cardio/burpee.gif",
        "Levantamento Terra": "glutes/barbell-deadlift.gif",
        "Thruster": "delts/barbell-thruster.gif",
        "Kettlebell Swing": "glutes/kettlebell-swing.gif",
        "Farmer's Walk": "quads/farmers-walk.gif",
    ]
}

extension MuscleGroup {
    var bundleResourceName: String {
        switch self {
        case .chest: return "peito"
        case .back: return "costas"
        case .legs: return "pernas"
        case .shoulders: return "ombros"
        case .arms: return "bracos"
        case .core: return "abdomen"
        case .fullBody: return "corpo_inteiro"
        }
    }
}

extension Exercise {
    var demoGifURL: URL? {
        ExerciseGifCatalog.gifURL(for: self)
    }
}
