import Foundation
@testable import HealthFit

enum TestFixtures {
    static let sheetId = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    static let exerciseId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    static func userProfile(
        id: String = "test-user-id",
        name: String = "João Silva",
        email: String = "joao@test.com",
        biotype: Biotype = .mesomorph,
        goal: FitnessGoal = .muscleGain,
        gender: Gender = .male,
        weight: Double = 75,
        height: Double = 175,
        age: Int = 28,
        caloricDeficit: Int = 400
    ) -> UserProfile {
        UserProfile(
            id: id,
            name: name,
            email: email,
            biotype: biotype,
            goal: goal,
            gender: gender,
            weight: weight,
            height: height,
            age: age,
            caloricDeficit: caloricDeficit
        )
    }

    static func assistantContext(
        user: UserProfile? = userProfile(),
        waterIntakeMl: Int = 1200,
        sleepHours: Double? = 6.5,
        weeklyWorkoutCount: Int = 2,
        hoursSinceLastWorkout: Double? = 30,
        todayWorkoutSessions: [WorkoutSession] = [],
        recentWorkoutSessions: [WorkoutSession] = [],
        hasMealPlan: Bool = false,
        todayMealsCompleted: Int = 0,
        todayMealsTotal: Int = 0,
        weekMealsCompleted: Int = 0,
        weekMealsTotal: Int = 0,
        todayCaloriesConsumed: Int = 0,
        todayHealthKitActiveCalories: Int = 0,
        supplementsLoggedToday: Int = 0,
        isTodayRestDay: Bool = false,
        consecutiveTrainingDays: Int = 0
    ) -> HealthAssistantContext {
        HealthAssistantContext(
            user: user,
            waterIntakeMl: waterIntakeMl,
            sleepHours: sleepHours,
            weeklyWorkoutCount: weeklyWorkoutCount,
            hoursSinceLastWorkout: hoursSinceLastWorkout,
            todayWorkoutSessions: todayWorkoutSessions,
            recentWorkoutSessions: recentWorkoutSessions,
            dailyCalorieTarget: user?.dailyCalorieTarget ?? 2500,
            basalMetabolicRate: user?.basalMetabolicRate ?? 1700,
            estimatedTDEE: user?.estimatedTDEE ?? 2600,
            caloricDeficit: user?.caloricDeficit ?? 400,
            sweetConsumption: .moderate,
            lactoseTolerance: .tolerant,
            hasMealPlan: hasMealPlan,
            todayMealsCompleted: todayMealsCompleted,
            todayMealsTotal: todayMealsTotal,
            weekMealsCompleted: weekMealsCompleted,
            weekMealsTotal: weekMealsTotal,
            todayCaloriesConsumed: todayCaloriesConsumed,
            todayHealthKitActiveCalories: todayHealthKitActiveCalories,
            supplementsLoggedToday: supplementsLoggedToday,
            isTodayRestDay: isTodayRestDay,
            consecutiveTrainingDays: consecutiveTrainingDays
        )
    }

    static func distanceRunSession(
        id: UUID = UUID(),
        targetKm: Double = 10,
        completedKm: Double? = nil,
        elapsedSeconds: Int = 3600,
        paceSecondsPerKm: Int = 360,
        intensityLabel: String = "Média",
        startedAt: Date = .now,
        endedAt: Date? = nil
    ) -> WorkoutSession {
        let end = endedAt ?? startedAt.addingTimeInterval(TimeInterval(elapsedSeconds))
        return WorkoutSession(
            id: id,
            workoutSheetId: sheetId,
            workoutTitle: "Cardio — Corrida \(Int(targetKm)) km",
            startedAt: startedAt,
            endedAt: end,
            exerciseRecords: [
                ExerciseSessionRecord(
                    exerciseId: exerciseId,
                    exerciseName: "Corrida",
                    elapsedSeconds: elapsedSeconds,
                    isCompleted: true
                )
            ],
            targetDistanceKm: targetKm,
            completedDistanceKm: completedKm ?? targetKm,
            averagePaceSecondsPerKm: paceSecondsPerKm,
            cardioIntensityLabel: intensityLabel
        )
    }

    static func meditationSession(startedAt: Date = .now) -> WorkoutSession {
        WorkoutSession(
            workoutSheetId: sheetId,
            workoutTitle: "Meditação — Respiração",
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(600),
            exerciseRecords: [
                ExerciseSessionRecord(
                    exerciseId: exerciseId,
                    exerciseName: "Meditação",
                    elapsedSeconds: 600,
                    isCompleted: true
                )
            ]
        )
    }

    static func completedWorkoutSession(
        workoutTitle: String = "Treino A",
        endedAt: Date = .now,
        completedExercises: Int = 6,
        totalExercises: Int = 6
    ) -> WorkoutSession {
        WorkoutSession(
            workoutSheetId: sheetId,
            workoutTitle: workoutTitle,
            startedAt: endedAt.addingTimeInterval(-3600),
            endedAt: endedAt,
            caloriesBurned: 320,
            completedExercises: completedExercises,
            totalExercises: totalExercises,
            exerciseRecords: [
                ExerciseSessionRecord(
                    exerciseId: exerciseId,
                    exerciseName: "Supino reto",
                    elapsedSeconds: 2400,
                    isCompleted: true
                )
            ]
        )
    }

    static var runningExercise: CardioExercise {
        CardioExercise.catalog.first { $0.name == "Corrida" }!
    }
}
