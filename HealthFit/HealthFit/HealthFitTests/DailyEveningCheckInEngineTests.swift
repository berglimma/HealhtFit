import XCTest
@testable import HealthFit

final class DailyEveningCheckInEngineTests: XCTestCase {
    func testCheckInWindowOpensAt21Local() {
        // Build dates in device-local wall clock so the assertion is timezone-portable.
        let calendar = MotivationMessages.localCalendar
        let before = calendar.date(from: DateComponents(year: 2026, month: 7, day: 4, hour: 20, minute: 59))!
        let after = calendar.date(from: DateComponents(year: 2026, month: 7, day: 4, hour: 21, minute: 1))!

        XCTAssertFalse(DailyEveningCheckInEngine.isCheckInWindowOpen(now: before, calendar: calendar))
        XCTAssertTrue(DailyEveningCheckInEngine.isCheckInWindowOpen(now: after, calendar: calendar))
    }

    func testOpeningMessageIncludesTodayWorkouts() {
        let session = TestFixtures.completedWorkoutSession(workoutTitle: "Treino Peito")
        let context = TestFixtures.assistantContext().withTodayWorkouts([session])
        let message = DailyEveningCheckInEngine.openingMessage(athleteName: "João", context: context)

        XCTAssertTrue(message.contains("Treino Peito"))
        XCTAssertTrue(message.contains("Agora são"))
        XCTAssertFalse(message.contains("São 21h"))
    }

    func testOpeningMessageWithoutWorkoutsIsMotivational() {
        let context = TestFixtures.assistantContext()
        let message = DailyEveningCheckInEngine.openingMessage(athleteName: "João", context: context)

        XCTAssertTrue(message.contains("Não vi treinos registrados hoje"))
        XCTAssertTrue(message.contains("descanso"))
    }

    func testClassifySkippedWorkoutFeeling() {
        XCTAssertEqual(
            DailyEveningCheckInEngine.classifyDayFeeling("Não treinei hoje"),
            .skippedWorkout
        )
    }

    func testDayReflectionFollowUpAsksAboutRest() {
        let context = TestFixtures.assistantContext()
        let followUp = DailyEveningCheckInEngine.dayReflectionFollowUp(
            feeling: .good,
            context: context
        )

        XCTAssertTrue(followUp.contains("cama"))
        XCTAssertTrue(followUp.contains("corpo"))
    }

    func testClosingSequenceHasMultipleMessages() {
        let context = TestFixtures.assistantContext()
        let closing = DailyEveningCheckInEngine.closingSequence(
            readiness: .readyToSleep,
            dayFeeling: .great,
            context: context
        )

        XCTAssertEqual(closing.count, 3)
        let farewell = closing.last ?? ""
        XCTAssertTrue(
            farewell.contains("Bom descanso")
                || farewell.contains("Descanse bem")
                || farewell.contains("Boa noite de descanso")
                || farewell.contains("Durma bem")
                || farewell.contains("Descanse"),
            "Expected rest-oriented farewell after check-in, got: \(farewell)"
        )
    }

    func testDetectsOffTopicQuestionVersusDayFeeling() {
        XCTAssertTrue(DailyEveningCheckInEngine.isDayFeelingReply("Foi um dia ótimo"))
        XCTAssertFalse(DailyEveningCheckInEngine.isDayFeelingReply("Qual é meu IMC?"))
        XCTAssertFalse(DailyEveningCheckInEngine.isDayFeelingReply("Como montar um cardápio"))
        XCTAssertTrue(
            DailyEveningCheckInEngine.reminderToAnswerDayFeeling()
                .hasPrefix("Quando puder, me responde também:")
        )
    }

    func testCompletedSessionsTodayFiltersByDate() {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let sessions = [
            TestFixtures.completedWorkoutSession(endedAt: today),
            TestFixtures.completedWorkoutSession(endedAt: yesterday)
        ]

        let todaySessions = DailyEveningCheckInEngine.completedSessionsToday(from: sessions, on: today)
        XCTAssertEqual(todaySessions.count, 1)
    }
}

