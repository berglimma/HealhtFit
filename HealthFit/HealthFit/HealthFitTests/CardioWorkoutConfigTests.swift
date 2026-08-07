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
        // Meta de kcal = sessão aberta (só encerra no Finalizar).
        XCTAssertEqual(withGoal.targetDurationSeconds, 0)
        XCTAssertGreaterThan(withoutGoal.targetDurationSeconds, 0)
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

    func testKitesurfTitleIsNotCorridaLivre() {
        let kite = CardioExercise.catalog.first(where: { $0.name == "Kitesurf" })!
        let setup = WaterSportSetup.defaultKite()
        let config = CardioWorkoutConfig(
            exercise: kite,
            intensity: .medium,
            isFreeRun: true,
            waterSportSetup: setup
        )
        XCTAssertTrue(config.isKitesurfSession)
        XCTAssertTrue(config.isFreeRun)
        XCTAssertEqual(config.title, "Cardio — Kitesurf · \(setup.ridingMode!.rawValue)")
        XCTAssertFalse(config.title.lowercased().contains("corrida"))
    }

    func testSurfTitleIsNotCorridaLivre() {
        let surf = CardioExercise.catalog.first(where: { $0.name == "Surf" })!
        let setup = WaterSportSetup.defaultSurf()
        let config = CardioWorkoutConfig(
            exercise: surf,
            intensity: .medium,
            isFreeRun: true,
            waterSportSetup: setup
        )
        XCTAssertTrue(config.isSurfSession)
        XCTAssertTrue(config.title.hasPrefix("Cardio — Surf"))
        XCTAssertFalse(config.title.lowercased().contains("corrida"))
    }

    func testKitesurfTitleWithoutRidingMode() {
        let kite = CardioExercise.catalog.first(where: { $0.name == "Kitesurf" })!
        var setup = WaterSportSetup.defaultKite()
        setup.ridingMode = nil
        setup.spot = WaterSpotInfo(name: "Joaquina")
        let config = CardioWorkoutConfig(
            exercise: kite,
            intensity: .medium,
            isFreeRun: true,
            waterSportSetup: setup
        )
        XCTAssertEqual(config.title, "Cardio — Kitesurf · Joaquina")
    }

    func testSwimLapsFromWatchDistance() {
        XCTAssertEqual(CardioWorkoutConfig.swimLaps(fromDistanceMeters: 0, poolLengthMeters: 25), 0)
        XCTAssertEqual(CardioWorkoutConfig.swimLaps(fromDistanceMeters: 24.9, poolLengthMeters: 25), 0)
        XCTAssertEqual(CardioWorkoutConfig.swimLaps(fromDistanceMeters: 25, poolLengthMeters: 25), 1)
        XCTAssertEqual(CardioWorkoutConfig.swimLaps(fromDistanceMeters: 1000, poolLengthMeters: 25), 40)
        XCTAssertEqual(CardioWorkoutConfig.swimLaps(fromDistanceMeters: 1500, poolLengthMeters: 50), 30)
    }
}
