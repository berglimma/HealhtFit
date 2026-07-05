import XCTest
@testable import HealthFit

final class SupplementationGuideEngineTests: XCTestCase {
    func testOverviewMentionsBenefitsAndExcess() {
        let answer = HealthAssistantEngine.answer(
            for: "Quais suplementos devo tomar?",
            context: TestFixtures.assistantContext()
        )
        XCTAssertTrue(answer.localizedCaseInsensitiveContains("benefício") || answer.contains("✅"))
        XCTAssertTrue(answer.localizedCaseInsensitiveContains("excesso") || answer.contains("⚠️"))
    }

    func testCreatineAnswerIncludesDoseAndRisks() {
        let answer = HealthAssistantEngine.answer(
            for: "Para que serve a creatina?",
            context: TestFixtures.assistantContext()
        )
        XCTAssertTrue(answer.localizedCaseInsensitiveContains("creatina"))
        XCTAssertTrue(answer.contains("3–5 g") || answer.contains("3-5 g"))
        XCTAssertTrue(answer.localizedCaseInsensitiveContains("excesso") || answer.contains("⚠️"))
        XCTAssertTrue(answer.localizedCaseInsensitiveContains("benefício") || answer.contains("✅"))
    }

    func testWheyAnswerIncludesBenefitsAndExcess() {
        let answer = HealthAssistantEngine.answer(
            for: "Whey protein faz mal?",
            context: TestFixtures.assistantContext()
        )
        XCTAssertTrue(answer.localizedCaseInsensitiveContains("whey"))
        XCTAssertTrue(answer.localizedCaseInsensitiveContains("benefício") || answer.contains("✅"))
        XCTAssertTrue(answer.localizedCaseInsensitiveContains("excesso") || answer.contains("⚠️"))
    }

    func testPreWorkoutAnswerIncludesCaffeineRisks() {
        let answer = HealthAssistantEngine.answer(
            for: "Posso tomar pré-treino todo dia?",
            context: TestFixtures.assistantContext()
        )
        XCTAssertTrue(answer.localizedCaseInsensitiveContains("pré-treino") || answer.localizedCaseInsensitiveContains("pre-treino"))
        XCTAssertTrue(answer.localizedCaseInsensitiveContains("cafeína") || answer.localizedCaseInsensitiveContains("cafeina"))
        XCTAssertTrue(answer.contains("⚠️"))
    }

    func testOmega3AnswerIncludesBloodThinningRisk() {
        let answer = HealthAssistantEngine.answer(
            for: "Para que serve ômega 3?",
            context: TestFixtures.assistantContext()
        )
        XCTAssertTrue(answer.localizedCaseInsensitiveContains("ômega") || answer.localizedCaseInsensitiveContains("omega"))
        XCTAssertTrue(answer.localizedCaseInsensitiveContains("sangramento") || answer.localizedCaseInsensitiveContains("excesso"))
    }

    func testSuggestedQuestionsIncludeSupplementation() {
        XCTAssertTrue(HealthAssistantEngine.suggestedQuestions.contains("Quais suplementos devo tomar?"))
        XCTAssertTrue(HealthAssistantEngine.suggestedQuestions.contains("Para que serve a creatina?"))
    }
}