private extension HealthAssistantContext {
    func withTodayWorkouts(_ sessions: [WorkoutSession]) -> HealthAssistantContext {
        HealthAssistantContext(
            user: user,
            waterIntakeMl: waterIntakeMl,
            sleepHours: sleepHours,
            weeklyWorkoutCount: weeklyWorkoutCount,
            hoursSinceLastWorkout: hoursSinceLastWorkout,
            todayWorkoutSessions: sessions,
            recentWorkoutSessions: recentWorkoutSessions,
            dailyCalorieTarget: dailyCalorieTarget,
            basalMetabolicRate: basalMetabolicRate,
            estimatedTDEE: estimatedTDEE,
            caloricDeficit: caloricDeficit,
            sweetConsumption: sweetConsumption,
            lactoseTolerance: lactoseTolerance,
            hasMealPlan: hasMealPlan,
            todayMealsCompleted: todayMealsCompleted,
            todayMealsTotal: todayMealsTotal,
            weekMealsCompleted: weekMealsCompleted,
            weekMealsTotal: weekMealsTotal,
            supplementsLoggedToday: supplementsLoggedToday
        )
    }
}

// MARK: - Day-part greetings (app-wide local windows)

extension DailyEveningCheckInEngineTests {
    /// Proves classification is by local hour on the *passed* calendar — not a hard-coded Brazil zone.
    func testDayPartGreetingWindowsAcrossTimeZones() {
        let zones = [
            "UTC",
            "Europe/London",
            "America/New_York",
            "Asia/Tokyo",
            "America/Sao_Paulo"
        ]

        for zoneId in zones {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: zoneId)!

            func date(hour: Int, minute: Int = 0) -> Date {
                calendar.date(from: DateComponents(year: 2026, month: 8, day: 3, hour: hour, minute: minute))!
            }

            XCTAssertEqual(
                MotivationMessages.dayPartWindow(for: date(hour: 6), calendar: calendar),
                .morning,
                "zone \(zoneId)"
            )
            XCTAssertEqual(MotivationMessages.dayPartGreeting(for: date(hour: 6), calendar: calendar), "Bom dia")
            XCTAssertEqual(MotivationMessages.dayPartGreeting(for: date(hour: 11, minute: 59), calendar: calendar), "Bom dia")
            XCTAssertEqual(MotivationMessages.dayPartGreeting(for: date(hour: 12), calendar: calendar), "Boa tarde")
            XCTAssertEqual(MotivationMessages.dayPartGreeting(for: date(hour: 17, minute: 59), calendar: calendar), "Boa tarde")
            XCTAssertEqual(MotivationMessages.dayPartGreeting(for: date(hour: 18), calendar: calendar), "Boa noite")
            XCTAssertEqual(MotivationMessages.dayPartGreeting(for: date(hour: 19, minute: 59), calendar: calendar), "Boa noite")

            let rest = MotivationMessages.dayPartGreeting(for: date(hour: 20), calendar: calendar)
            XCTAssertTrue(
                ["Bom descanso", "Descanse bem", "Boa noite de descanso"].contains(rest),
                "20h local rest greeting in \(zoneId), got: \(rest)"
            )
            XCTAssertTrue(MotivationMessages.isRestWindow(for: date(hour: 20), calendar: calendar), zoneId)
            XCTAssertTrue(MotivationMessages.isRestWindow(for: date(hour: 23), calendar: calendar), zoneId)
            XCTAssertTrue(MotivationMessages.isRestWindow(for: date(hour: 3), calendar: calendar), zoneId)
            XCTAssertFalse(MotivationMessages.isRestWindow(for: date(hour: 19, minute: 59), calendar: calendar), zoneId)

            XCTAssertEqual(
                MotivationMessages.namedGreeting(name: "João", date: date(hour: 9), calendar: calendar),
                "Bom dia, João!"
            )
        }
    }

    func testOpeningMessageAfter20UsesRestGreeting() {
        // 21:05 in *device* local wall clock (same basis as production dayPartGreeting).
        let calendar = MotivationMessages.localCalendar
        let night = calendar.date(from: DateComponents(year: 2026, month: 8, day: 3, hour: 21, minute: 5))!
        let context = TestFixtures.assistantContext()
        let message = DailyEveningCheckInEngine.openingMessage(
            athleteName: "João",
            context: context,
            now: night
        )
        let rest = MotivationMessages.dayPartGreeting(for: night, calendar: calendar)
        XCTAssertTrue(message.hasPrefix("\(rest), João!"), "got: \(message.prefix(80))")
        XCTAssertTrue(MotivationMessages.isRestWindow(for: night, calendar: calendar))
    }
}
