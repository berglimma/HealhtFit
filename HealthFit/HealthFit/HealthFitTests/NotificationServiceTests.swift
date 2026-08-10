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

    @MainActor
    func testMealReminderFiresAtRegisteredMealTime() {
        XCTAssertEqual(MealReminderConfiguration.minutesBeforeMeal, 0)

        let breakfastDefault = MealReminderConfiguration.defaultMealClock(for: .breakfast)
        XCTAssertEqual(breakfastDefault.hour, 7)
        XCTAssertEqual(breakfastDefault.minute, 0)

        let lunchDefault = MealReminderConfiguration.defaultMealClock(for: .lunch)
        XCTAssertEqual(lunchDefault.hour, 12)
        XCTAssertEqual(lunchDefault.minute, 30)

        let prefs = NutritionNotificationPreferences.shared
        prefs.resetToDefaults()
        let breakfast = MealReminderConfiguration.reminderClock(for: .breakfast)
        XCTAssertEqual(breakfast.hour, 7)
        XCTAssertEqual(breakfast.minute, 0)

        let lunch = MealReminderConfiguration.reminderClock(for: .lunch)
        XCTAssertEqual(lunch.hour, 12)
        XCTAssertEqual(lunch.minute, 30)

        let supper = MealReminderConfiguration.reminderClock(for: .supper)
        XCTAssertEqual(supper.hour, 21)
        XCTAssertEqual(supper.minute, 30)
    }

    func testDailyMotivationSchedulesAtSixAM() {
        XCTAssertEqual(DailyMotivationConfiguration.hour, 6)
        XCTAssertEqual(DailyMotivationConfiguration.minute, 0)
        XCTAssertEqual(DailyMotivationConfiguration.scheduledDayCount, 14)
    }

    @MainActor
    func testMealReminderMessageMentionsMealAndTime() {
        NutritionNotificationPreferences.shared.resetToDefaults()
        let message = MotivationMessages.mealReminderMessage(for: .lunch)
        XCTAssertTrue(message.contains("Almoço"))
        XCTAssertTrue(message.contains("12:30"))
    }

    func testWeekdayDailyMotivationMessages() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        func date(year: Int, month: Int, day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 8))!
        }

        // 2026-07-27 = segunda … 2026-08-02 = domingo
        let monday = MotivationMessages.dailyMessage(for: date(year: 2026, month: 7, day: 27))
        let thursday = MotivationMessages.dailyMessage(for: date(year: 2026, month: 7, day: 30))
        let friday = MotivationMessages.dailyMessage(for: date(year: 2026, month: 7, day: 31))
        let saturday = MotivationMessages.dailyMessage(for: date(year: 2026, month: 8, day: 1))
        let sunday = MotivationMessages.dailyMessage(for: date(year: 2026, month: 8, day: 2))

        XCTAssertFalse(monday.hasPrefix("#TBD"))
        XCTAssertFalse(monday.hasPrefix("#sextou"))
        XCTAssertTrue(thursday.hasPrefix("#TBD"))
        XCTAssertTrue(friday.hasPrefix("#sextou"))
        XCTAssertTrue(friday.localizedCaseInsensitiveContains("bebidas leves"))
        XCTAssertTrue(friday.localizedCaseInsensitiveContains("baixa quantidade")
                      || friday.localizedCaseInsensitiveContains("pouca")
                      || friday.localizedCaseInsensitiveContains("poucas"))
        XCTAssertTrue(saturday.localizedCaseInsensitiveContains("FDS")
                      || saturday.localizedCaseInsensitiveContains("sábado"))
        XCTAssertTrue(sunday.localizedCaseInsensitiveContains("Domingo")
                      || sunday.localizedCaseInsensitiveContains("motiv"))
    }

    func testWeekdayDailyNotificationTitles() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let thursday = calendar.date(from: DateComponents(year: 2026, month: 7, day: 30))!
        let friday = calendar.date(from: DateComponents(year: 2026, month: 7, day: 31))!

        XCTAssertEqual(DailyMotivationConfiguration.hour, 6)
        XCTAssertEqual(DailyMotivationConfiguration.minute, 0)
        XCTAssertTrue(MotivationMessages.dailyNotificationTitle(for: thursday).contains("Bom dia, HealthFit"))
        XCTAssertTrue(MotivationMessages.dailyNotificationTitle(for: friday).contains("Bom dia, HealthFit"))
    }
}
