import XCTest
@testable import HealthFit

final class AssistantRestDayEngineTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AssistantRestDayEngine.reset()
    }

    func testConsecutiveTrainingDaysIgnoresMeditationOnlyDays() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var sessions: [WorkoutSession] = []

        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            sessions.append(
                TestFixtures.completedWorkoutSession(
                    workoutTitle: "Meditação — Respiração",
                    endedAt: day.addingTimeInterval(7200)
                )
            )
        }

        XCTAssertEqual(
            WeeklyProgressAnalyzer.consecutiveTrainingDays(in: sessions, through: today),
            0
        )
    }

    func testConsecutiveTrainingDaysCountsSevenWithoutMeditation() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var sessions: [WorkoutSession] = []

        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            sessions.append(
                TestFixtures.completedWorkoutSession(
                    workoutTitle: "Peito e Tríceps",
                    endedAt: day.addingTimeInterval(7200)
                )
            )
            sessions.append(
                TestFixtures.completedWorkoutSession(
                    workoutTitle: "Meditação — Foco",
                    endedAt: day.addingTimeInterval(12_000)
                )
            )
        }

        XCTAssertEqual(
            WeeklyProgressAnalyzer.consecutiveTrainingDays(in: sessions, through: today),
            7
        )
    }

    func testShouldDeliverSevenDayAlertWhenStreakReached() {
        XCTAssertTrue(
            AssistantRestDayEngine.shouldDeliverSevenDayAlert(
                consecutiveDays: 7,
                isRestDay: false
            )
        )
        XCTAssertFalse(
            AssistantRestDayEngine.shouldDeliverSevenDayAlert(
                consecutiveDays: 7,
                isRestDay: true
            )
        )
    }

    func testMatchesRestDayQuestionsNotRestTimer() {
        XCTAssertTrue(AssistantRestDayEngine.matches("Preciso de um dia de descanso"))
        XCTAssertTrue(AssistantRestDayEngine.matches("Treinei 7 dias seguidos, devo descansar?"))
        XCTAssertFalse(AssistantRestDayEngine.matches("Quanto tempo de descanso entre séries?"))
    }

    func testRestDayMarkedMessageIncludesHypertrophy() {
        let context = TestFixtures.assistantContext(
            user: TestFixtures.userProfile(name: "Ana"),
            isTodayRestDay: true,
            consecutiveTrainingDays: 3
        )
        let message = AssistantRestDayEngine.restDayMarkedMessage(context: context)
        XCTAssertTrue(message.contains("Ana"))
        XCTAssertTrue(message.localizedCaseInsensitiveContains("hipertrofia"))
    }

    func testPendingMessageQueueAndConsume() {
        AssistantRestDayEngine.queueRestDayMarkedMessage("Descanso ok")
        XCTAssertEqual(AssistantRestDayEngine.consumePendingMessage(), "Descanso ok")
        XCTAssertNil(AssistantRestDayEngine.consumePendingMessage())
    }
}
