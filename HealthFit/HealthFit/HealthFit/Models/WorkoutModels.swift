import Foundation

struct Exercise: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var sets: Int
    var reps: Int
    /// Carga recomendada na ficha (kg).
    var weight: Double?
    var restSeconds: Int
    var notes: String
    var muscleGroup: MuscleGroup

    init(
        id: UUID = UUID(),
        name: String,
        sets: Int = 3,
        reps: Int = 12,
        weight: Double? = nil,
        restSeconds: Int = 60,
        notes: String = "",
        muscleGroup: MuscleGroup = .chest
    ) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.restSeconds = restSeconds
        self.notes = notes
        self.muscleGroup = muscleGroup
    }

    var recommendedWeight: Double? {
        get { weight }
        set { weight = newValue }
    }

    var recommendedWeightLabel: String {
        guard let weight else { return "—" }
        return weight.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(weight)) kg"
            : String(format: "%.1f kg", weight)
    }
}

enum MuscleGroup: String, CaseIterable, Codable, Identifiable, Hashable {
    case chest = "Peito"
    case back = "Costas"
    case legs = "Pernas"
    case shoulders = "Ombros"
    case arms = "Braços"
    case core = "Abdômen"
    case fullBody = "Corpo Inteiro"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .chest: return "figure.arms.open"
        case .back: return "figure.climbing"
        case .legs: return "figure.run"
        case .shoulders: return "figure.boxing"
        case .arms: return "figure.strengthtraining.functional"
        case .core: return "figure.core.training"
        case .fullBody: return "figure.mixed.cardio"
        }
    }
}

enum CustomWorkoutFocusGroup: String, CaseIterable, Codable, Identifiable, Hashable {
    case chest = "Peito"
    case triceps = "Tríceps"
    case back = "Costas"
    case shoulders = "Ombros"
    case biceps = "Bíceps"
    case legs = "Pernas"
    case trapezius = "Trapézio"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .chest: return "figure.arms.open"
        case .triceps: return "figure.strengthtraining.traditional"
        case .back: return "figure.climbing"
        case .shoulders: return "figure.boxing"
        case .biceps: return "figure.strengthtraining.functional"
        case .legs: return "figure.run"
        case .trapezius: return "figure.walk"
        }
    }

    var bundleResourceName: String {
        switch self {
        case .chest: return "peito"
        case .triceps: return "triceps"
        case .back: return "costas"
        case .shoulders: return "ombros"
        case .biceps: return "biceps"
        case .legs: return "pernas"
        case .trapezius: return "trapezio"
        }
    }

    static func focusGroup(for exerciseName: String) -> CustomWorkoutFocusGroup? {
        if exerciseNames[exerciseName] != nil {
            return exerciseNames[exerciseName]
        }

        let normalized = exerciseName
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))

        if normalized.contains("triceps") || normalized.contains("tríceps") || normalized.contains("mergulho") {
            return .triceps
        }
        if normalized.contains("rosca") {
            return .biceps
        }
        if normalized.contains("encolhimento") || normalized.contains("remada alta") {
            return .trapezius
        }
        if normalized.contains("supino") || normalized.contains("crucifixo reto") || normalized.contains("crucifixo inclinado")
            || normalized.contains("crossover") || normalized.contains("flexao") || normalized.contains("flexão") {
            return .chest
        }
        if normalized.contains("desenvolvimento") || normalized.contains("elevacao") || normalized.contains("elevação")
            || normalized.contains("arnold") || normalized.contains("face pull") || normalized.contains("crucifixo inverso") {
            return .shoulders
        }
        if normalized.contains("agachamento") || normalized.contains("leg press") || normalized.contains("hack")
            || normalized.contains("extensora") || normalized.contains("flexora") || normalized.contains("stiff")
            || normalized.contains("afundo") || normalized.contains("adutora") || normalized.contains("abdutora")
            || normalized.contains("panturrilha") {
            return .legs
        }
        if normalized.contains("remada") || normalized.contains("puxada") || normalized.contains("barra fixa")
            || normalized.contains("pulldown") || normalized.contains("terra romeno") {
            return .back
        }
        return nil
    }

    private static let exerciseNames: [String: CustomWorkoutFocusGroup] = [
        "Supino Reto": .chest,
        "Supino Inclinado": .chest,
        "Supino Declinado": .chest,
        "Crucifixo Reto": .chest,
        "Crucifixo Inclinado": .chest,
        "Crossover": .chest,
        "Flexão de Braços": .chest,
        "Tríceps Pulley": .triceps,
        "Tríceps Testa": .triceps,
        "Tríceps Francês": .triceps,
        "Mergulho no Banco": .triceps,
        "Barra Fixa": .back,
        "Remada Curvada": .back,
        "Puxada Frontal": .back,
        "Remada Unilateral": .back,
        "Pulldown Triângulo": .back,
        "Levantamento Terra Romeno": .back,
        "Puxada Alta": .back,
        "Rosca Direta": .biceps,
        "Rosca Martelo": .biceps,
        "Rosca Scott": .biceps,
        "Rosca Concentrada": .biceps,
        "Agachamento Livre": .legs,
        "Leg Press 45°": .legs,
        "Hack Squat": .legs,
        "Cadeira Extensora": .legs,
        "Mesa Flexora": .legs,
        "Stiff": .legs,
        "Afundo": .legs,
        "Cadeira Adutora": .legs,
        "Cadeira Abdutora": .legs,
        "Panturrilha em Pé": .legs,
        "Panturrilha Sentado": .legs,
        "Encolhimento com Barra": .trapezius,
        "Desenvolvimento Militar": .shoulders,
        "Elevação Lateral": .shoulders,
        "Remada Alta": .trapezius,
        "Encolhimento com Halteres": .trapezius,
        "Elevação Frontal": .shoulders,
        "Crucifixo Inverso": .shoulders,
        "Face Pull": .shoulders,
        "Desenvolvimento com Halteres": .shoulders,
        "Arnold Press": .shoulders,
        "Elevação Posterior": .shoulders,
        "Elevação Lateral na Polia": .shoulders,
        "Desenvolvimento na Máquina": .shoulders,
        "Crucifixo Inverso no Cabo": .shoulders,
    ]
}

