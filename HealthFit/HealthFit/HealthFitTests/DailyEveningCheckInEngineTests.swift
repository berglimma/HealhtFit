import XCTest
@testable import HealthFit

final class DailyEveningCheckInEngineTests: XCTestCase {
    func testCheckInWindowOpensAt21() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let components = DateComponents(year: 2026, month: 7, day: 4, hour: 20, minute: 59)
        let before = calendar.date(from: components)!
        let after = calendar.date(byAdding: .minute, value: 2, to: before)!

        XCTAssertFalse(DailyEveningCheckInEngine.isCheckInWindowOpen(now: before))
        XCTAssertTrue(DailyEveningCheckInEngine.isCheckInWindowOpen(now: after))
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
        XCTAssertTrue(closing.last?.contains("Boa noite") == true)
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
            dailyCalorieTarget: dailyCalorieTarget,
            basalMetabolicRate: basalMetabolicRate,
            estimatedTDEE: estimatedTDEE,
            caloricDeficit: caloricDeficit,
            sweetConsumption: sweetConsumption,
            lactoseTolerance: lactoseTolerance
        )
    }
}
