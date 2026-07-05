import Foundation
import Combine

@MainActor
final class WorkoutStore: ObservableObject {
    @Published var workoutSheets: [WorkoutSheet] = []
    @Published var activeSession: WorkoutSession?
    @Published var sessionHistory: [WorkoutSession] = []
    @Published var currentExerciseIndex = 0
    @Published private(set) var exerciseRecords: [ExerciseSessionRecord] = []

    @Published private(set) var isExerciseTimerPaused = false

    private let storageKey = "healthfit_workout_sheets"
    private let historyKey = "healthfit_session_history"
    private var exerciseTimer: Timer?
    private var cloudUserId: String?

    func configureCloudSync(userId: String?) {
        cloudUserId = userId
    }

    func clearAllLocalData() {
        activeSession = nil
        currentExerciseIndex = 0
        exerciseRecords = []
        sessionHistory = []
        workoutSheets = []
        cloudUserId = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: historyKey)
    }

    func loadCloudHistory(userId: String) async {
        guard WorkoutFirestoreService.isAvailable else { return }

        do {
            let remoteSessions = try await WorkoutFirestoreService.fetchRecentSessions(userId: userId)
            guard !remoteSessions.isEmpty else { return }

            sessionHistory = mergeSessions(local: sessionHistory, remote: remoteSessions)
            saveHistory()
        } catch {
            print("[HealthFit] Falha ao carregar treinos do Firebase: \(error.localizedDescription)")
        }
    }

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
        guard canModify(sheet) else { return }
        if let index = workoutSheets.firstIndex(where: { $0.id == sheet.id }) {
            workoutSheets[index] = sheet
            saveData()
        }
    }

    func deleteWorkoutSheet(_ sheet: WorkoutSheet) {
        guard canModify(sheet) else { return }
        workoutSheets.removeAll { $0.id == sheet.id }
        saveData()
    }

    func canModify(_ sheet: WorkoutSheet) -> Bool {
        sheet.isUserCreated || !Self.sampleWorkoutTitles.contains(sheet.title)
    }

    func isStandardWorkout(_ sheet: WorkoutSheet) -> Bool {
        !canModify(sheet)
    }

    var standardWorkoutSheets: [WorkoutSheet] {
        workoutSheets.filter(isStandardWorkout)
    }

    var customWorkoutSheets: [WorkoutSheet] {
        workoutSheets.filter { !isStandardWorkout($0) }
    }

    private static let sampleWorkoutTitles = Set(sampleWorkouts.map(\.title))

    func startSession(for sheet: WorkoutSheet, tookPreWorkout: Bool? = nil) {
        activeSession = WorkoutSession(
            workoutSheetId: sheet.id,
            workoutTitle: sheet.title,
            totalExercises: sheet.exercises.count,
            tookPreWorkout: tookPreWorkout
        )
        currentExerciseIndex = 0
        exerciseRecords = sheet.exercises.map {
            ExerciseSessionRecord(exerciseId: $0.id, exerciseName: $0.name)
        }
        isExerciseTimerPaused = false
        startExerciseTimer()
    }

    func startCardioSession(config: CardioWorkoutConfig) {
        stopExerciseTimer()
        activeSession = WorkoutSession(
            workoutSheetId: config.exercise.id,
            workoutTitle: config.title,
            totalExercises: 1,
            targetDistanceKm: config.isDistanceRun ? config.targetDistanceKm : nil,
            cardioIntensityLabel: config.intensity.rawValue,
            targetCalories: config.targetCalories
        )
        currentExerciseIndex = 0
        exerciseRecords = [
            ExerciseSessionRecord(
                exerciseId: config.exercise.id,
                exerciseName: "\(config.exercise.name) (\(config.intensity.rawValue))"
            )
        ]
        isExerciseTimerPaused = false
    }

    func startMeditationSession(config: MeditationWorkoutConfig) {
        stopExerciseTimer()
        activeSession = WorkoutSession(
            workoutSheetId: config.topic.id,
            workoutTitle: config.title,
            totalExercises: 1
        )
        currentExerciseIndex = 0
        exerciseRecords = [
            ExerciseSessionRecord(
                exerciseId: config.topic.id,
                exerciseName: config.topic.name
            )
        ]
        isExerciseTimerPaused = false
    }

    func completeExercise() {
        markExerciseCompleted()
    }

    func markExerciseCompleted(at index: Int? = nil) {
        let idx = index ?? currentExerciseIndex
        guard idx < exerciseRecords.count, !exerciseRecords[idx].isCompleted else { return }

        exerciseRecords[idx].isCompleted = true
        syncCompletedExerciseCount()

        if idx == currentExerciseIndex {
            advanceToNextIncomplete()
        }
    }

    func setExerciseTimerPaused(_ paused: Bool) {
        isExerciseTimerPaused = paused
    }

    func applyRestSeconds(from timerService: RestTimerService) {
        for (exerciseId, seconds) in timerService.restByExerciseId {
            guard let idx = exerciseRecords.firstIndex(where: { $0.exerciseId == exerciseId }) else { continue }
            exerciseRecords[idx].restSeconds = seconds
        }
    }

    var allExercisesCompleted: Bool {
        !exerciseRecords.isEmpty && exerciseRecords.allSatisfy(\.isCompleted)
    }

    private func startExerciseTimer() {
        exerciseTimer?.invalidate()
        exerciseTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickCurrentExercise()
            }
        }
    }

    private func tickCurrentExercise() {
        guard !isExerciseTimerPaused,
              currentExerciseIndex < exerciseRecords.count,
              !exerciseRecords[currentExerciseIndex].isCompleted else { return }
        exerciseRecords[currentExerciseIndex].elapsedSeconds += 1
    }

    private func advanceToNextIncomplete() {
        if let next = exerciseRecords.indices.first(where: { !exerciseRecords[$0].isCompleted }) {
            currentExerciseIndex = next
        }
    }

    private func syncCompletedExerciseCount() {
        guard var session = activeSession else { return }
        session.completedExercises = exerciseRecords.filter(\.isCompleted).count
        activeSession = session
    }

    private func stopExerciseTimer() {
        exerciseTimer?.invalidate()
        exerciseTimer = nil
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

    func endSession(persisting persistedSession: WorkoutSession? = nil) {
        stopExerciseTimer()

        guard var session = persistedSession ?? activeSession else { return }

        if persistedSession == nil {
            session.endedAt = .now
            session.exerciseRecords = exerciseRecords
            session.completedExercises = exerciseRecords.filter(\.isCompleted).count
        } else if session.endedAt == nil {
            session.endedAt = .now
        }

        sessionHistory.insert(session, at: 0)
        if sessionHistory.count > WorkoutFirestoreService.maxStoredSessions {
            sessionHistory = Array(sessionHistory.prefix(WorkoutFirestoreService.maxStoredSessions))
        }
        activeSession = nil
        currentExerciseIndex = 0
        exerciseRecords = []
        isExerciseTimerPaused = false
        saveHistory()

        if let userId = cloudUserId {
            Task {
                do {
                    try await WorkoutFirestoreService.saveSession(session, userId: userId)
                } catch {
                    print("[HealthFit] Falha ao salvar treino no Firebase: \(error.localizedDescription)")
                }
            }
        }

        if let endedAt = session.endedAt {
            NotificationService.shared.recordWorkoutCompleted(at: endedAt)
        }

        PostWorkoutCheckInService.shared.scheduleCheckIn(for: session)
    }

    var lastCompletedWorkoutAt: Date? {
        if let recorded = NotificationService.shared.lastRecordedWorkoutAt {
            return recorded
        }
        return sessionHistory
            .compactMap { $0.endedAt ?? $0.startedAt }
            .max()
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
            workoutSheets = sheets.map { sheet in
                var updated = sheet
                if !updated.isUserCreated, !Self.sampleWorkoutTitles.contains(updated.title) {
                    updated.isUserCreated = true
                }
                return updated
            }
        }
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let history = try? JSONDecoder().decode([WorkoutSession].self, from: data) {
            sessionHistory = Array(history.prefix(WorkoutFirestoreService.maxStoredSessions))
            if let latest = history.compactMap({ $0.endedAt ?? $0.startedAt }).max() {
                NotificationService.shared.migrateLastWorkoutDateIfNeeded(latest)
            }
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

    private func mergeSessions(local: [WorkoutSession], remote: [WorkoutSession]) -> [WorkoutSession] {
        var merged: [UUID: WorkoutSession] = [:]

        for session in local {
            merged[session.id] = session
        }
        for session in remote {
            merged[session.id] = session
        }

        return merged.values
            .sorted {
                let lhs = $0.endedAt ?? $0.startedAt
                let rhs = $1.endedAt ?? $1.startedAt
                return lhs > rhs
            }
            .prefix(WorkoutFirestoreService.maxStoredSessions)
            .map { $0 }
    }

    static func presetExercises(for muscleGroup: MuscleGroup) -> [Exercise] {
        var seen = Set<String>()
        return (sampleWorkouts + catalogOnlyWorkouts)
            .flatMap(\.exercises)
            .filter { $0.muscleGroup == muscleGroup }
            .filter { seen.insert($0.name).inserted }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func presetExercises(for focusGroups: Set<CustomWorkoutFocusGroup>) -> [Exercise] {
        guard !focusGroups.isEmpty else { return [] }

        var seen = Set<String>()
        return (sampleWorkouts + catalogOnlyWorkouts)
            .flatMap(\.exercises)
            .filter { exercise in
                guard let focus = CustomWorkoutFocusGroup.focusGroup(for: exercise.name) else { return false }
                return focusGroups.contains(focus)
            }
            .filter { seen.insert($0.name).inserted }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func focusGroup(for exercise: Exercise) -> CustomWorkoutFocusGroup? {
        CustomWorkoutFocusGroup.focusGroup(for: exercise.name)
    }

    static func copyExerciseForWorkout(_ template: Exercise) -> Exercise {
        Exercise(
            name: template.name,
            sets: template.sets,
            reps: template.reps,
            weight: template.weight,
            restSeconds: template.restSeconds,
            notes: template.notes,
            muscleGroup: template.muscleGroup
        )
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

    /// Fichas usadas apenas no catálogo de exercícios ao criar treino personalizado.
    private static let catalogOnlyWorkouts: [WorkoutSheet] = [
        WorkoutSheet(
            title: "Catálogo - Ombros",
            description: "Exercícios de deltoides",
            exercises: [
                Exercise(name: "Desenvolvimento com Halteres", sets: 4, reps: 10, weight: 18, restSeconds: 90, muscleGroup: .shoulders),
                Exercise(name: "Arnold Press", sets: 3, reps: 12, weight: 14, restSeconds: 75, muscleGroup: .shoulders),
                Exercise(name: "Elevação Posterior", sets: 4, reps: 15, weight: 8, restSeconds: 60, muscleGroup: .shoulders),
                Exercise(name: "Elevação Lateral na Polia", sets: 3, reps: 15, weight: 8, restSeconds: 60, muscleGroup: .shoulders),
                Exercise(name: "Desenvolvimento na Máquina", sets: 4, reps: 12, weight: 35, restSeconds: 75, muscleGroup: .shoulders),
                Exercise(name: "Crucifixo Inverso no Cabo", sets: 3, reps: 15, weight: 10, restSeconds: 60, muscleGroup: .shoulders)
            ]
        ),
        WorkoutSheet(
            title: "Catálogo - Abdômen",
            description: "Exercícios de core",
            exercises: [
                Exercise(name: "Prancha", sets: 3, reps: 45, restSeconds: 45, muscleGroup: .core),
                Exercise(name: "Abdominal Crunch", sets: 4, reps: 20, restSeconds: 45, muscleGroup: .core),
                Exercise(name: "Abdominal Infra", sets: 4, reps: 15, restSeconds: 45, muscleGroup: .core),
                Exercise(name: "Abdominal Oblíquo", sets: 3, reps: 20, restSeconds: 45, muscleGroup: .core),
                Exercise(name: "Elevação de Pernas", sets: 3, reps: 15, restSeconds: 60, muscleGroup: .core),
                Exercise(name: "Russian Twist", sets: 3, reps: 20, weight: 8, restSeconds: 45, muscleGroup: .core),
                Exercise(name: "Mountain Climber", sets: 3, reps: 30, restSeconds: 45, muscleGroup: .core),
                Exercise(name: "Abdominal na Polia", sets: 4, reps: 15, weight: 25, restSeconds: 60, muscleGroup: .core),
                Exercise(name: "Prancha Lateral", sets: 3, reps: 30, restSeconds: 45, muscleGroup: .core),
                Exercise(name: "Bicicleta no Ar", sets: 3, reps: 20, restSeconds: 45, muscleGroup: .core)
            ]
        ),
        WorkoutSheet(
            title: "Catálogo - Corpo Inteiro",
            description: "Exercícios compostos",
            exercises: [
                Exercise(name: "Burpee", sets: 3, reps: 12, restSeconds: 75, muscleGroup: .fullBody),
                Exercise(name: "Levantamento Terra", sets: 4, reps: 8, weight: 70, restSeconds: 120, muscleGroup: .fullBody),
                Exercise(name: "Thruster", sets: 3, reps: 10, weight: 20, restSeconds: 90, muscleGroup: .fullBody),
                Exercise(name: "Kettlebell Swing", sets: 4, reps: 15, weight: 16, restSeconds: 75, muscleGroup: .fullBody),
                Exercise(name: "Farmer's Walk", sets: 3, reps: 40, weight: 24, restSeconds: 90, muscleGroup: .fullBody)
            ]
        )
    ]
}