struct WorkoutSheet: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var description: String
    var exercises: [Exercise]
    var assignedTo: String?
    var createdAt: Date
    var isActive: Bool
    var isUserCreated: Bool
    /// Perfil do programa (masculino/feminino). Padrões e personalizados filtrados por isso.
    var targetGender: Gender?
    /// Ficha gerada pelo IAssistente (não criada manualmente em Nova Ficha).
    var createdByAssistant: Bool

    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        exercises: [Exercise] = [],
        assignedTo: String? = nil,
        createdAt: Date = .now,
        isActive: Bool = true,
        isUserCreated: Bool = false,
        targetGender: Gender? = nil,
        createdByAssistant: Bool = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.exercises = exercises
        self.assignedTo = assignedTo
        self.createdAt = createdAt
        self.isActive = isActive
        self.isUserCreated = isUserCreated
        self.targetGender = targetGender ?? Self.inferredGender(from: title)
        self.createdByAssistant = createdByAssistant
    }

    enum CodingKeys: String, CodingKey {
        case id, title, description, exercises, assignedTo, createdAt, isActive, isUserCreated, targetGender, createdByAssistant
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        exercises = try container.decode([Exercise].self, forKey: .exercises)
        assignedTo = try container.decodeIfPresent(String.self, forKey: .assignedTo)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        isUserCreated = try container.decodeIfPresent(Bool.self, forKey: .isUserCreated) ?? false
        targetGender = try container.decodeIfPresent(Gender.self, forKey: .targetGender)
            ?? Self.inferredGender(from: title)
        createdByAssistant = try container.decodeIfPresent(Bool.self, forKey: .createdByAssistant) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(exercises, forKey: .exercises)
        try container.encodeIfPresent(assignedTo, forKey: .assignedTo)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(isUserCreated, forKey: .isUserCreated)
        try container.encodeIfPresent(targetGender, forKey: .targetGender)
        try container.encode(createdByAssistant, forKey: .createdByAssistant)
    }

    var resolvedProgramGender: Gender? {
        targetGender ?? Self.inferredGender(from: title)
    }

    private static func inferredGender(from title: String) -> Gender? {
        let lower = title.lowercased()
        if lower.hasPrefix("masculino") { return .male }
        if lower.hasPrefix("feminino") { return .female }
        return nil
    }

    var totalExercises: Int { exercises.count }
    var estimatedDuration: Int {
        exercises.reduce(0) { $0 + ($1.sets * 45) + ($1.sets * $1.restSeconds) }
    }
}

