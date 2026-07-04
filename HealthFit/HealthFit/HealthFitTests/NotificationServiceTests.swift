import XCTest
@testable import HealthFit

final class NotificationServiceTests: XCTestCase {
    func testWaterReminderHoursEveryThreeHours() {
        let hours = NotificationService.waterReminderHours()
        XCTAssertEqual(hours, [8, 11, 14, 17, 20])
    }

    func testWaterReminderHoursRespectsCustomWindow() {
        let hours = NotificationService.waterReminderHours(startHour: 9, endHour: 21, intervalHours: 3)
        XCTAssertEqual(hours, [9, 12, 15, 18, 21])
    }

    func testWaterReminderMessageCyclesThroughOptions() {
        let first = MotivationMessages.waterReminderMessage(forHour: 7)
        let second = MotivationMessages.waterReminderMessage(forHour: 10)

        XCTAssertTrue(first.contains("água") || first.contains("Hidratação") || first.contains("Água"))
        XCTAssertFalse(first.isEmpty)
        XCTAssertFalse(second.isEmpty)
    }
}
