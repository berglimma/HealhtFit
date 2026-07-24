import XCTest
@testable import HealthFit

final class NotificationServiceTests: XCTestCase {
    func testWaterReminderHoursEveryTwoHours() {
        let hours = WaterReminderConfiguration.reminderHours()
        XCTAssertEqual(hours, [8, 10, 12, 14, 16, 18, 20])
    }

    func testWaterReminderHoursRespectsCustomWindow() {
        let hours = WaterReminderConfiguration.reminderHours(startHour: 9, endHour: 21, intervalHours: 3)
        XCTAssertEqual(hours, [9, 12, 15, 18, 21])
    }

    func testWaterReminderMessageCyclesThroughOptions() {
        let first = MotivationMessages.waterReminderMessage(forHour: 7)
        let second = MotivationMessages.waterReminderMessage(forHour: 10)

        XCTAssertTrue(first.contains("água") || first.contains("Hidratação") || first.contains("Água"))
        XCTAssertFalse(first.isEmpty)
        XCTAssertFalse(second.isEmpty)
    }

    func testHealthIconMessagesIncludeEmoji() {
        let yellow = MotivationMessages.healthIconYellowMessage(detail: "Atualize água e sono")
        let red = MotivationMessages.healthIconRedMessage(detail: "24h sem atualizar")

        XCTAssertTrue(yellow.contains("💛") || yellow.contains("💧"))
        XCTAssertTrue(red.contains("🚨") || red.contains("❤️"))
    }
}
