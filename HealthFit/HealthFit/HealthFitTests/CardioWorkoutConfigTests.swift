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
}
