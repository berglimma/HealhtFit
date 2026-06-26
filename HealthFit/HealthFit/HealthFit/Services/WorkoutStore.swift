import Foundation
import Combine

@MainActor
final class WorkoutStore: ObservableObject {
    @Published var workoutSheets: [WorkoutSheet] = []
    @Published var activeSession: WorkoutSession?
    @Published var sessionHistory: [WorkoutSession] = []
    @Published var currentExerciseIndex = 0

    private let storageKey = "healthfit_workout_sheets"
    private let historyKey = "healthfit_session_history"

    init() {
        loadData()
        if workoutSheets.isEmpty {
            workoutSheets = Self.sampleWorkouts
            saveData()
        } else {
            refreshSampleWorkoutsIfNeeded()
        }
    }

    func addWorkoutSheet(_ sheet: WorkoutSheet) {
        workoutSheets.append(sheet)
        saveData()
    }

    func updateWorkoutSheet(_ sheet: WorkoutSheet) {
        if let index = workoutSheets.firstIndex(where: { $0.id == sheet.id }) {
            workoutSheets[index] = sheet
            saveData()
        }
    }

    func deleteWorkoutSheet(_ sheet: WorkoutSheet) {
        workoutSheets.removeAll { $0.id == sheet.id }
        saveData()
    }

    func startSession(for sheet: WorkoutSheet) {
        activeSession = WorkoutSession(
            workoutSheetId: sheet.id,
            workoutTitle: sheet.title,
            totalExercises: sheet.exercises.count
        )
        currentExerciseIndex = 0
    }

    func completeExercise() {
        guard var session = activeSession else { return }
        session.completedExercises += 1
        activeSession = session

        if currentExerciseIndex < (workoutSheets.first { $0.id == session.workoutSheetId }?.exercises.count ?? 0) - 1 {
            currentExerciseIndex += 1
        }
    }

    func addHeartRateSample(_ bpm: Double) {
        guard var session = activeSession else { return }
        session.heartRateSamples.append(HeartRateSample(bpm: bpm))
        activeSession = session
    }

    func updateCalories(_ calories: Double) {
        guard var session = activeSession else { return }
        session.caloriesBurned = calories
        activeSession = session
    }

    func endSession() {
        guard var session = activeSession else { return }
        session.endedAt = .now
        sessionHistory.insert(session, at: 0)
        activeSession = nil
        currentExerciseIndex = 0
        saveHistory()
    }

    var currentExercise: Exercise? {
        guard let session = activeSession,
              let sheet = workoutSheets.first(where: { $0.id == session.workoutSheetId }),
              currentExerciseIndex < sheet.exercises.count else { return nil }
        return sheet.exercises[currentExerciseIndex]
    }

