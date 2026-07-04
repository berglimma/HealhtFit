import XCTest
@testable import HealthFit

final class PaceFormattingTests: XCTestCase {
    func testFormatPace() {
        XCTAssertEqual(PaceFormatting.format(secondsPerKm: 305), "5:05 /km")
    }

    func testFormatDurationWithHours() {
        XCTAssertEqual(PaceFormatting.formatDuration(seconds: 3661), "1:01:01")
    }

    func testProjectedFinish() {
        XCTAssertEqual(PaceFormatting.projectedFinish(secondsPerKm: 300, distanceKm: 10), 3000)
    }
}