struct ExerciseSessionRecord: Identifiable, Codable, Hashable {
    var exerciseId: UUID
    var exerciseName: String
    var elapsedSeconds: Int
    var restSeconds: Int
    var isCompleted: Bool
    var completedSets: Int
    var recommendedWeight: Double?
    var performedWeight: Double?

    var id: UUID { exerciseId }

    init(
        exerciseId: UUID,
        exerciseName: String,
        elapsedSeconds: Int = 0,
        restSeconds: Int = 0,
        isCompleted: Bool = false,
        completedSets: Int = 0,
        recommendedWeight: Double? = nil,
        performedWeight: Double? = nil
    ) {
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.elapsedSeconds = elapsedSeconds
        self.restSeconds = restSeconds
        self.isCompleted = isCompleted
        self.completedSets = max(0, completedSets)
        self.recommendedWeight = recommendedWeight
        self.performedWeight = performedWeight
    }

    enum CodingKeys: String, CodingKey {
        case exerciseId, exerciseName, elapsedSeconds, restSeconds, isCompleted
        case completedSets, recommendedWeight, performedWeight
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exerciseId = try container.decode(UUID.self, forKey: .exerciseId)
        exerciseName = try container.decode(String.self, forKey: .exerciseName)
        elapsedSeconds = try container.decodeIfPresent(Int.self, forKey: .elapsedSeconds) ?? 0
        restSeconds = try container.decodeIfPresent(Int.self, forKey: .restSeconds) ?? 0
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        completedSets = try container.decodeIfPresent(Int.self, forKey: .completedSets) ?? 0
        recommendedWeight = try container.decodeIfPresent(Double.self, forKey: .recommendedWeight)
        performedWeight = try container.decodeIfPresent(Double.self, forKey: .performedWeight)
    }

    var weightComparisonLabel: String? {
        let recommended = recommendedWeight.map { formatKg($0) }
        let performed = performedWeight.map { formatKg($0) }
        switch (recommended, performed) {
        case let (rec?, perf?):
            return "Rec. \(rec) · Feita \(perf)"
        case let (rec?, nil):
            return "Rec. \(rec)"
        case let (nil, perf?):
            return "Feita \(perf)"
        default:
            return nil
        }
    }

    private func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) kg"
            : String(format: "%.1f kg", value)
    }
}

struct WorkoutSession: Identifiable, Codable {
    var id: UUID
    var workoutSheetId: UUID
    var workoutTitle: String
    var startedAt: Date
    var endedAt: Date?
    var heartRateSamples: [HeartRateSample]
    var caloriesBurned: Double
    var completedExercises: Int
    var totalExercises: Int
    var exerciseRecords: [ExerciseSessionRecord]
    var tookPreWorkout: Bool?
    var targetDistanceKm: Double?
    var completedDistanceKm: Double?
    var averagePaceSecondsPerKm: Int?
    var cardioIntensityLabel: String?
    var targetCalories: Int?
    /// Encerrado antes de concluir todos os exercícios.
    var endedEarly: Bool
    /// Motivo informado pelo aluno ao encerrar antecipadamente.
    var earlyEndJustification: String?
    /// Encerrado automaticamente por inatividade (mais de 2h30 sem finalizar).
    var autoEndedByInactivity: Bool

