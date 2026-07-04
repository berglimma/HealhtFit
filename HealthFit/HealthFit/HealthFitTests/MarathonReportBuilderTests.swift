import XCTest
@testable import HealthFit

final class MarathonReportBuilderTests: XCTestCase {
    func testIsDistanceRunSessionRequiresPositiveTarget() {
        var session = TestFixtures.distanceRunSession(targetKm: 10)
        XCTAssertTrue(MarathonReportBuilder.isDistanceRunSession(session))

        session.targetDistanceKm = nil
        XCTAssertFalse(MarathonReportBuilder.isDistanceRunSession(session))
    }

    func testBuildReturnsNilForNonDistanceSession() {
        let session = WorkoutSession(
            workoutSheetId: TestFixtures.sheetId,
            workoutTitle: "Musculação A",
            endedAt: .now
        )
        XCTAssertNil(MarathonReportBuilder.build(session: session, allSessions: [session]))
    }

    func testGoalReachedWhenCompletedAtLeast98Percent() {
        let session = TestFixtures.distanceRunSession(targetKm: 10, completedKm: 9.9, elapsedSeconds: 3600)
        let report = MarathonReportBuilder.build(session: session, allSessions: [session])
        XCTAssertNotNil(report)
        XCTAssertTrue(report!.goalReached)
    }

    func testPreviousBestTimeDetected() {
        let older = TestFixtures.distanceRunSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            targetKm: 10,
            elapsedSeconds: 3900,
            startedAt: Date().addingTimeInterval(-86_400)
        )
        let current = TestFixtures.distanceRunSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            targetKm: 10,
            elapsedSeconds: 3600
        )

        let report = MarathonReportBuilder.build(session: current, allSessions: [older, current])
        XCTAssertEqual(report?.previousBestSeconds, 3900)
        XCTAssertEqual(report?.improvementSeconds, -300)
    }

    func testMarathonProjectionUsesPace() {
        let session = TestFixtures.distanceRunSession(targetKm: 10, elapsedSeconds: 3000, paceSecondsPerKm: 300)
        let report = MarathonReportBuilder.build(session: session, allSessions: [session])
        let expected = PaceFormatting.projectedFinish(secondsPerKm: 300, distanceKm: PaceFormatting.marathonDistanceKm)
        XCTAssertEqual(report?.projectedMarathonSeconds, expected)
    }
}
