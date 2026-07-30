import Foundation

@MainActor
enum WorkoutLiveActivitySync {
    static func push(
        workoutStore: WorkoutStore,
        timerService: RestTimerService,
        sheet: WorkoutSheet? = nil
    ) {
        guard let session = workoutStore.activeSession else {
            WorkoutLiveActivityController.shared.end()
            return
        }

        let currentExercise = workoutStore.currentExercise
            ?? sheet.flatMap { sheet in
                guard workoutStore.currentExerciseIndex < sheet.exercises.count else { return nil }
                return sheet.exercises[workoutStore.currentExerciseIndex]
            }

        let exerciseName = currentExercise?.name
            ?? workoutStore.exerciseRecords[safe: workoutStore.currentExerciseIndex]?.exerciseName
            ?? session.workoutTitle

        let totalSets = max(currentExercise?.sets ?? 1, 1)
        let done = currentExercise.map { workoutStore.completedSets(for: $0.id) } ?? 0
        let setsLabel = SetProgressFormatting.progressLabel(completed: done, totalSets: totalSets)

        let elapsed = workoutStore.exerciseRecords
            .first(where: { $0.exerciseId == currentExercise?.id })?
            .elapsedSeconds
            ?? workoutStore.exerciseRecords[safe: workoutStore.currentExerciseIndex]?.elapsedSeconds
            ?? 0

        let isResting = timerService.isRunning
            || timerService.isAwaitingResumeAcknowledgment

        WorkoutLiveActivityController.shared.startOrUpdate(
            session: session,
            exerciseName: exerciseName,
            setsLabel: setsLabel,
            exerciseElapsedSeconds: elapsed,
            isResting: isResting,
            restEndDate: timerService.restEndDate
        )
    }

    static func end() {
        WorkoutLiveActivityController.shared.end()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
