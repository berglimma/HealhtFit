import Foundation
import WidgetKit

enum HealthFitWidgetBridge {
    @MainActor
    static func refresh(
        workoutStore: WorkoutStore,
        gender: Gender? = nil,
        todayCalories: Double
    ) {
        let resolvedGender = gender ?? .male
        let sessions = workoutStore.sessionHistory
        let sheets = workoutStore.workoutSheets

        var candidates: [WorkoutSheet] = []
        candidates += workoutStore.recommendedStandardWorkouts(for: resolvedGender)
        candidates += workoutStore.atletaStandardWorkouts(for: resolvedGender)
        candidates += workoutStore.militarStandardWorkouts(for: resolvedGender)
        candidates += workoutStore.shapeStandardWorkouts(for: resolvedGender)
        candidates += workoutStore.customWorkoutSheets(for: resolvedGender)
        candidates += sheets.filter { $0.isCoachPrescribed && $0.isActive }

        let suggestion = WorkoutDaySuggestionAnalyzer.suggestWorkoutOfTheDay(
            sessions: sessions,
            candidateSheets: candidates,
            sheetsCatalog: sheets
        )
        let lift = WorkoutDaySuggestionAnalyzer.bestRecentLift(sessions: sessions, sheets: sheets)
        let weekCount = WorkoutDaySuggestionAnalyzer.strengthSessionsThisWeek(sessions: sessions)
        let streak = WorkoutDaySuggestionAnalyzer.streakDays(sessions: sessions)

        let snapshot = HealthFitWidgetSnapshot(
            updatedAt: .now,
            liftWeightKg: lift?.weightKg,
            liftExerciseName: lift?.exerciseName ?? "Sem carga recente",
            liftEquipmentHint: lift?.equipment ?? "",
            workoutsThisWeek: weekCount,
            weeklyGoal: WorkoutDaySuggestionAnalyzer.weeklyGoalDefault,
            todayCalories: max(0, Int(todayCalories.rounded())),
            workoutOfDayTitle: suggestion?.sheet.title ?? "Treino do dia",
            workoutOfDaySubtitle: suggestion?.reason ?? "Abra o app para personalizar a sugestão",
            streakDays: streak
        )
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