    private func saveData() {
        if let data = try? JSONEncoder().encode(workoutSheets) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let sheets = try? JSONDecoder().decode([WorkoutSheet].self, from: data) {
            workoutSheets = sheets
        }
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let history = try? JSONDecoder().decode([WorkoutSession].self, from: data) {
            sessionHistory = history
        }
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(sessionHistory) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    private func refreshSampleWorkoutsIfNeeded() {
        let sampleByTitle = Dictionary(uniqueKeysWithValues: Self.sampleWorkouts.map { ($0.title, $0) })
        var didUpdate = false

        workoutSheets = workoutSheets.map { sheet in
            guard let sample = sampleByTitle[sheet.title], sheet.exercises.count < 10 else {
                return sheet
            }
            didUpdate = true
            return WorkoutSheet(
                id: sheet.id,
                title: sheet.title,
                description: sample.description,
                exercises: sample.exercises,
                assignedTo: sheet.assignedTo,
                createdAt: sheet.createdAt,
                isActive: sheet.isActive
            )
        }

        let existingTitles = Set(workoutSheets.map(\.title))
        for sample in Self.sampleWorkouts where !existingTitles.contains(sample.title) {
            workoutSheets.append(sample)
            didUpdate = true
        }

        if didUpdate {
            saveData()
        }
    }

    static let sampleWorkouts: [WorkoutSheet] = [
        WorkoutSheet(
            title: "Treino A - Peito e Tríceps",
            description: "Foco em hipertrofia do peitoral e tríceps",
            exercises: [
                Exercise(name: "Supino Reto", sets: 4, reps: 10, weight: 60, restSeconds: 90, muscleGroup: .chest),
                Exercise(name: "Supino Inclinado", sets: 4, reps: 10, weight: 50, restSeconds: 90, muscleGroup: .chest),
                Exercise(name: "Supino Declinado", sets: 3, reps: 12, weight: 55, restSeconds: 75, muscleGroup: .chest),
                Exercise(name: "Crucifixo Reto", sets: 3, reps: 15, weight: 14, restSeconds: 60, muscleGroup: .chest),
                Exercise(name: "Crucifixo Inclinado", sets: 3, reps: 15, weight: 12, restSeconds: 60, muscleGroup: .chest),
                Exercise(name: "Crossover", sets: 3, reps: 15, weight: 10, restSeconds: 60, muscleGroup: .chest),
                Exercise(name: "Flexão de Braços", sets: 3, reps: 15, restSeconds: 60, muscleGroup: .chest),
                Exercise(name: "Tríceps Pulley", sets: 4, reps: 12, weight: 25, restSeconds: 60, muscleGroup: .arms),
                Exercise(name: "Tríceps Testa", sets: 3, reps: 12, weight: 20, restSeconds: 60, muscleGroup: .arms),
                Exercise(name: "Tríceps Francês", sets: 3, reps: 12, weight: 14, restSeconds: 60, muscleGroup: .arms),
                Exercise(name: "Mergulho no Banco", sets: 3, reps: 12, restSeconds: 60, muscleGroup: .arms)
            ]
        ),
        WorkoutSheet(
            title: "Treino B - Costas e Bíceps",
            description: "Desenvolvimento dorsal e bíceps completo",
            exercises: [
                Exercise(name: "Barra Fixa", sets: 4, reps: 8, restSeconds: 90, muscleGroup: .back),
                Exercise(name: "Remada Curvada", sets: 4, reps: 10, weight: 50, restSeconds: 75, muscleGroup: .back),
                Exercise(name: "Puxada Frontal", sets: 4, reps: 12, weight: 45, restSeconds: 75, muscleGroup: .back),
                Exercise(name: "Remada Unilateral", sets: 3, reps: 12, weight: 22, restSeconds: 60, muscleGroup: .back),
                Exercise(name: "Pulldown Triângulo", sets: 3, reps: 12, weight: 40, restSeconds: 60, muscleGroup: .back),
                Exercise(name: "Levantamento Terra Romeno", sets: 3, reps: 10, weight: 40, restSeconds: 90, muscleGroup: .back),
                Exercise(name: "Puxada Alta", sets: 3, reps: 15, weight: 30, restSeconds: 60, muscleGroup: .back),
                Exercise(name: "Rosca Direta", sets: 4, reps: 12, weight: 12, restSeconds: 60, muscleGroup: .arms),
                Exercise(name: "Rosca Martelo", sets: 3, reps: 12, weight: 10, restSeconds: 60, muscleGroup: .arms),
                Exercise(name: "Rosca Scott", sets: 3, reps: 12, weight: 10, restSeconds: 60, muscleGroup: .arms),
                Exercise(name: "Rosca Concentrada", sets: 3, reps: 12, weight: 8, restSeconds: 45, muscleGroup: .arms)
            ]
        ),
        WorkoutSheet(
            title: "Treino C - Pernas",
            description: "Membros inferiores completo",
            exercises: [
                Exercise(name: "Agachamento Livre", sets: 4, reps: 10, weight: 80, restSeconds: 120, muscleGroup: .legs),
                Exercise(name: "Leg Press 45°", sets: 4, reps: 12, weight: 150, restSeconds: 90, muscleGroup: .legs),
                Exercise(name: "Hack Squat", sets: 3, reps: 12, weight: 100, restSeconds: 90, muscleGroup: .legs),
                Exercise(name: "Cadeira Extensora", sets: 4, reps: 15, weight: 40, restSeconds: 60, muscleGroup: .legs),
                Exercise(name: "Mesa Flexora", sets: 4, reps: 12, weight: 35, restSeconds: 60, muscleGroup: .legs),
                Exercise(name: "Stiff", sets: 3, reps: 12, weight: 50, restSeconds: 75, muscleGroup: .legs),
                Exercise(name: "Afundo", sets: 3, reps: 12, weight: 20, restSeconds: 75, muscleGroup: .legs),
                Exercise(name: "Cadeira Adutora", sets: 3, reps: 15, weight: 50, restSeconds: 45, muscleGroup: .legs),
                Exercise(name: "Cadeira Abdutora", sets: 3, reps: 15, weight: 45, restSeconds: 45, muscleGroup: .legs),
                Exercise(name: "Panturrilha em Pé", sets: 4, reps: 20, weight: 80, restSeconds: 45, muscleGroup: .legs),
                Exercise(name: "Panturrilha Sentado", sets: 4, reps: 20, weight: 50, restSeconds: 45, muscleGroup: .legs)
            ]
        ),
        WorkoutSheet(
            title: "Treino D - Trapézio e Ombros",
            description: "Desenvolvimento de trapézio e deltoides",
            exercises: [
                Exercise(name: "Encolhimento com Barra", sets: 4, reps: 12, weight: 60, restSeconds: 75, muscleGroup: .back),
                Exercise(name: "Desenvolvimento Militar", sets: 4, reps: 10, weight: 40, restSeconds: 90, muscleGroup: .shoulders),
                Exercise(name: "Elevação Lateral", sets: 4, reps: 15, weight: 10, restSeconds: 60, muscleGroup: .shoulders),
                Exercise(name: "Remada Alta", sets: 4, reps: 12, weight: 30, restSeconds: 75, muscleGroup: .shoulders),
                Exercise(name: "Encolhimento com Halteres", sets: 3, reps: 15, weight: 22, restSeconds: 60, muscleGroup: .back),
                Exercise(name: "Elevação Frontal", sets: 3, reps: 12, weight: 12, restSeconds: 60, muscleGroup: .shoulders),
                Exercise(name: "Crucifixo Inverso", sets: 3, reps: 15, weight: 10, restSeconds: 60, muscleGroup: .back),
                Exercise(name: "Face Pull", sets: 3, reps: 15, weight: 20, restSeconds: 60, muscleGroup: .back)
            ]
        )
    ]
}
