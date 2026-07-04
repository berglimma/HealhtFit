import XCTest
@testable import HealthFit

final class WeeklyProgressAnalyzerTests: XCTestCase {
    func testEmptySessionsProducesLowScore() {
        let report = WeeklyProgressAnalyzer.buildReport(sessions: [], goal: .maintenance)
        XCTAssertEqual(report.currentWeek.workoutCount, 0)
        XCTAssertEqual(report.overallScore, 0)
        XCTAssertFalse(report.improvements.isEmpty)
    }

    func testDetectsMeditationSession() {
        let session = TestFixtures.meditationSession()
        XCTAssertTrue(WeeklyProgressAnalyzer.isMeditationSession(session))
    }
}
