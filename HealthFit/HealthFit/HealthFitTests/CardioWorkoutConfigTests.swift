import XCTest
@testable import HealthFit

final class CardioWorkoutConfigTests: XCTestCase {
    func testFreeRunIsNotDistanceRun() {
        let config = CardioWorkoutConfig(
            exercise: TestFixtures.runningExercise,
            intensity: .medium,
            runningDistance: .ten,
            isFreeRun: true
        )
        XCTAssertTrue(config.isFreeRun)
        XCTAssertFalse(config.isDistanceRun)
        XCTAssertEqual(config.title, "Cardio — Corrida livre")
    }

    func testDistanceRunTargetDurationUsesPace() {
        let config = CardioWorkoutConfig(
            exercise: TestFixtures.runningExercise,
            intensity: .medium,
            runningDistance: .ten
        )
        XCTAssertTrue(config.isDistanceRun)
        XCTAssertEqual(config.targetDistanceKm, 10)
        XCTAssertEqual(config.targetDurationSeconds, 10 * 360)
    }

    func testEstimatedDistanceFromElapsedTime() {
        let config = CardioWorkoutConfig(
            exercise: TestFixtures.runningExercise,
            intensity: .medium,
            runningDistance: .five
        )
        XCTAssertEqual(config.estimatedDistanceKm(elapsedSeconds: 1800), 5, accuracy: 0.01)
    }

    func testCalorieGoalFlag() {
        let withGoal = CardioWorkoutConfig(
            exercise: TestFixtures.runningExercise,
            intensity: .high,
            targetCalories: 400
        )
        let withoutGoal = CardioWorkoutConfig(
            exercise: TestFixtures.runningExercise,
            intensity: .high,
            targetCalories: 0
        )
        XCTAssertTrue(withGoal.hasCalorieGoal)
        XCTAssertFalse(withoutGoal.hasCalorieGoal)
    }

    func testSwimmingPoolConfigAndDistance() {
        let swim = CardioExercise.catalog.first(where: { $0.name == "Natação" })!
        let config = CardioWorkoutConfig(
            exercise: swim,
            intensity: .medium,
            poolLengthMeters: 25,
            targetSwimLaps: 40
        )
        XCTAssertTrue(config.isSwimmingSession)
        XCTAssertEqual(config.resolvedPoolLengthMeters, 25)
        XCTAssertEqual(config.swimDistanceMeters(laps: 40), 1000, accuracy: 0.01)
        XCTAssertEqual(config.targetDistanceKm, 1.0, accuracy: 0.001)
        XCTAssertTrue(config.title.contains("25 m"))
        XCTAssertTrue(config.title.contains("40 voltas"))
        let pace = config.swimPaceSecondsPer100m(elapsedSeconds: 1200, distanceMeters: 1000)
        XCTAssertEqual(pace, 120)
    }

    func testSwimCaloriesEstimateUsesDistance() {
        let swim = CardioExercise.catalog.first(where: { $0.name == "Natação" })!
        let config = CardioWorkoutConfig(exercise: swim, intensity: .high, poolLengthMeters: 50)
        let kcal = config.estimatedSwimCalories(elapsedSeconds: 1800, distanceMeters: 1500, weightKg: 70)
        XCTAssertGreaterThan(kcal, 100)
    }
}