    init(
        id: UUID = UUID(),
        workoutSheetId: UUID,
        workoutTitle: String,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        heartRateSamples: [HeartRateSample] = [],
        caloriesBurned: Double = 0,
        completedExercises: Int = 0,
        totalExercises: Int = 0,
        exerciseRecords: [ExerciseSessionRecord] = [],
        tookPreWorkout: Bool? = nil,
        targetDistanceKm: Double? = nil,
        completedDistanceKm: Double? = nil,
        averagePaceSecondsPerKm: Int? = nil,
        cardioIntensityLabel: String? = nil,
        targetCalories: Int? = nil,
        endedEarly: Bool = false,
        earlyEndJustification: String? = nil,
        autoEndedByInactivity: Bool = false
    ) {
        self.id = id
        self.workoutSheetId = workoutSheetId
        self.workoutTitle = workoutTitle
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.heartRateSamples = heartRateSamples
        self.caloriesBurned = caloriesBurned
        self.completedExercises = completedExercises
        self.totalExercises = totalExercises
        self.exerciseRecords = exerciseRecords
        self.tookPreWorkout = tookPreWorkout
        self.targetDistanceKm = targetDistanceKm
        self.completedDistanceKm = completedDistanceKm
        self.averagePaceSecondsPerKm = averagePaceSecondsPerKm
        self.cardioIntensityLabel = cardioIntensityLabel
        self.targetCalories = targetCalories
        self.endedEarly = endedEarly
        self.earlyEndJustification = earlyEndJustification
        self.autoEndedByInactivity = autoEndedByInactivity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        workoutSheetId = try container.decode(UUID.self, forKey: .workoutSheetId)
        workoutTitle = try container.decode(String.self, forKey: .workoutTitle)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        heartRateSamples = try container.decodeIfPresent([HeartRateSample].self, forKey: .heartRateSamples) ?? []
        caloriesBurned = try container.decodeIfPresent(Double.self, forKey: .caloriesBurned) ?? 0
        completedExercises = try container.decodeIfPresent(Int.self, forKey: .completedExercises) ?? 0
        totalExercises = try container.decodeIfPresent(Int.self, forKey: .totalExercises) ?? 0
        exerciseRecords = try container.decodeIfPresent([ExerciseSessionRecord].self, forKey: .exerciseRecords) ?? []
        tookPreWorkout = try container.decodeIfPresent(Bool.self, forKey: .tookPreWorkout)
        targetDistanceKm = try container.decodeIfPresent(Double.self, forKey: .targetDistanceKm)
        completedDistanceKm = try container.decodeIfPresent(Double.self, forKey: .completedDistanceKm)
        averagePaceSecondsPerKm = try container.decodeIfPresent(Int.self, forKey: .averagePaceSecondsPerKm)
        cardioIntensityLabel = try container.decodeIfPresent(String.self, forKey: .cardioIntensityLabel)
        targetCalories = try container.decodeIfPresent(Int.self, forKey: .targetCalories)
        endedEarly = try container.decodeIfPresent(Bool.self, forKey: .endedEarly) ?? false
        earlyEndJustification = try container.decodeIfPresent(String.self, forKey: .earlyEndJustification)
        autoEndedByInactivity = try container.decodeIfPresent(Bool.self, forKey: .autoEndedByInactivity) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(workoutSheetId, forKey: .workoutSheetId)
        try container.encode(workoutTitle, forKey: .workoutTitle)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(endedAt, forKey: .endedAt)
        try container.encode(heartRateSamples, forKey: .heartRateSamples)
        try container.encode(caloriesBurned, forKey: .caloriesBurned)
        try container.encode(completedExercises, forKey: .completedExercises)
        try container.encode(totalExercises, forKey: .totalExercises)
        try container.encode(exerciseRecords, forKey: .exerciseRecords)
        try container.encodeIfPresent(tookPreWorkout, forKey: .tookPreWorkout)
        try container.encodeIfPresent(targetDistanceKm, forKey: .targetDistanceKm)
        try container.encodeIfPresent(completedDistanceKm, forKey: .completedDistanceKm)
        try container.encodeIfPresent(averagePaceSecondsPerKm, forKey: .averagePaceSecondsPerKm)
        try container.encodeIfPresent(cardioIntensityLabel, forKey: .cardioIntensityLabel)
        try container.encodeIfPresent(targetCalories, forKey: .targetCalories)
        try container.encode(endedEarly, forKey: .endedEarly)
        try container.encodeIfPresent(earlyEndJustification, forKey: .earlyEndJustification)
        try container.encode(autoEndedByInactivity, forKey: .autoEndedByInactivity)
    }

