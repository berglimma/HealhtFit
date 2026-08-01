import XCTest
@testable import HealthFit

final class RunTrackingTests: XCTestCase {
    func testSpeedClassificationThresholds() {
        XCTAssertEqual(RunTrackingMath.activityState(fromSpeedMetersPerSecond: 0.2), .stationary)
        XCTAssertEqual(RunTrackingMath.activityState(fromSpeedMetersPerSecond: 0.5), .walking)
        XCTAssertEqual(RunTrackingMath.activityState(fromSpeedMetersPerSecond: 1.5), .walking)
        XCTAssertEqual(RunTrackingMath.activityState(fromSpeedMetersPerSecond: 2.0), .running)
        XCTAssertEqual(RunTrackingMath.activityState(fromSpeedMetersPerSecond: 3.5), .running)
    }

    func testEstimatedStepsFromDistance() {
        XCTAssertEqual(RunTrackingMath.estimatedSteps(distanceKm: 0), 0)
        XCTAssertEqual(RunTrackingMath.estimatedSteps(distanceKm: 1), 1_312)
        XCTAssertEqual(RunTrackingMath.estimatedSteps(distanceKm: 0.5), 656)
    }

    func testEstimatedCaloriesUsesMETAndWeight() {
        let calories = RunTrackingMath.estimatedCalories(
            weightKg: 70,
            elapsedSeconds: 3600,
            activityState: .running,
            speedMetersPerSecond: nil
        )
        // 9.8 MET × 70 kg × 1 h
        XCTAssertEqual(calories, 9.8 * 70, accuracy: 0.01)
    }

    func testElapsedClockAlwaysIncludesHours() {
        XCTAssertEqual(DurationFormatting.formatElapsedClock(seconds: 0), "0:00:00")
        XCTAssertEqual(DurationFormatting.formatElapsedClock(seconds: 65), "0:01:05")
        XCTAssertEqual(DurationFormatting.formatElapsedClock(seconds: 3661), "1:01:01")
    }

    func testRouteCoordinateRoundTrip() throws {
        let point = RouteCoordinate(latitude: -23.55, longitude: -46.63, altitude: 760)
        let data = try JSONEncoder().encode([point])
        let decoded = try JSONDecoder().decode([RouteCoordinate].self, from: data)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].latitude, -23.55, accuracy: 0.0001)
        XCTAssertEqual(decoded[0].longitude, -46.63, accuracy: 0.0001)
    }

    func testWorkoutSessionPersistsRouteAndSteps() throws {
        var session = WorkoutSession(
            workoutSheetId: UUID(),
            workoutTitle: "Cardio — Corrida livre",
            totalExercises: 1
        )
        session.routePoints = [
            RouteCoordinate(latitude: -23.55, longitude: -46.63),
            RouteCoordinate(latitude: -23.551, longitude: -46.631)
        ]
        session.stepCount = 420
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(WorkoutSession.self, from: data)
        XCTAssertEqual(decoded.routePoints.count, 2)
        XCTAssertEqual(decoded.stepCount, 420)
    }

    func testRunningSessionFlag() {
        let run = CardioWorkoutConfig(
            exercise: TestFixtures.runningExercise,
            intensity: .medium,
            isFreeRun: true
        )
        XCTAssertTrue(run.isRunningSession)

        let bike = CardioExercise.catalog.first { $0.name == "Bicicleta" }!
        let bikeConfig = CardioWorkoutConfig(exercise: bike, intensity: .medium)
        XCTAssertFalse(bikeConfig.isRunningSession)
    }
}
