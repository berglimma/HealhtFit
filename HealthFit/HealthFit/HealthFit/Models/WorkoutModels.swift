import Foundation

struct Exercise: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var sets: Int
    var reps: Int
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

struct WorkoutSheet: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var description: String
    var exercises: [Exercise]
    var assignedTo: String?
    var createdAt: Date
    var isActive: Bool

    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        exercises: [Exercise] = [],
        assignedTo: String? = nil,
        createdAt: Date = .now,
        isActive: Bool = true
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.exercises = exercises
        self.assignedTo = assignedTo
        self.createdAt = createdAt
        self.isActive = isActive
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

    var id: UUID { exerciseId }

    init(
        exerciseId: UUID,
        exerciseName: String,
        elapsedSeconds: Int = 0,
        restSeconds: Int = 0,
        isCompleted: Bool = false
    ) {
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.elapsedSeconds = elapsedSeconds
        self.restSeconds = restSeconds
        self.isCompleted = isCompleted
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
        exerciseRecords: [ExerciseSessionRecord] = []
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
