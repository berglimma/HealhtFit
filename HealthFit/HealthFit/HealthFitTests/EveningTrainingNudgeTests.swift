import XCTest
@testable import HealthFit

final class EveningTrainingNudgeTests: XCTestCase {
    func testConfigurationIsEighteenHundredWithThreeHourWindow() {
        XCTAssertEqual(EveningTrainingNudgeConfiguration.hour, 18)
        XCTAssertEqual(EveningTrainingNudgeConfiguration.minute, 0)
        XCTAssertEqual(EveningTrainingNudgeConfiguration.countdownDuration, 3 * 60 * 60)
    }

    func testHasTrainedTodayUsesEndedAt() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        let today = calendar.date(from: DateComponents(year: 2026, month: 7, day: 31, hour: 10))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let trained = WorkoutSession(
            workoutSheetId: UUID(),
            workoutTitle: "A",
            startedAt: today.addingTimeInterval(-3600),
            endedAt: today,
            completedExercises: 1,
            totalExercises: 1
        )
        let old = WorkoutSession(
            workoutSheetId: UUID(),
            workoutTitle: "B",
            startedAt: yesterday.addingTimeInterval(-3600),
            endedAt: yesterday,
            completedExercises: 1,
            totalExercises: 1
        )
        let open = WorkoutSession(
            workoutSheetId: UUID(),
            workoutTitle: "C",
            startedAt: today,
            endedAt: nil,
            completedExercises: 0,
            totalExercises: 1
        )

        XCTAssertTrue(
            EveningTrainingNudgeService.hasTrainedToday(sessions: [trained], calendar: calendar, now: today)
        )
        XCTAssertFalse(
            EveningTrainingNudgeService.hasTrainedToday(sessions: [old, open], calendar: calendar, now: today)
        )
    }

    func testNudgeWindowIsEighteenToTwentyOne() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 31, hour: 12))!

        let window = EveningTrainingNudgeService.nudgeWindow(on: day, calendar: calendar)
        XCTAssertNotNil(window)
        XCTAssertEqual(calendar.component(.hour, from: window!.start), 18)
        XCTAssertEqual(calendar.component(.hour, from: window!.end), 21)
        XCTAssertEqual(window!.end.timeIntervalSince(window!.start), 3 * 60 * 60)
    }

    func testWeekdayEveningMessagesAreDistinctPortuguese() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        func date(year: Int, month: Int, day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 18))!
        }

        // 2026-07-26 = domingo … 2026-08-01 = sábado
        let sunday = MotivationMessages.eveningTrainingNudgeMessage(for: date(year: 2026, month: 7, day: 26))
        let monday = MotivationMessages.eveningTrainingNudgeMessage(for: date(year: 2026, month: 7, day: 27))
        let tuesday = MotivationMessages.eveningTrainingNudgeMessage(for: date(year: 2026, month: 7, day: 28))
        let wednesday = MotivationMessages.eveningTrainingNudgeMessage(for: date(year: 2026, month: 7, day: 29))
        let thursday = MotivationMessages.eveningTrainingNudgeMessage(for: date(year: 2026, month: 7, day: 30))
        let friday = MotivationMessages.eveningTrainingNudgeMessage(for: date(year: 2026, month: 7, day: 31))
        let saturday = MotivationMessages.eveningTrainingNudgeMessage(for: date(year: 2026, month: 8, day: 1))

        XCTAssertTrue(sunday.localizedCaseInsensitiveContains("Domingo"))
        XCTAssertTrue(monday.localizedCaseInsensitiveContains("Segunda"))
        XCTAssertTrue(tuesday.localizedCaseInsensitiveContains("Terça"))
        XCTAssertTrue(wednesday.localizedCaseInsensitiveContains("Quarta"))
        XCTAssertTrue(thursday.localizedCaseInsensitiveContains("Quinta"))
        XCTAssertTrue(friday.localizedCaseInsensitiveContains("Sextou") || friday.localizedCaseInsensitiveContains("Sexta"))
        XCTAssertTrue(saturday.localizedCaseInsensitiveContains("Sábado"))

        let all = [sunday, monday, tuesday, wednesday, thursday, friday, saturday]
        XCTAssertEqual(Set(all).count, 7)
    }

    func testStatusMessageIsPortuguese() {
        XCTAssertEqual(EveningTrainingNudgeService.statusMessage, "Você ainda não treinou hoje")
    }
}
