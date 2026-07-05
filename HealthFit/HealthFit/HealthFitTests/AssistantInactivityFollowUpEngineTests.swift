import XCTest
@testable import HealthFit

final class AssistantInactivityFollowUpEngineTests: XCTestCase {
    func testShouldDeliverAfterOneHourWithoutUserReply() {
        let prompt = Date().addingTimeInterval(-(61 * 60))
        XCTAssertTrue(
            AssistantInactivityFollowUpEngine.shouldDeliverFollowUp(
                lastUserMessageAt: nil,
                lastAssistantPromptAt: prompt
            )
        )
    }

    func testShouldNotDeliverBeforeOneHour() {
        let prompt = Date().addingTimeInterval(-(30 * 60))
        XCTAssertFalse(
            AssistantInactivityFollowUpEngine.shouldDeliverFollowUp(
                lastUserMessageAt: nil,
                lastAssistantPromptAt: prompt
            )
        )
    }

    func testUsesLastUserMessageAsReference() {
        let userReply = Date().addingTimeInterval(-(30 * 60))
        let oldPrompt = Date().addingTimeInterval(-(2 * 60 * 60))
        XCTAssertFalse(
            AssistantInactivityFollowUpEngine.shouldDeliverFollowUp(
                lastUserMessageAt: userReply,
                lastAssistantPromptAt: oldPrompt
            )
        )
    }

    func testMessageIncludesProgressSummary() {
        let session = TestFixtures.completedWorkoutSession()
        let context = TestFixtures.assistantContext()
        let message = AssistantInactivityFollowUpEngine.message(
            context: context,
            sessions: [session]
        )

        XCTAssertTrue(message.localizedCaseInsensitiveContains("sentindo sua falta"))
        XCTAssertTrue(message.contains("resultados"))
        XCTAssertTrue(message.contains("Score semanal"))
        XCTAssertTrue(message.contains("treino"))
    }

    @MainActor
    func testUserReplyAllowsNewFollowUpCycle() {
        let service = HealthAssistantService()
        let context = TestFixtures.assistantContext()
        service.bootstrap(context: context)
        service.setInactivityFollowUpDeliveredForTests(true)
        service.send("Olá assistente", context: context)

        XCTAssertEqual(service.messages.filter(\.isUser).count, 1)
    }
}
