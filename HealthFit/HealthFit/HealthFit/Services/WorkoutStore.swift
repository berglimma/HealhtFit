import Foundation
import Combine

@MainActor
final class WorkoutStore: ObservableObject {
    @Published var workoutSheets: [WorkoutSheet] = []
    @Published var activeSession: WorkoutSession?
    @Published var sessionHistory: [WorkoutSession] = []
    @Published var currentExerciseIndex = 0
    /// Mutações do cronômetro (1s) não publicam para não travar abas que observam o store.
    private(set) var exerciseRecords: [ExerciseSessionRecord] = []
    /// Tick leve para a tela de treino ativo atualizar o cronômetro.
    let exerciseElapsedTick = PassthroughSubject<Int, Never>()
    /// Emitido quando o treino é encerrado automaticamente por inatividade (2h30).
    let sessionAutoEnded = PassthroughSubject<WorkoutSession, Never>()

    @Published private(set) var isExerciseTimerPaused = false

    private let storageKey = "healthfit_workout_sheets"
    private let historyKey = "healthfit_session_history"
    private let activeSessionKey = "healthfit_active_session"
    private let activeRecordsKey = "healthfit_active_exercise_records"
    private let activeExerciseIndexKey = "healthfit_active_exercise_index"
    /// Após 2h30 sem finalizar, o treino é encerrado automaticamente.
    static let autoEndInactivityLimit: TimeInterval = 2.5 * 60 * 60
    static let autoEndJustification =
        "Encerrado automaticamente após 2h30 sem finalização (inatividade)."
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
        clearPersistedActiveSession()
        NotificationService.shared.cancelActiveWorkoutAutoEnd()
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
        restorePersistedActiveSessionIfNeeded()
        autoEndStaleActiveSessionIfNeeded()
    }

    /// Verifica se o treino ativo ultrapassou 2h30 e encerra automaticamente.
    @discardableResult
    func autoEndStaleActiveSessionIfNeeded(now: Date = .now, athleteName: String = "Atleta") -> WorkoutSession? {
        if activeSession == nil {
            restorePersistedActiveSessionIfNeeded()
        }
        guard var session = activeSession else { return nil }

        let elapsed = now.timeIntervalSince(session.startedAt)
        guard elapsed >= Self.autoEndInactivityLimit else { return nil }

        session.endedAt = now
        var records = exerciseRecords
        let elapsedSeconds = max(0, Int(elapsed))
        if !records.isEmpty {
            for index in records.indices where records[index].elapsedSeconds == 0 {
                records[index].elapsedSeconds = elapsedSeconds
            }
            session.exerciseRecords = records
            session.completedExercises = records.filter(\.isCompleted).count
        }
        session.endedEarly = true
        session.autoEndedByInactivity = true
        session.earlyEndJustification = Self.autoEndJustification

        NotificationService.shared.cancelActiveWorkoutAutoEnd(sessionId: session.id)
        NotificationService.shared.deliverForgottenWorkoutEndNotification(
            session: session,
            athleteName: athleteName
        )

        endSession(persisting: session)
        sessionAutoEnded.send(session)
        return session
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

    var maleStandardWorkoutSheets: [WorkoutSheet] {
        standardWorkoutSheets.filter { Self.maleSampleTitles.contains($0.title) }
    }

    var femaleStandardWorkoutSheets: [WorkoutSheet] {
        standardWorkoutSheets.filter { Self.femaleSampleTitles.contains($0.title) }
    }

    var homeStandardWorkoutSheets: [WorkoutSheet] {
        standardWorkoutSheets.filter { Self.homeSampleTitles.contains($0.title) }
    }

    var mobilityStandardWorkoutSheets: [WorkoutSheet] {
        standardWorkoutSheets.filter { Self.mobilitySampleTitles.contains($0.title) }
    }

    func recommendedStandardWorkouts(for gender: Gender?) -> [WorkoutSheet] {
        switch gender {
        case .female:
            return femaleStandardWorkoutSheets
        case .male, .none:
            return maleStandardWorkoutSheets
        }
    }

    func customWorkoutSheets(for gender: Gender) -> [WorkoutSheet] {
        customWorkoutSheets.filter { sheet in
            sheet.resolvedProgramGender == gender
        }
    }

    var customWorkoutSheets: [WorkoutSheet] {
        workoutSheets.filter { !isStandardWorkout($0) }
    }

    private static let sampleWorkoutTitles = Set(sampleWorkouts.map(\.title))
    private static let maleSampleTitles = Set(maleSampleWorkouts.map(\.title))
    private static let femaleSampleTitles = Set(femaleSampleWorkouts.map(\.title))
    private static let homeSampleTitles = Set(homeSampleWorkouts.map(\.title))
    private static let mobilitySampleTitles = Set(mobilitySampleWorkouts.map(\.title))

    /// Retorna a última sessão concluída desta ficha se foi há menos de `hours` horas.
    func recentSameWorkoutSession(
        as sheet: WorkoutSheet,
        withinHours hours: Double = 24
    ) -> WorkoutSession? {
        guard let last = sessionHistory.first(where: { $0.endedAt != nil }) else { return nil }
        guard last.workoutSheetId == sheet.id else { return nil }

        let endedAt = last.endedAt ?? last.startedAt
        let elapsed = Date.now.timeIntervalSince(endedAt)
        guard elapsed >= 0, elapsed <= hours * 3600 else { return nil }
        return last
    }

    func startSession(for sheet: WorkoutSheet, tookPreWorkout: Bool? = nil) {
        let session = WorkoutSession(
            workoutSheetId: sheet.id,
            workoutTitle: sheet.title,
            totalExercises: sheet.exercises.count,
            tookPreWorkout: tookPreWorkout
        )
        activeSession = session
        currentExerciseIndex = 0
        replaceExerciseRecords(sheet.exercises.map {
            ExerciseSessionRecord(
                exerciseId: $0.id,
                exerciseName: $0.name,
                recommendedWeight: $0.recommendedWeight,
                performedWeight: $0.recommendedWeight
            )
        })
        isExerciseTimerPaused = false
        startExerciseTimer()
        persistActiveSession()
        scheduleAutoEnd(for: session)
    }

    func startCardioSession(config: CardioWorkoutConfig) {
        stopExerciseTimer()
        let session = WorkoutSession(
            workoutSheetId: config.exercise.id,
            workoutTitle: config.title,
            totalExercises: 1,
            targetDistanceKm: config.isDistanceRun ? config.targetDistanceKm : nil,
            cardioIntensityLabel: config.intensity.rawValue,
            targetCalories: config.targetCalories
        )
        activeSession = session
        currentExerciseIndex = 0
        replaceExerciseRecords([
            ExerciseSessionRecord(
                exerciseId: config.exercise.id,
                exerciseName: "\(config.exercise.name) (\(config.intensity.rawValue))"
            )
        ])
        isExerciseTimerPaused = false
        persistActiveSession()
        scheduleAutoEnd(for: session)
    }

    func startMeditationSession(config: MeditationWorkoutConfig) {
        stopExerciseTimer()
        let session = WorkoutSession(
            workoutSheetId: config.topic.id,
            workoutTitle: config.title,
            totalExercises: 1
        )
        activeSession = session
        currentExerciseIndex = 0
        replaceExerciseRecords([
            ExerciseSessionRecord(
                exerciseId: config.topic.id,
                exerciseName: config.topic.name
            )
        ])
        isExerciseTimerPaused = false
        persistActiveSession()
        scheduleAutoEnd(for: session)
    }

    func completeExercise() {
        markExerciseCompleted()
    }

    func markExerciseCompleted(at index: Int? = nil) {
        let idx = index ?? currentExerciseIndex
        guard idx < exerciseRecords.count, !exerciseRecords[idx].isCompleted else { return }

        mutateExerciseRecords { records in
            records[idx].isCompleted = true
        }
        syncCompletedExerciseCount()

        if idx == currentExerciseIndex {
            advanceToNextIncomplete()
        }
    }

    func setExerciseTimerPaused(_ paused: Bool) {
        isExerciseTimerPaused = paused
    }

    func applyRestSeconds(from timerService: RestTimerService) {
        mutateExerciseRecords { records in
            for (exerciseId, seconds) in timerService.restByExerciseId {
                guard let idx = records.firstIndex(where: { $0.exerciseId == exerciseId }) else { continue }
                records[idx].restSeconds = seconds
            }
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
        autoEndStaleActiveSessionIfNeeded()
        guard activeSession != nil else { return }
        guard !isExerciseTimerPaused,
              currentExerciseIndex < exerciseRecords.count,
              !exerciseRecords[currentExerciseIndex].isCompleted else { return }
        exerciseRecords[currentExerciseIndex].elapsedSeconds += 1
        exerciseElapsedTick.send(exerciseRecords[currentExerciseIndex].elapsedSeconds)
        if exerciseRecords[currentExerciseIndex].elapsedSeconds % 30 == 0 {
            persistActiveSession()
        }
    }

    /// Publica mudanças estruturais nos registros (não usar no tick de 1s).
    private func replaceExerciseRecords(_ records: [ExerciseSessionRecord]) {
        exerciseRecords = records
        objectWillChange.send()
    }

    private func mutateExerciseRecords(_ mutate: (inout [ExerciseSessionRecord]) -> Void) {
        mutate(&exerciseRecords)
        objectWillChange.send()
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
        if let last = session.heartRateSamples.last, abs(last.bpm - bpm) < 1 {
            return
        }
        session.heartRateSamples.append(HeartRateSample(bpm: bpm))
        activeSession = session
    }

    func updateCalories(_ calories: Double) {
        guard var session = activeSession else { return }
        guard abs(session.caloriesBurned - calories) >= 1 else { return }
        session.caloriesBurned = calories
        activeSession = session
    }

    func updatePerformedWeight(exerciseId: UUID, weight: Double?) {
        guard let index = exerciseRecords.firstIndex(where: { $0.exerciseId == exerciseId }) else { return }
        mutateExerciseRecords { records in
            records[index].performedWeight = weight
        }
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

        NotificationService.shared.cancelActiveWorkoutAutoEnd(sessionId: session.id)

        sessionHistory.insert(session, at: 0)
        if sessionHistory.count > WorkoutFirestoreService.maxStoredSessions {
            sessionHistory = Array(sessionHistory.prefix(WorkoutFirestoreService.maxStoredSessions))
        }
        activeSession = nil
        currentExerciseIndex = 0
        exerciseRecords = []
        isExerciseTimerPaused = false
        clearPersistedActiveSession()
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
            if WeeklyProgressAnalyzer.isCardioSession(session) {
                NotificationService.shared.recordCardioCompleted(at: endedAt)
            } else if WeeklyProgressAnalyzer.isMeditationSession(session) {
                NotificationService.shared.recordMeditationCompleted(at: endedAt)
            }
        }

        PostWorkoutCheckInService.shared.scheduleCheckIn(for: session)
    }

    private func scheduleAutoEnd(for session: WorkoutSession) {
        let fireDate = session.startedAt.addingTimeInterval(Self.autoEndInactivityLimit)
        NotificationService.shared.scheduleActiveWorkoutAutoEnd(
            sessionId: session.id,
            workoutTitle: session.workoutTitle,
            fireDate: fireDate
        )
    }

    private func persistActiveSession() {
        guard let session = activeSession else {
            clearPersistedActiveSession()
            return
        }
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: activeSessionKey)
        }
        if let recordsData = try? JSONEncoder().encode(exerciseRecords) {
            UserDefaults.standard.set(recordsData, forKey: activeRecordsKey)
        }
        UserDefaults.standard.set(currentExerciseIndex, forKey: activeExerciseIndexKey)
    }

    private func clearPersistedActiveSession() {
        UserDefaults.standard.removeObject(forKey: activeSessionKey)
        UserDefaults.standard.removeObject(forKey: activeRecordsKey)
        UserDefaults.standard.removeObject(forKey: activeExerciseIndexKey)
    }

    private func restorePersistedActiveSessionIfNeeded() {
        guard activeSession == nil,
              let data = UserDefaults.standard.data(forKey: activeSessionKey),
              let session = try? JSONDecoder().decode(WorkoutSession.self, from: data),
              session.endedAt == nil else { return }

        activeSession = session
        if let recordsData = UserDefaults.standard.data(forKey: activeRecordsKey),
           let records = try? JSONDecoder().decode([ExerciseSessionRecord].self, from: recordsData) {
            exerciseRecords = records
        }
        currentExerciseIndex = UserDefaults.standard.integer(forKey: activeExerciseIndexKey)
        isExerciseTimerPaused = false
        if !WeeklyProgressAnalyzer.isCardioSession(session),
           !WeeklyProgressAnalyzer.isMeditationSession(session) {
            startExerciseTimer()
        }
    }

    var lastCompletedWorkoutAt: Date? {
        if let recorded = NotificationService.shared.lastRecordedWorkoutAt {
            return recorded
        }
        return sessionHistory
            .compactMap { $0.endedAt ?? $0.startedAt }
            .max()
    }

    var lastCompletedCardioAt: Date? {
        if let recorded = NotificationService.shared.lastRecordedCardioAt {
            return recorded
        }
        return AssistantCardioMeditationNudgeEngine.lastCardioDate(from: sessionHistory)
    }

    var lastCompletedMeditationAt: Date? {
        if let recorded = NotificationService.shared.lastRecordedMeditationAt {
            return recorded
        }
        return AssistantCardioMeditationNudgeEngine.lastMeditationDate(from: sessionHistory)
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

        // Remove fichas padrão antigas (A/B/C/D genéricas) substituídas pelos programas por sexo.
        let beforeCount = workoutSheets.count
        workoutSheets.removeAll { sheet in
            !sheet.isUserCreated && Self.legacySampleTitles.contains(sheet.title)
        }
        if workoutSheets.count != beforeCount {
            didUpdate = true
        }

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
                isActive: sheet.isActive,
                targetGender: sample.targetGender,
                createdByAssistant: sheet.createdByAssistant
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

    private static let legacySampleTitles: Set<String> = [
        "Treino A - Peito e Tríceps",
        "Treino B - Costas e Bíceps",
        "Treino C - Pernas",
        "Treino D - Trapézio e Ombros"
    ]

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

    static let sampleWorkouts: [WorkoutSheet] =
        maleSampleWorkouts + femaleSampleWorkouts + homeSampleWorkouts + mobilitySampleWorkouts

    /// Programa padrão masculino — hipertrofia clássica com ênfase em peito, costas e força.
    static let maleSampleWorkouts: [WorkoutSheet] = [
        WorkoutSheet(
            title: "Masculino A — Peito e Tríceps",
            description: "Hipertrofia de peitoral e tríceps — perfil masculino",
            exercises: [
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
        WorkoutSheet(
            title: "Masculino B — Costas e Bíceps",
            description: "Largura dorsal e bíceps — perfil masculino",
            exercises: [
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
        WorkoutSheet(
            title: "Masculino C — Pernas",
            description: "Força e volume de membros inferiores — perfil masculino",
            exercises: [
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
        WorkoutSheet(
            title: "Masculino D — Ombros e Trapézio",
            description: "Deltoides e trapézio para estrutura — perfil masculino",
            exercises: [
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
    ]

    /// Programa padrão feminino — ênfase em glúteos, posteriores, core e postura.
    static let femaleSampleWorkouts: [WorkoutSheet] = [
        WorkoutSheet(
            title: "Feminino A — Glúteos e Posteriores",
            description: "Ativação e hipertrofia de glúteos e cadeia posterior — perfil feminino",
            exercises: [
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
        WorkoutSheet(
            title: "Feminino B — Pernas e Core",
            description: "Quadríceps, adutores e abdômen — perfil feminino",
            exercises: [
                Exercise(name: "Agachamento Livre", sets: 4, reps: 12, weight: 35, restSeconds: 90, muscleGroup: .legs),
                Exercise(name: "Leg Press 45°", sets: 4, reps: 15, weight: 80, restSeconds: 75, muscleGroup: .legs),
                Exercise(name: "Cadeira Extensora", sets: 4, reps: 15, weight: 30, restSeconds: 60, muscleGroup: .legs),
                Exercise(name: "Cadeira Adutora", sets: 3, reps: 15, weight: 40, restSeconds: 45, muscleGroup: .legs),
                Exercise(name: "Afundo", sets: 3, reps: 12, weight: 10, restSeconds: 60, muscleGroup: .legs),
                Exercise(name: "Panturrilha Sentado", sets: 3, reps: 20, weight: 30, restSeconds: 45, muscleGroup: .legs),
                Exercise(name: "Prancha", sets: 3, reps: 40, restSeconds: 45, muscleGroup: .core),
                Exercise(name: "Abdominal Infra", sets: 3, reps: 15, restSeconds: 45, muscleGroup: .core),
                Exercise(name: "Abdominal Oblíquo", sets: 3, reps: 20, restSeconds: 45, muscleGroup: .core),
                Exercise(name: "Elevação de Pernas", sets: 3, reps: 12, restSeconds: 45, muscleGroup: .core)
            ]
        ),
        WorkoutSheet(
            title: "Feminino C — Costas e Postura",
            description: "Costas, ombros posteriores e braços leves — perfil feminino",
            exercises: [
                Exercise(name: "Puxada Frontal", sets: 4, reps: 12, weight: 30, restSeconds: 75, muscleGroup: .back),
                Exercise(name: "Remada Unilateral", sets: 3, reps: 12, weight: 12, restSeconds: 60, muscleGroup: .back),
                Exercise(name: "Pulldown Triângulo", sets: 3, reps: 12, weight: 25, restSeconds: 60, muscleGroup: .back),
                Exercise(name: "Remada Curvada", sets: 3, reps: 12, weight: 25, restSeconds: 75, muscleGroup: .back),
                Exercise(name: "Face Pull", sets: 3, reps: 15, weight: 12, restSeconds: 45, muscleGroup: .back),
                Exercise(name: "Crucifixo Inverso", sets: 3, reps: 15, weight: 6, restSeconds: 45, muscleGroup: .shoulders),
                Exercise(name: "Elevação Lateral", sets: 3, reps: 15, weight: 6, restSeconds: 45, muscleGroup: .shoulders),
                Exercise(name: "Rosca Direta", sets: 3, reps: 12, weight: 8, restSeconds: 45, muscleGroup: .arms),
                Exercise(name: "Tríceps Pulley", sets: 3, reps: 12, weight: 15, restSeconds: 45, muscleGroup: .arms),
                Exercise(name: "Prancha Lateral", sets: 3, reps: 30, restSeconds: 45, muscleGroup: .core)
            ]
        ),
        WorkoutSheet(
            title: "Feminino D — Full Body e Ombros",
            description: "Corpo inteiro com ênfase em ombros e core — perfil feminino",
            exercises: [
                Exercise(name: "Agachamento Livre", sets: 3, reps: 12, weight: 30, restSeconds: 75, muscleGroup: .legs),
                Exercise(name: "Elevação Pélvica (Hip Thrust)", sets: 3, reps: 12, weight: 35, restSeconds: 60, muscleGroup: .legs),
                Exercise(name: "Puxada Frontal", sets: 3, reps: 12, weight: 25, restSeconds: 60, muscleGroup: .back),
                Exercise(name: "Desenvolvimento com Halteres", sets: 3, reps: 12, weight: 8, restSeconds: 60, muscleGroup: .shoulders),
                Exercise(name: "Elevação Lateral", sets: 3, reps: 15, weight: 5, restSeconds: 45, muscleGroup: .shoulders),
                Exercise(name: "Flexão de Braços", sets: 3, reps: 10, restSeconds: 60, muscleGroup: .chest),
                Exercise(name: "Remada Unilateral", sets: 3, reps: 12, weight: 10, restSeconds: 60, muscleGroup: .back),
                Exercise(name: "Kettlebell Swing", sets: 3, reps: 15, weight: 12, restSeconds: 60, muscleGroup: .fullBody),
                Exercise(name: "Abdominal Crunch", sets: 3, reps: 20, restSeconds: 40, muscleGroup: .core),
                Exercise(name: "Prancha", sets: 3, reps: 35, restSeconds: 40, muscleGroup: .core)
            ]
        )
    ]

    /// Programa em casa — peso corporal com demos em vídeo/GIF durante o treino.
    static let homeSampleWorkouts: [WorkoutSheet] = [
        WorkoutSheet(
            title: "Casa A — Full Body",
            description: "Corpo inteiro sem equipamentos — ideal para iniciar em casa",
            exercises: [
                Exercise(name: "Agachamento Livre", sets: 3, reps: 15, restSeconds: 45, muscleGroup: .legs),
                Exercise(name: "Flexão de Braços", sets: 3, reps: 12, restSeconds: 45, muscleGroup: .chest),
                Exercise(name: "Afundo", sets: 3, reps: 12, restSeconds: 45, muscleGroup: .legs),
                Exercise(name: "Mergulho no Banco", sets: 3, reps: 12, restSeconds: 45, muscleGroup: .arms),
                Exercise(name: "Prancha", sets: 3, reps: 40, restSeconds: 40, muscleGroup: .core),
                Exercise(name: "Mountain Climber", sets: 3, reps: 20, restSeconds: 40, muscleGroup: .fullBody),
                Exercise(name: "Burpee", sets: 3, reps: 10, restSeconds: 50, muscleGroup: .fullBody),
                Exercise(name: "Polichinelo", sets: 3, reps: 30, restSeconds: 40, muscleGroup: .fullBody)
            ]
        ),
        WorkoutSheet(
            title: "Casa B — Core e Abdômen",
            description: "Abdômen, oblíquos e estabilidade — só o peso do corpo",
            exercises: [
                Exercise(name: "Prancha", sets: 3, reps: 45, restSeconds: 40, muscleGroup: .core),
                Exercise(name: "Prancha Lateral", sets: 3, reps: 30, restSeconds: 40, muscleGroup: .core),
                Exercise(name: "Abdominal Crunch", sets: 3, reps: 20, restSeconds: 40, muscleGroup: .core),
                Exercise(name: "Abdominal Infra", sets: 3, reps: 15, restSeconds: 40, muscleGroup: .core),
                Exercise(name: "Abdominal Oblíquo", sets: 3, reps: 20, restSeconds: 40, muscleGroup: .core),
                Exercise(name: "Elevação de Pernas", sets: 3, reps: 12, restSeconds: 45, muscleGroup: .core),
                Exercise(name: "Bicicleta no Ar", sets: 3, reps: 24, restSeconds: 40, muscleGroup: .core),
                Exercise(name: "Russian Twist", sets: 3, reps: 24, restSeconds: 40, muscleGroup: .core)
            ]
        ),
        WorkoutSheet(
            title: "Casa C — HIIT Em Casa",
            description: "Alta intensidade em circuitos curtos — cardio + força",
            exercises: [
                Exercise(name: "Polichinelo", sets: 4, reps: 40, restSeconds: 30, muscleGroup: .fullBody),
                Exercise(name: "Burpee", sets: 4, reps: 10, restSeconds: 40, muscleGroup: .fullBody),
                Exercise(name: "Mountain Climber", sets: 4, reps: 30, restSeconds: 30, muscleGroup: .fullBody),
                Exercise(name: "Agachamento Livre", sets: 4, reps: 20, restSeconds: 35, muscleGroup: .legs),
                Exercise(name: "Flexão de Braços", sets: 4, reps: 12, restSeconds: 35, muscleGroup: .chest),
                Exercise(name: "Prancha", sets: 3, reps: 40, restSeconds: 30, muscleGroup: .core),
                Exercise(name: "Afundo", sets: 3, reps: 16, restSeconds: 35, muscleGroup: .legs),
                Exercise(name: "Polichinelo", sets: 3, reps: 35, restSeconds: 45, notes: "Finalizador — ritmo máximo", muscleGroup: .fullBody)
            ]
        ),
        WorkoutSheet(
            title: "Casa D — Pernas e Glúteos",
            description: "Inferiores em casa — agachamentos, afundos e ponte",
            exercises: [
                Exercise(name: "Agachamento Livre", sets: 4, reps: 15, restSeconds: 50, muscleGroup: .legs),
                Exercise(name: "Afundo", sets: 3, reps: 12, restSeconds: 45, muscleGroup: .legs),
                Exercise(name: "Ponte de Glúteos", sets: 4, reps: 15, restSeconds: 40, muscleGroup: .legs),
                Exercise(name: "Elevação Pélvica (Hip Thrust)", sets: 3, reps: 15, restSeconds: 45, muscleGroup: .legs),
                Exercise(name: "Isometria na Parede", sets: 3, reps: 40, restSeconds: 45, notes: "Segure a posição (reps = segundos)", muscleGroup: .legs),
                Exercise(name: "Agachamento Sumô", sets: 3, reps: 15, restSeconds: 45, muscleGroup: .legs),
                Exercise(name: "Panturrilha Corporal", sets: 4, reps: 20, restSeconds: 30, muscleGroup: .legs),
                Exercise(name: "Prancha", sets: 3, reps: 35, restSeconds: 40, muscleGroup: .core)
            ]
        ),
        WorkoutSheet(
            title: "Casa E — Superiores",
            description: "Peito, tríceps e postura — flexões e isometrias",
            exercises: [
                Exercise(name: "Flexão de Braços", sets: 4, reps: 12, restSeconds: 45, muscleGroup: .chest),
                Exercise(name: "Flexão Diamante", sets: 3, reps: 10, restSeconds: 45, muscleGroup: .arms),
                Exercise(name: "Flexão Inclinada", sets: 3, reps: 12, restSeconds: 45, notes: "Mãos em sofá ou banco", muscleGroup: .chest),
                Exercise(name: "Mergulho no Banco", sets: 3, reps: 12, restSeconds: 45, muscleGroup: .arms),
                Exercise(name: "Superman", sets: 3, reps: 15, restSeconds: 40, muscleGroup: .back),
                Exercise(name: "Prancha", sets: 3, reps: 40, restSeconds: 40, muscleGroup: .core),
                Exercise(name: "Prancha Lateral", sets: 3, reps: 30, restSeconds: 40, muscleGroup: .core),
                Exercise(name: "Flexão de Braços", sets: 2, reps: 10, restSeconds: 50, notes: "Séries finais até a falha próxima", muscleGroup: .chest)
            ]
        ),
        WorkoutSheet(
            title: "Casa F — Mobilidade e Postura",
            description: "Core, lombar e estabilidade para o dia a dia",
            exercises: [
                Exercise(name: "Superman", sets: 3, reps: 12, restSeconds: 40, muscleGroup: .back),
                Exercise(name: "Ponte de Glúteos", sets: 3, reps: 15, restSeconds: 40, muscleGroup: .legs),
                Exercise(name: "Prancha", sets: 3, reps: 40, restSeconds: 40, muscleGroup: .core),
                Exercise(name: "Prancha Lateral", sets: 3, reps: 30, restSeconds: 40, muscleGroup: .core),
                Exercise(name: "Elevação de Pernas", sets: 3, reps: 12, restSeconds: 40, muscleGroup: .core),
                Exercise(name: "Russian Twist", sets: 3, reps: 20, restSeconds: 40, muscleGroup: .core),
                Exercise(name: "Bicicleta no Ar", sets: 3, reps: 24, restSeconds: 40, muscleGroup: .core),
                Exercise(name: "Isometria na Parede", sets: 3, reps: 35, restSeconds: 45, notes: "Segure a posição (reps = segundos)", muscleGroup: .legs)
            ]
        )
    ]

    /// Mobilidade voltada à musculação — aquecimento, articulações e pós-treino.
    static let mobilitySampleWorkouts: [WorkoutSheet] = [
        WorkoutSheet(
            title: "Mobilidade A — Aquecimento Geral",
            description: "Ativação articular antes de treinar com carga — 8–10 min",
            exercises: [
                Exercise(name: "Círculos de Tornozelo", sets: 2, reps: 12, restSeconds: 20, notes: "Cada lado · movimento lento", muscleGroup: .legs),
                Exercise(name: "Círculos de Punho", sets: 2, reps: 12, restSeconds: 20, notes: "Cada direção", muscleGroup: .arms),
                Exercise(name: "Inchworm", sets: 2, reps: 8, restSeconds: 30, muscleGroup: .fullBody),
                Exercise(name: "Alongamento Mundial", sets: 2, reps: 6, restSeconds: 25, notes: "3 por lado", muscleGroup: .fullBody),
                Exercise(name: "Alongamento de Coluna", sets: 2, reps: 10, restSeconds: 25, muscleGroup: .back),
                Exercise(name: "Alongamento de Costas Altas", sets: 2, reps: 10, restSeconds: 25, muscleGroup: .back),
                Exercise(name: "Alongamento de Panturrilha", sets: 2, reps: 30, restSeconds: 20, notes: "Cada lado · reps = segundos", muscleGroup: .legs)
            ]
        ),
        WorkoutSheet(
            title: "Mobilidade B — Ombros e Peito",
            description: "Preparo para supino, desenvolvimento e remadas",
            exercises: [
                Exercise(name: "Alongamento de Peito", sets: 3, reps: 30, restSeconds: 20, notes: "Segure · reps = segundos", muscleGroup: .chest),
                Exercise(name: "Alongamento Peitoral Atrás da Cabeça", sets: 2, reps: 25, restSeconds: 20, notes: "reps = segundos", muscleGroup: .chest),
                Exercise(name: "Alongamento de Deltoide Posterior", sets: 2, reps: 25, restSeconds: 20, notes: "Cada lado · reps = segundos", muscleGroup: .shoulders),
                Exercise(name: "Alongamento de Tríceps", sets: 2, reps: 25, restSeconds: 20, notes: "Cada braço · reps = segundos", muscleGroup: .arms),
                Exercise(name: "Alongamento de Dorsal", sets: 2, reps: 25, restSeconds: 20, notes: "Cada lado · reps = segundos", muscleGroup: .back),
                Exercise(name: "Alongamento de Costas Altas", sets: 2, reps: 12, restSeconds: 25, muscleGroup: .back),
                Exercise(name: "Alongamento de Pescoço", sets: 2, reps: 20, restSeconds: 15, notes: "Cada lado · suave · reps = segundos", muscleGroup: .shoulders)
            ]
        ),
        WorkoutSheet(
            title: "Mobilidade C — Quadril e Posterior",
            description: "Preparo para agachamento, terra e afundos",
            exercises: [
                Exercise(name: "Alongamento Mundial", sets: 2, reps: 6, restSeconds: 25, notes: "3 por lado", muscleGroup: .fullBody),
                Exercise(name: "Alongamento de Flexor de Quadril", sets: 2, reps: 30, restSeconds: 25, notes: "Cada lado · reps = segundos", muscleGroup: .legs),
                Exercise(name: "Alongamento de Posterior", sets: 2, reps: 30, restSeconds: 25, notes: "Cada perna · reps = segundos", muscleGroup: .legs),
                Exercise(name: "Alongamento de Glúteo", sets: 2, reps: 30, restSeconds: 25, notes: "Cada lado · reps = segundos", muscleGroup: .legs),
                Exercise(name: "Alongamento de Piriforme", sets: 2, reps: 30, restSeconds: 25, notes: "Cada lado · reps = segundos", muscleGroup: .legs),
                Exercise(name: "Borboleta (Addutores)", sets: 2, reps: 35, restSeconds: 25, notes: "reps = segundos", muscleGroup: .legs),
                Exercise(name: "Círculos de Tornozelo", sets: 2, reps: 12, restSeconds: 20, notes: "Cada lado", muscleGroup: .legs),
                Exercise(name: "Alongamento de Panturrilha", sets: 2, reps: 30, restSeconds: 20, notes: "Cada lado · reps = segundos", muscleGroup: .legs)
            ]
        ),
        WorkoutSheet(
            title: "Mobilidade D — Torácica e Escápulas",
            description: "Abertura torácica e controle escapular para puxadas e presses",
            exercises: [
                Exercise(name: "Alongamento de Coluna", sets: 3, reps: 12, restSeconds: 25, muscleGroup: .back),
                Exercise(name: "Alongamento de Costas Altas", sets: 3, reps: 12, restSeconds: 25, muscleGroup: .back),
                Exercise(name: "Alongamento de Dorsal", sets: 2, reps: 30, restSeconds: 20, notes: "Cada lado · reps = segundos", muscleGroup: .back),
                Exercise(name: "Alongamento de Peito", sets: 2, reps: 30, restSeconds: 20, notes: "reps = segundos", muscleGroup: .chest),
                Exercise(name: "Alongamento de Deltoide Posterior", sets: 2, reps: 25, restSeconds: 20, notes: "Cada lado · reps = segundos", muscleGroup: .shoulders),
                Exercise(name: "Escápula na Barra", sets: 3, reps: 10, restSeconds: 40, notes: "Só depressão/elevação das escápulas", muscleGroup: .back),
                Exercise(name: "Inchworm", sets: 2, reps: 6, restSeconds: 30, muscleGroup: .fullBody)
            ]
        ),
        WorkoutSheet(
            title: "Mobilidade E — Pós-treino",
            description: "Alongamento estático para recuperação após a musculação",
            exercises: [
                Exercise(name: "Alongamento de Peito", sets: 2, reps: 40, restSeconds: 15, notes: "reps = segundos", muscleGroup: .chest),
                Exercise(name: "Alongamento de Dorsal", sets: 2, reps: 40, restSeconds: 15, notes: "Cada lado · reps = segundos", muscleGroup: .back),
                Exercise(name: "Alongamento de Posterior", sets: 2, reps: 40, restSeconds: 15, notes: "Cada perna · reps = segundos", muscleGroup: .legs),
                Exercise(name: "Alongamento de Flexor de Quadril", sets: 2, reps: 40, restSeconds: 15, notes: "Cada lado · reps = segundos", muscleGroup: .legs),
                Exercise(name: "Alongamento de Glúteo", sets: 2, reps: 40, restSeconds: 15, notes: "Cada lado · reps = segundos", muscleGroup: .legs),
                Exercise(name: "Alongamento de Tríceps", sets: 2, reps: 35, restSeconds: 15, notes: "Cada braço · reps = segundos", muscleGroup: .arms),
                Exercise(name: "Alongamento de Panturrilha", sets: 2, reps: 35, restSeconds: 15, notes: "Cada lado · reps = segundos", muscleGroup: .legs),
                Exercise(name: "Alongamento de Pescoço", sets: 2, reps: 25, restSeconds: 10, notes: "Cada lado · suave · reps = segundos", muscleGroup: .shoulders)
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
