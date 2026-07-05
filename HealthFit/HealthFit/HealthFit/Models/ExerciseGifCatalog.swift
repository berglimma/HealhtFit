import Foundation

enum ExerciseGifCatalog {
    static let cdnBaseURL = "https://static.exercisedb.dev/media/"

    static func gifURL(for exercise: Exercise) -> URL? {
        gifURL(forExerciseName: exercise.name, muscleGroup: exercise.muscleGroup)
    }

    static func gifURL(forExerciseName name: String, muscleGroup: MuscleGroup) -> URL? {
        guard let mediaId = mediaId(forExerciseName: name, muscleGroup: muscleGroup) else {
            return nil
        }
        return URL(string: "\(cdnBaseURL)\(mediaId).gif")
    }

    static func mediaId(forExerciseName name: String, muscleGroup: MuscleGroup) -> String? {
        if let exact = mediaIds[name] {
            return exact
        }

        let normalized = name.lowercased()
        for rule in keywordRules {
            if rule.keywords.contains(where: { normalized.contains($0) }) {
                return rule.mediaId
            }
        }

        return groupFallbackMediaIds[muscleGroup]
    }

    private static let groupFallbackMediaIds: [MuscleGroup: String] = [
        .chest: "EIeI8Vf",
        .back: "eZyBC3j",
        .legs: "qXTaZnJ",
        .shoulders: "Xy4jlWA",
        .arms: "25GPyDY",
        .core: "hCjGsRQ",
        .fullBody: "ila4NZS",
    ]

    private static let keywordRules: [(keywords: [String], mediaId: String)] = [
        (["supino"], "EIeI8Vf"),
        (["crucifixo", "crossover"], "yz9nUhF"),
        (["flexão", "flexao"], "I4hDWkc"),
        (["tríceps", "triceps", "mergulho"], "ThKP69G"),
        (["rosca", "curl"], "25GPyDY"),
        (["remada", "row"], "eZyBC3j"),
        (["puxada", "pulldown", "barra fixa", "pull"], "LEprlgG"),
        (["agachamento", "squat", "leg press", "hack"], "qXTaZnJ"),
        (["extensora", "flexora", "stiff", "afundo", "adutora", "abdutora"], "my33uHU"),
        (["panturrilha", "calf"], "8ozhUIZ"),
        (["desenvolvimento", "elevação", "elevacao", "militar", "arnold"], "Xy4jlWA"),
        (["encolhimento"], "dG7tG5y"),
        (["face pull"], "wqNPGCg"),
        (["prancha", "plank"], "hCjGsRQ"),
        (["abdominal", "crunch", "infra", "oblíquo", "oblicuo"], "tZkGYZ9"),
        (["burpee", "thruster", "kettlebell", "farmer"], "dK9394r"),
        (["terra", "deadlift"], "ila4NZS"),
    ]

    private static let mediaIds: [String: String] = [
        "Supino Reto": "EIeI8Vf",
        "Supino Inclinado": "3TZduzM",
        "Supino Declinado": "GrO65fd",
        "Crucifixo Reto": "yz9nUhF",
        "Crucifixo Inclinado": "yz9nUhF",
        "Crossover": "OQ1otBN",
        "Flexão de Braços": "I4hDWkc",
        "Tríceps Pulley": "ThKP69G",
        "Tríceps Testa": "iZop9xO",
        "Tríceps Francês": "5uFK1xr",
        "Mergulho no Banco": "RrLske5",
        "Barra Fixa": "lBDjFxJ",
        "Remada Curvada": "eZyBC3j",
        "Puxada Frontal": "LEprlgG",
        "Remada Unilateral": "C0MA9bC",
        "Pulldown Triângulo": "4c9BhzB",
        "Levantamento Terra Romeno": "wQ2c4XD",
        "Puxada Alta": "LEprlgG",
        "Rosca Direta": "25GPyDY",
        "Rosca Martelo": "HPlPoQA",
        "Rosca Scott": "SYJ4Bkt",
        "Rosca Concentrada": "kmVVAfu",
        "Agachamento Livre": "qXTaZnJ",
        "Leg Press 45°": "V07qpXy",
        "Hack Squat": "5VCj6iH",
        "Cadeira Extensora": "my33uHU",
        "Mesa Flexora": "17lJ1kr",
        "Stiff": "wQ2c4XD",
        "Afundo": "py1HSzx",
        "Cadeira Adutora": "oHsrypV",
        "Cadeira Abdutora": "mQ1tBXn",
        "Panturrilha em Pé": "8ozhUIZ",
        "Panturrilha Sentado": "ipvgBnC",
        "Encolhimento com Barra": "dG7tG5y",
        "Desenvolvimento Militar": "ngPpyRS",
        "Elevação Lateral": "sTg7iys",
        "Remada Alta": "UDlhcO8",
        "Encolhimento com Halteres": "NJzBsGJ",
        "Elevação Frontal": "TFA88iB",
        "Crucifixo Inverso": "sTfvVsG",
        "Face Pull": "wqNPGCg",
        "Desenvolvimento com Halteres": "O8o7q4d",
        "Arnold Press": "Xy4jlWA",
        "Elevação Posterior": "sTfvVsG",
        "Elevação Lateral na Polia": "goJ6ezq",
        "Desenvolvimento na Máquina": "67n3r98",
        "Crucifixo Inverso no Cabo": "yUdIGNs",
        "Prancha": "hCjGsRQ",
        "Abdominal Crunch": "tZkGYZ9",
        "Abdominal Infra": "UGhRD1A",
        "Abdominal Oblíquo": "cJgSTmh",
        "Elevação de Pernas": "I3tsCnC",
        "Russian Twist": "XVDdcoj",
        "Mountain Climber": "RJgzwny",
        "Abdominal na Polia": "WW95auq",
        "Prancha Lateral": "5VXmnV5",
        "Bicicleta no Ar": "tZkGYZ9",
        "Burpee": "dK9394r",
        "Levantamento Terra": "ila4NZS",
        "Thruster": "f7Y9eDZ",
        "Kettlebell Swing": "UHJlbu3",
        "Farmer's Walk": "qPEzJjA",
    ]
}

extension Exercise {
    var demoGifURL: URL? {
        ExerciseGifCatalog.gifURL(for: self)
    }
}
