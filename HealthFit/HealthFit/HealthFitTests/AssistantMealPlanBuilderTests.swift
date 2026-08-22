import XCTest
@testable import HealthFit

final class AssistantMealPlanBuilderTests: XCTestCase {
    func testDetectsMealPlanBuildIntent() {
        XCTAssertTrue(AssistantMealPlanBuilder.detectsMealPlanBuildIntent("Quero montar cardápio"))
        XCTAssertTrue(AssistantMealPlanBuilder.detectsMealPlanBuildIntent("Gerar plano alimentar"))
        XCTAssertFalse(AssistantMealPlanBuilder.detectsMealPlanBuildIntent("Qual é meu IMC?"))
    }

    func testParsesLactoseSweetAndGoal() {
        XCTAssertEqual(AssistantMealPlanBuilder.parseLactoseTolerance(from: "Sim, tolero"), .tolerant)
        XCTAssertEqual(AssistantMealPlanBuilder.parseLactoseTolerance(from: "intolerância"), .intolerant)
        XCTAssertEqual(AssistantMealPlanBuilder.parseSweetLevel(from: "Pouco"), .low)
        XCTAssertEqual(AssistantMealPlanBuilder.parseSweetLevel(from: "moderado"), .moderate)
        XCTAssertEqual(AssistantMealPlanBuilder.parseGoal(from: "perda de gordura"), .fatLoss)
        XCTAssertEqual(AssistantMealPlanBuilder.parseGoal(from: "Ganho de Massa"), .muscleGain)
    }

    func testRejectsDefaultBodyMetrics() {
        let unset = UserProfile(name: "Ana", email: "a@b.com", weight: 75, height: 175, age: 28)
        XCTAssertFalse(AssistantMealPlanBuilder.hasRequiredProfileData(unset))

        let ready = UserProfile(name: "Ana", email: "a@b.com", weight: 62, height: 165, age: 30)
        XCTAssertTrue(AssistantMealPlanBuilder.hasRequiredProfileData(ready))
    }

    func testConfirmationMentionsProfessionalDisclaimer() {
        let profile = UserProfile(name: "João", email: "j@b.com", weight: 80, height: 180, age: 32)
        let text = AssistantMealPlanBuilder.confirmationSummary(
            profile: profile,
            lactose: .tolerant,
            sweet: .moderate,
            goal: .fatLoss
        )
        XCTAssertTrue(text.contains(AssistantMealPlanBuilder.professionalDisclaimer))
        XCTAssertTrue(text.localizedCaseInsensitiveContains("autoriza"))
        XCTAssertTrue(text.contains("Perda de Gordura"))
    }

    func testAffirmativeAndNegative() {
        XCTAssertTrue(AssistantMealPlanBuilder.isAffirmative("Sim, autorizo"))
        XCTAssertTrue(AssistantMealPlanBuilder.isNegative("Não, cancelar"))
        XCTAssertFalse(AssistantMealPlanBuilder.isAffirmative("Não, cancelar"))
    }
}
