import Foundation

enum ExerciseGifCatalog {
    /// ExerciseGymGifsDB — 1.300+ GIFs demonstrativos via jsDelivr CDN.
    /// Poucos arquivos são rotulados como `*-female`; quando o programa é feminino,
    /// priorizamos esses e variantes mais alinhadas a glúteos/pernas.
    static let cdnBaseURL = "https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/"

    static func gifURL(for exercise: Exercise, preferredGender: Gender? = nil) -> URL? {
        remoteGifURL(for: exercise, preferredGender: preferredGender)
            ?? bundledGifURL(for: exercise)
    }

    static func remoteGifURL(for exercise: Exercise, preferredGender: Gender? = nil) -> URL? {
        remoteGifURL(
            forExerciseName: exercise.name,
            muscleGroup: exercise.muscleGroup,
            preferredGender: preferredGender
        )
    }

    static func remoteGifURL(
        forExerciseName name: String,
        muscleGroup: MuscleGroup,
        preferredGender: Gender? = nil
    ) -> URL? {
        guard let filePath = filePath(
            forExerciseName: name,
            muscleGroup: muscleGroup,
            preferredGender: preferredGender
        ) else {
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

    static func filePath(
        forExerciseName name: String,
        muscleGroup: MuscleGroup,
        preferredGender: Gender? = nil
    ) -> String? {
        if preferredGender == .female, let female = femaleExerciseFilePaths[name] {
            return female
        }

        if let exact = exerciseFilePaths[name] {
            return exact
        }

        let normalized = name
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))

        if preferredGender == .female {
            for rule in femaleKeywordFilePaths {
                if rule.keywords.contains(where: { normalized.contains($0) }) {
                    return rule.filePath
                }
            }
        }

        for rule in keywordFilePaths {
            if rule.keywords.contains(where: { normalized.contains($0) }) {
                return rule.filePath
            }
        }

        if preferredGender == .female, let fallback = femaleGroupFallbackFilePaths[muscleGroup] {
            return fallback
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
        (["hip thrust", "elevacao pelvica", "elevação pélvica"], "glutes/resistance-band-hip-thrusts-on-knees-female.gif"),
        (["agachamento sumo", "agachamento sumô"], "glutes/smith-sumo-squat.gif"),
        (["afundo bulgaro", "afundo búlgaro"], "quads/dumbbell-single-leg-split-squat.gif"),
        (["coice"], "glutes/cable-pull-through-with-rope.gif"),
        (["agachamento", "leg press", "hack"], "glutes/barbell-full-squat.gif"),
        (["extensora", "flexora", "stiff", "afundo", "adutora", "abdutora"], "quads/lever-leg-extension.gif"),
        (["panturrilha"], "calves/lever-standing-calf-raise.gif"),
        (["desenvolvimento", "elevacao", "elevação", "arnold"], "delts/dumbbell-lateral-raise.gif"),
        (["encolhimento"], "traps/barbell-shrug.gif"),
        (["face pull"], "delts/cable-standing-rear-delt-row-with-rope.gif"),
        (["abdominal", "prancha", "mountain", "russian", "bicicleta"], "abs/crunch.gif"),
        (["polichinelo", "jumping jack", "jack jump"], "cardio/jack-jump-male.gif"),
        (["ponte de gluteos", "ponte de glúteos", "glute bridge"], "glutes/low-glute-bridge-on-floor.gif"),
        (["superman", "hiperextensao", "hiperextensão"], "spine/hyperextension.gif"),
        (["isometria na parede", "wall sit", "sentar na parede"], "glutes/march-sit-wall.gif"),
        (["flexao diamante", "flexão diamante", "diamond"], "triceps/diamond-push-up.gif"),
        (["flexao inclinada", "flexão inclinada"], "pectorals/incline-push-up.gif"),
        (["panturrilha corporal"], "calves/bodyweight-standing-calf-raise.gif"),
        (["circulos de tornozelo", "círculos de tornozelo", "ankle"], "calves/ankle-circles.gif"),
        (["circulos de punho", "círculos de punho", "wrist"], "forearms/wrist-circles.gif"),
        (["inchworm", "lagarta"], "abs/inchworm.gif"),
        (["alongamento mundial", "world greatest"], "hamstrings/world-greatest-stretch.gif"),
        (["alongamento de coluna", "spine stretch"], "spine/spine-stretch.gif"),
        (["alongamento de costas", "upper back stretch"], "upper-back/upper-back-stretch.gif"),
        (["alongamento de panturrilha", "calf stretch"], "calves/calf-stretch-with-hands-against-wall.gif"),
        (["alongamento de peito", "chest stretch"], "pectorals/chest-and-front-of-shoulder-stretch.gif"),
        (["peitoral atras", "peitoral atrás"], "pectorals/behind-head-chest-stretch.gif"),
        (["deltoide posterior", "rear deltoid"], "delts/rear-deltoid-stretch.gif"),
        (["alongamento de triceps", "alongamento de tríceps"], "triceps/overhead-triceps-stretch.gif"),
        (["alongamento de dorsal", "lat stretch"], "lats/kneeling-lat-stretch.gif"),
        (["alongamento de pescoco", "alongamento de pescoço", "neck"], "levator-scapulae/neck-side-stretch.gif"),
        (["flexor de quadril", "hip flexor"], "quads/intermediate-hip-flexor-and-quad-stretch.gif"),
        (["alongamento de posterior", "hamstring"], "hamstrings/hamstring-stretch.gif"),
        (["alongamento de gluteo", "alongamento de glúteo"], "glutes/seated-glute-stretch.gif"),
        (["piriforme"], "glutes/seated-piriformis-stretch.gif"),
        (["borboleta", "addutor"], "adductors/butterfly-yoga-pose.gif"),
        (["escapula na barra", "escápula na barra", "scapular"], "traps/scapular-pull-up.gif"),
        (["burpee", "thruster", "kettlebell", "farmer", "terra"], "glutes/barbell-deadlift.gif"),
    ]

    /// GIFs rotulados `*-female` no CDN + variantes com foco em glúteos/pernas.
    private static let femaleExerciseFilePaths: [String: String] = [
        "Elevação Pélvica (Hip Thrust)": "glutes/resistance-band-hip-thrusts-on-knees-female.gif",
        "Agachamento Sumô": "glutes/smith-sumo-squat.gif",
        "Afundo Búlgaro": "quads/dumbbell-single-leg-split-squat.gif",
        "Coice na Polia": "glutes/cable-pull-through-with-rope.gif",
        "Stiff": "glutes/barbell-romanian-deadlift.gif",
        "Afundo": "glutes/dumbbell-lunge.gif",
        "Cadeira Abdutora": "abductors/lever-seated-hip-abduction.gif",
        "Cadeira Adutora": "adductors/lever-seated-hip-adduction.gif",
        "Agachamento Livre": "glutes/barbell-full-squat.gif",
        "Leg Press 45°": "glutes/sled-45-leg-press.gif",
        "Elevação de Pernas": "abs/twisted-leg-raise-female.gif",
        "Abdominal Infra": "abs/barbell-sitted-alternate-leg-raise-female.gif",
        "Abdominal Oblíquo": "abs/twisted-leg-raise-female.gif",
        "Remada Unilateral": "upper-back/dumbbell-reverse-grip-row-female.gif",
        "Remada Curvada": "upper-back/dumbbell-reverse-grip-row-female.gif",
        "Kettlebell Swing": "glutes/kettlebell-swing.gif",
    ]

    private static let femaleKeywordFilePaths: [(keywords: [String], filePath: String)] = [
        (["hip thrust", "elevacao pelvica", "elevação pélvica", "glute bridge"], "glutes/resistance-band-hip-thrusts-on-knees-female.gif"),
        (["sumo"], "glutes/smith-sumo-squat.gif"),
        (["bulgaro", "búlgaro", "split squat"], "quads/dumbbell-single-leg-split-squat.gif"),
        (["coice", "kickback gluteo", "kickback glúteo"], "glutes/cable-pull-through-with-rope.gif"),
        (["elevacao de pernas", "elevação de pernas"], "abs/twisted-leg-raise-female.gif"),
        (["abdominal infra"], "abs/barbell-sitted-alternate-leg-raise-female.gif"),
        (["obliquo", "oblíquo"], "abs/twisted-leg-raise-female.gif"),
        (["remada"], "upper-back/dumbbell-reverse-grip-row-female.gif"),
    ]

    private static let femaleGroupFallbackFilePaths: [MuscleGroup: String] = [
        .chest: "pectorals/push-up.gif",
        .back: "upper-back/dumbbell-reverse-grip-row-female.gif",
        .legs: "glutes/resistance-band-hip-thrusts-on-knees-female.gif",
        .shoulders: "delts/dumbbell-lateral-raise.gif",
        .arms: "biceps/dumbbell-hammer-curl.gif",
        .core: "abs/twisted-leg-raise-female.gif",
        .fullBody: "glutes/kettlebell-swing.gif",
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
        "Elevação Pélvica (Hip Thrust)": "glutes/resistance-band-hip-thrusts-on-knees-female.gif",
        "Agachamento Sumô": "glutes/smith-sumo-squat.gif",
        "Afundo Búlgaro": "quads/dumbbell-single-leg-split-squat.gif",
        "Coice na Polia": "glutes/cable-pull-through-with-rope.gif",
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
        "Polichinelo": "cardio/jack-jump-male.gif",
        "Ponte de Glúteos": "glutes/low-glute-bridge-on-floor.gif",
        "Superman": "spine/hyperextension.gif",
        "Isometria na Parede": "glutes/march-sit-wall.gif",
        "Flexão Diamante": "triceps/diamond-push-up.gif",
        "Flexão Inclinada": "pectorals/incline-push-up.gif",
        "Panturrilha Corporal": "calves/bodyweight-standing-calf-raise.gif",
        "Círculos de Tornozelo": "calves/ankle-circles.gif",
        "Círculos de Punho": "forearms/wrist-circles.gif",
        "Inchworm": "abs/inchworm.gif",
        "Alongamento Mundial": "hamstrings/world-greatest-stretch.gif",
        "Alongamento de Coluna": "spine/spine-stretch.gif",
        "Alongamento de Costas Altas": "upper-back/upper-back-stretch.gif",
        "Alongamento de Panturrilha": "calves/calf-stretch-with-hands-against-wall.gif",
        "Alongamento de Peito": "pectorals/chest-and-front-of-shoulder-stretch.gif",
        "Alongamento Peitoral Atrás da Cabeça": "pectorals/behind-head-chest-stretch.gif",
        "Alongamento de Deltoide Posterior": "delts/rear-deltoid-stretch.gif",
        "Alongamento de Tríceps": "triceps/overhead-triceps-stretch.gif",
        "Alongamento de Dorsal": "lats/kneeling-lat-stretch.gif",
        "Alongamento de Pescoço": "levator-scapulae/neck-side-stretch.gif",
        "Alongamento de Flexor de Quadril": "quads/intermediate-hip-flexor-and-quad-stretch.gif",
        "Alongamento de Posterior": "hamstrings/hamstring-stretch.gif",
        "Alongamento de Glúteo": "glutes/seated-glute-stretch.gif",
        "Alongamento de Piriforme": "glutes/seated-piriformis-stretch.gif",
        "Borboleta (Addutores)": "adductors/butterfly-yoga-pose.gif",
        "Escápula na Barra": "traps/scapular-pull-up.gif",
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

    func demoGifURL(preferredGender: Gender?) -> URL? {
        ExerciseGifCatalog.gifURL(for: self, preferredGender: preferredGender)
    }
}
