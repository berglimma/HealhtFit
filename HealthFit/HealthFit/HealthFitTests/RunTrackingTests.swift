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

    func testCyclingSpeedClassification() {
        XCTAssertEqual(
            RunTrackingMath.activityState(fromSpeedMetersPerSecond: 0.3, modality: .cycling),
            .stationary
        )
        XCTAssertEqual(
            RunTrackingMath.activityState(fromSpeedMetersPerSecond: 3.0, modality: .cycling),
            .lightCycling
        )
        XCTAssertEqual(
            RunTrackingMath.activityState(fromSpeedMetersPerSecond: 5.5, modality: .cycling),
            .hardCycling
        )
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

    func testRunningAndOutdoorGPSFlags() {
        let run = CardioWorkoutConfig(
            exercise: TestFixtures.runningExercise,
            intensity: .medium,
            isFreeRun: true
        )
        XCTAssertTrue(run.isRunningSession)
        XCTAssertTrue(run.isOutdoorGPSCardio)
        XCTAssertFalse(run.isOutdoorCyclingSession)

        let pedal = CardioExercise.catalog.first { $0.name == "Bicicleta pedal" }!
        let pedalConfig = CardioWorkoutConfig(exercise: pedal, intensity: .medium)
        XCTAssertFalse(pedalConfig.isRunningSession)
        XCTAssertTrue(pedalConfig.isOutdoorGPSCardio)
        XCTAssertTrue(pedalConfig.isOutdoorCyclingSession)

        let mtb = CardioExercise.catalog.first { $0.name == "Mountain bike" }!
        let mtbConfig = CardioWorkoutConfig(exercise: mtb, intensity: .high)
        XCTAssertTrue(mtbConfig.isOutdoorGPSCardio)
        XCTAssertTrue(mtbConfig.isOutdoorCyclingSession)

        let ergo = CardioExercise.catalog.first { $0.name == "Bicicleta ergométrica" }!
        let ergoConfig = CardioWorkoutConfig(exercise: ergo, intensity: .medium)
        XCTAssertFalse(ergoConfig.isRunningSession)
        XCTAssertFalse(ergoConfig.isOutdoorGPSCardio)
        XCTAssertFalse(ergoConfig.isOutdoorCyclingSession)
    }

    func testWorkoutSessionIsRunningFromTitleAndRoute() {
        let byTitle = WorkoutSession(
            workoutSheetId: UUID(),
            workoutTitle: "Cardio — Corrida livre",
            totalExercises: 1
        )
        XCTAssertTrue(byTitle.isRunningSession)
        XCTAssertTrue(byTitle.isOutdoorGPSCardio)

        var byRoute = WorkoutSession(
            workoutSheetId: UUID(),
            workoutTitle: "Cardio — Outdoor",
            totalExercises: 1
        )
        byRoute.routePoints = [
            RouteCoordinate(latitude: -23.55, longitude: -46.63),
            RouteCoordinate(latitude: -23.551, longitude: -46.631)
        ]
        XCTAssertTrue(byRoute.isRunningSession)
        XCTAssertTrue(byRoute.isOutdoorGPSCardio)

        let bike = WorkoutSession(
            workoutSheetId: UUID(),
            workoutTitle: "Cardio — Bicicleta pedal",
            totalExercises: 1
        )
        XCTAssertFalse(bike.isRunningSession)
        XCTAssertTrue(bike.isOutdoorCyclingSession)
        XCTAssertTrue(bike.isOutdoorGPSCardio)

        let ergo = WorkoutSession(
            workoutSheetId: UUID(),
            workoutTitle: "Cardio — Bicicleta ergométrica",
            totalExercises: 1
        )
        XCTAssertFalse(ergo.isRunningSession)
        XCTAssertFalse(ergo.isOutdoorGPSCardio)
    }

    func testDisplayPaceFromDistanceAndDuration() {
        var session = WorkoutSession(
            workoutSheetId: UUID(),
            workoutTitle: "Cardio — Corrida livre",
            startedAt: Date(timeIntervalSince1970: 0),
            endedAt: Date(timeIntervalSince1970: 600),
            totalExercises: 1,
            completedDistanceKm: 2.0
        )
        XCTAssertEqual(session.displayDistanceKm, 2.0, accuracy: 0.001)
        XCTAssertEqual(session.displayPaceSecondsPerKm, 300)

        session.averagePaceSecondsPerKm = 280
        XCTAssertEqual(session.displayPaceSecondsPerKm, 280)
    }

    func testDistanceKmFromRoutePoints() {
        let a = RouteCoordinate(latitude: -23.5500, longitude: -46.6300)
        let b = RouteCoordinate(latitude: -23.5500, longitude: -46.6400)
        let km = RunTrackingMath.distanceKm(from: [a, b])
        XCTAssertGreaterThan(km, 0.8)
        XCTAssertLessThan(km, 1.3)
    }

    func testRoutePerformanceColoringFasterIsGreener() {
        // Segment speeds come from the destination point: 2.5 then 4.0 → median 3.25
        // 2.5/3.25 ≈ 0.77 → below; 4.0/3.25 ≈ 1.23 → optimal
        let slow = RouteCoordinate(
            latitude: -23.55,
            longitude: -46.63,
            timestamp: Date(timeIntervalSince1970: 0),
            speedMetersPerSecond: 1.0
        )
        let mid = RouteCoordinate(
            latitude: -23.5505,
            longitude: -46.6305,
            timestamp: Date(timeIntervalSince1970: 10),
            speedMetersPerSecond: 2.5
        )
        let fast = RouteCoordinate(
            latitude: -23.5510,
            longitude: -46.6310,
            timestamp: Date(timeIntervalSince1970: 20),
            speedMetersPerSecond: 4.0
        )
        let segments = RoutePerformanceColoring.segments(from: [slow, mid, fast], metric: .pace)
        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0].band, .below)
        XCTAssertEqual(segments[1].band, .optimal)
        XCTAssertLessThan(segments[0].performanceScore, segments[1].performanceScore)
    }

    func testRoutePerformanceBandsRelativeToMedian() {
        let median = 3.0
        XCTAssertEqual(
            RoutePerformanceColoring.band(forSpeed: 3.3, medianMovingSpeed: median),
            .optimal
        ) // 110%
        XCTAssertEqual(
            RoutePerformanceColoring.band(forSpeed: 3.0, medianMovingSpeed: median),
            .intermediate
        )
        XCTAssertEqual(
            RoutePerformanceColoring.band(forSpeed: 2.7, medianMovingSpeed: median),
            .intermediate
        ) // exatamente 90% ainda é intermediário (< 90% = abaixo)
        XCTAssertEqual(
            RoutePerformanceColoring.band(forSpeed: 2.69, medianMovingSpeed: median),
            .below
        )
        XCTAssertEqual(
            RoutePerformanceColoring.band(forSpeed: 0.2, medianMovingSpeed: median),
            .stopped
        )
    }

    func testRoutePerformanceStoppedIsGrayNotRed() {
        let a = RouteCoordinate(
            latitude: -23.55,
            longitude: -46.63,
            timestamp: Date(timeIntervalSince1970: 0),
            speedMetersPerSecond: 3.0
        )
        let stopped = RouteCoordinate(
            latitude: -23.5501,
            longitude: -46.6301,
            timestamp: Date(timeIntervalSince1970: 5),
            speedMetersPerSecond: 0.1
        )
        let moving = RouteCoordinate(
            latitude: -23.5505,
            longitude: -46.6305,
            timestamp: Date(timeIntervalSince1970: 15),
            speedMetersPerSecond: 3.0
        )
        let segments = RoutePerformanceColoring.segments(from: [a, stopped, moving], metric: .speed)
        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0].band, .stopped)
        XCTAssertEqual(segments[1].band, .intermediate)
        XCTAssertNotEqual(
            RoutePerformanceColoring.color(for: .stopped),
            RoutePerformanceColoring.color(for: .below)
        )
    }

    func testRoutePerformanceMedianHelper() {
        XCTAssertEqual(RoutePerformanceColoring.median(of: [1, 3, 2]), 2)
        XCTAssertEqual(RoutePerformanceColoring.median(of: [1, 2, 3, 4]), 2.5)
        XCTAssertNil(RoutePerformanceColoring.median(of: []))
    }

    func testRoutePerformanceDiscreteScoreMapping() {
        // Scores map to discrete bands (Color equality is unreliable across instances).
        XCTAssertEqual(RoutePerformanceBand.below.performanceScore, 0)
        XCTAssertEqual(RoutePerformanceBand.intermediate.performanceScore, 0.5)
        XCTAssertEqual(RoutePerformanceBand.optimal.performanceScore, 1)
        XCTAssertEqual(RoutePerformanceBand.stopped.performanceScore, -1)
        XCTAssertNotEqual(
            RoutePerformanceColoring.color(for: .optimal),
            RoutePerformanceColoring.color(for: .below)
        )
        XCTAssertNotEqual(
            RoutePerformanceColoring.color(for: .intermediate),
            RoutePerformanceColoring.color(for: .below)
        )
        XCTAssertNotEqual(
            RoutePerformanceColoring.color(for: .stopped),
            RoutePerformanceColoring.color(for: .below)
        )
    }

    func testCatalogIncludesBikeModalities() {
        let names = Set(CardioExercise.catalog.map(\.name))
        XCTAssertTrue(names.contains("Mountain bike"))
        XCTAssertTrue(names.contains("Bicicleta pedal"))
        XCTAssertTrue(names.contains("Bicicleta ergométrica"))
        XCTAssertFalse(names.contains("Bicicleta"))
    }
}
