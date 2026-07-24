import XCTest
@testable import HealthFit

final class AssistantCardioMeditationNudgeEngineTests: XCTestCase {
    func testEvaluateReturnsNilWhenRecentCardioAndMeditation() {
        let now = Date()
        let sessions = [
            TestFixtures.completedWorkoutSession(
                workoutTitle: "Cardio — Corrida",
                endedAt: now.addingTimeInterval(-2 * 3600)
            ),
            TestFixtures.completedWorkoutSession(
                workoutTitle: "Meditação — Respiração",
                endedAt: now.addingTimeInterval(-3 * 3600)
            ),
        ]

        let result = AssistantCardioMeditationNudgeEngine.evaluate(
            sessions: sessions,
            accountCreatedAt: now.addingTimeInterval(-10 * 24 * 3600),
            now: now
        )

        XCTAssertNil(result)
    }

    func testEvaluateReturnsCardioWhenStale() {
        let now = Date()
        let sessions = [
            TestFixtures.completedWorkoutSession(
                workoutTitle: "Cardio — Bike",
                endedAt: now.addingTimeInterval(-50 * 3600)
            ),
            TestFixtures.completedWorkoutSession(
                workoutTitle: "Meditação — Foco",
                endedAt: now.addingTimeInterval(-1 * 3600)
            ),
        ]

        let result = AssistantCardioMeditationNudgeEngine.evaluate(
            sessions: sessions,
            accountCreatedAt: now.addingTimeInterval(-10 * 24 * 3600),
            now: now
        )

        XCTAssertEqual(result?.kind, .cardio)
    }

    func testEvaluateReturnsBothWhenBothStale() {
        let now = Date()
        let created = now.addingTimeInterval(-72 * 3600)

        let result = AssistantCardioMeditationNudgeEngine.evaluate(
            sessions: [],
            accountCreatedAt: created,
            now: now
        )

        XCTAssertEqual(result?.kind, .both)
    }

    func testMessageContainsBenefitsAndStimulus() {
        let cardio = AssistantCardioMeditationNudgeEngine.message(kind: .cardio, athleteName: "Ana")
        XCTAssertTrue(cardio.contains("Ana"))
        XCTAssertTrue(cardio.localizedCaseInsensitiveContains("cardio"))
        XCTAssertTrue(cardio.contains("Por que manter") || cardio.contains("Benefícios"))

        let meditation = AssistantCardioMeditationNudgeEngine.message(kind: .meditation, athleteName: "Ana")
        XCTAssertTrue(meditation.localizedCaseInsensitiveContains("medit"))
        XCTAssertTrue(meditation.contains("estresse") || meditation.contains("foco"))
    }
}
