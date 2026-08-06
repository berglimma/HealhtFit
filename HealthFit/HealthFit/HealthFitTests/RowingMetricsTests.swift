import XCTest
@testable import HealthFit

final class RowingMetricsTests: XCTestCase {
    func testSPMZoneClassification() {
        XCTAssertEqual(RowingSPMZone.classify(spm: 19), .recovery)
        XCTAssertEqual(RowingSPMZone.classify(spm: 22), .endurance)
        XCTAssertEqual(RowingSPMZone.classify(spm: 26), .technical)
        XCTAssertEqual(RowingSPMZone.classify(spm: 32), .race)
        XCTAssertEqual(RowingSPMZone.classify(spm: 40), .sprint)
        XCTAssertEqual(RowingSPMZone.classify(spm: 29), .transition)
    }

    func testSplitAndMetersPerStroke() {
        // 4 m/s → 500/4 = 125 s → 2:05
        let split = RowingMetricsMath.splitSecondsPer500m(speedMetersPerSecond: 4.0)
        XCTAssertEqual(split!, 125, accuracy: 0.01)
        XCTAssertEqual(RowingMetricsMath.formatSplit(seconds: 125), "2:05")

        let mps = RowingMetricsMath.metersPerStroke(distanceMeters: 2000, strokes: 200)
        XCTAssertEqual(mps, 10, accuracy: 0.01)
    }

    func testEfficiencyPenalizesAsymmetry() {
        let balanced = RowingMetricsMath.efficiencyScore(
            metersPerStroke: 10,
            speedMps: 3.5,
            stabilityScore: 80,
            balanceScore: 80,
            asymmetryPercent: 4
        )
        let asymmetric = RowingMetricsMath.efficiencyScore(
            metersPerStroke: 10,
            speedMps: 3.5,
            stabilityScore: 80,
            balanceScore: 80,
            asymmetryPercent: 30
        )
        XCTAssertGreaterThan(balanced, asymmetric)
    }

    func testRowingConfigTitleAndFlags() {
        let remo = CardioExercise.catalog.first { $0.isRowing }!
        XCTAssertTrue(remo.supportsOutdoorGPS)
        XCTAssertTrue(remo.supportsCustomDistanceGoals)

        let config = CardioWorkoutConfig(
            exercise: remo,
            intensity: .medium,
            isFreeRun: true,
            rowingSetup: RowingSetup(boatType: .singleSkiff)
        )
        XCTAssertTrue(config.isRowingSession)
        XCTAssertTrue(config.title.contains("Single Skiff"))
        XCTAssertEqual(config.outdoorTrackingModality, .rowing)
        XCTAssertEqual(config.routePerformanceMetric, .speed)
    }

    func testSessionRoundTripRowingSnapshot() throws {
        var session = WorkoutSession(
            workoutSheetId: UUID(),
            workoutTitle: "Cardio — Remo · Double"
        )
        session.rowing = RowingSessionSnapshot(
            boatType: .double,
            totalStrokes: 120,
            averageSPM: 24,
            peakSPM: 28,
            averageSplitSecondsPer500m: 130,
            metersPerStroke: 9.5,
            efficiencyScore: 72,
            stabilityScore: 80,
            balanceScore: 75,
            leftSideShare: 0.48,
            rightSideShare: 0.52,
            asymmetryPercent: 4,
            distanceMeters: 1140
        )
        XCTAssertTrue(session.isRowingSession)
        XCTAssertTrue(session.isOutdoorGPSCardio)

        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(WorkoutSession.self, from: data)
        XCTAssertEqual(decoded.rowing?.boatType, .double)
        XCTAssertEqual(decoded.rowing?.totalStrokes, 120)
        XCTAssertEqual(decoded.rowing?.formattedAverageSplit, "2:10")
    }
}