    private enum CodingKeys: String, CodingKey {
        case id, workoutSheetId, workoutTitle, startedAt, endedAt
        case heartRateSamples, caloriesBurned, completedExercises, totalExercises
        case exerciseRecords, tookPreWorkout
        case targetDistanceKm, completedDistanceKm, averagePaceSecondsPerKm, cardioIntensityLabel
        case targetCalories, endedEarly, earlyEndJustification, autoEndedByInactivity
    }

    var duration: TimeInterval {
        (endedAt ?? .now).timeIntervalSince(startedAt)
    }

    var averageHeartRate: Double {
        guard !heartRateSamples.isEmpty else { return 0 }
        return heartRateSamples.map(\.bpm).reduce(0, +) / Double(heartRateSamples.count)
    }

    var totalRestSeconds: Int {
        exerciseRecords.reduce(0) { $0 + $1.restSeconds }
    }

    var totalExerciseSeconds: Int {
        exerciseRecords.reduce(0) { $0 + $1.elapsedSeconds }
    }
}

enum DurationFormatting {
    static func format(seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

/// Contagem de séries no formato "1/1 de 3", "1/2 de 3", "3/3 de 3".
enum SetProgressFormatting {
    /// Série em andamento (1-based). Com todas concluídas, retorna o total.
    static func currentSet(completed: Int, totalSets: Int) -> Int {
        let total = max(totalSets, 1)
        let done = min(max(completed, 0), total)
        if done >= total { return total }
        return done + 1
    }

    /// Ex.: total 3 → "1/1 de 3", "1/2 de 3", "3/3 de 3".
    /// Total 4/5 segue o mesmo modelo (na última: "4/4 de 4", "5/5 de 5").
    static func progressLabel(completed: Int, totalSets: Int) -> String {
        let total = max(totalSets, 1)
        let done = min(max(completed, 0), total)
        if done >= total {
            return "\(total)/\(total) de \(total)"
        }
        let current = done + 1
        if done == 0 {
            return "1/1 de \(total)"
        }
        if current == total {
            return "\(total)/\(total) de \(total)"
        }
        return "\(done)/\(current) de \(total)"
    }

    static func isLastSet(completed: Int, totalSets: Int) -> Bool {
        let total = max(totalSets, 1)
        let done = min(max(completed, 0), total)
        return done >= total - 1
    }
}

struct HeartRateSample: Identifiable, Codable {
    var id: UUID
    var timestamp: Date
    var bpm: Double

    init(id: UUID = UUID(), timestamp: Date = .now, bpm: Double) {
        self.id = id
        self.timestamp = timestamp
        self.bpm = bpm
    }
}

struct DailyHealthMetric: Identifiable, Codable {
    var id: UUID
    var date: Date
    var steps: Int
    var activeCalories: Double
    var restingHeartRate: Double
    var workoutMinutes: Int

    init(
        id: UUID = UUID(),
        date: Date,
        steps: Int = 0,
        activeCalories: Double = 0,
        restingHeartRate: Double = 0,
        workoutMinutes: Int = 0
    ) {
        self.id = id
        self.date = date
        self.steps = steps
        self.activeCalories = activeCalories
        self.restingHeartRate = restingHeartRate
        self.workoutMinutes = workoutMinutes
    }
}
