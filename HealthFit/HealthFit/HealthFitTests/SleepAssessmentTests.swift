import XCTest
@testable import HealthFit

final class SleepAssessmentTests: XCTestCase {
    func testIdealSleepRange() {
        XCTAssertEqual(SleepAssessment.evaluate(hours: 8), .ideal)
    }

    func testUnregulatedSleepBelowFiveHours() {
        XCTAssertEqual(SleepAssessment.evaluate(hours: 4.5), .unregulated)
    }
}
