import XCTest
@testable import HealthFit

final class AssistantWorkoutBuilderTests: XCTestCase {
    func testDetectsWorkoutBuildIntent() {
        XCTAssertTrue(AssistantWorkoutBuilder.detectsWorkoutBuildIntent("Quero montar treino sem personal"))
        XCTAssertTrue(AssistantWorkoutBuilder.detectsWorkoutBuildIntent("Criar ficha personalizada"))
        XCTAssertFalse(AssistantWorkoutBuilder.detectsWorkoutBuildIntent("Qual é meu IMC?"))
    }

    func testParsesGenderAndFocus() {
        XCTAssertEqual(AssistantWorkoutBuilder.parseGender(from: "Feminino"), .female)
        XCTAssertEqual(AssistantWorkoutBuilder.parseGender(from: "treino masculino"), .male)
        XCTAssertEqual(AssistantWorkoutGoalFocus.parse(from: "Ganho de massa"), .muscleGain)
        XCTAssertEqual(AssistantWorkoutGoalFocus.parse(from: "perda de gordura"), .fatLoss)
        XCTAssertEqual(AssistantWorkoutGoalFocus.parse(from: "Resistência"), .endurance)
    }

    func testRejectsDefaultBodyMetrics() {
        let unset = UserProfile(name: "Ana", email: "a@b.com", weight: 75, height: 175, age: 28)
        XCTAssertFalse(AssistantWorkoutBuilder.hasRequiredProfileData(unset))

        let ready = UserProfile(name: "Ana", email: "a@b.com", weight: 62, height: 165, age: 30)
        XCTAssertTrue(AssistantWorkoutBuilder.hasRequiredProfileData(ready))
    }

    func testBuildsAssistantSheetWithBadgeFlag() {
        let profile = UserProfile(
            name: "Ana",
            email: "a@b.com",
            biotype: .mesomorph,
            gender: .female,
            weight: 62,
            height: 165,
            age: 30
        )
        let sheet = AssistantWorkoutBuilder.buildSheet(
            gender: .female,
            focus: .muscleGain,
            profile: profile
        )

        XCTAssertTrue(sheet.createdByAssistant)
        XCTAssertTrue(sheet.isUserCreated)
        XCTAssertEqual(sheet.targetGender, .female)
        XCTAssertFalse(sheet.exercises.isEmpty)
        XCTAssertTrue(sheet.title.contains("IAssistente"))
        XCTAssertTrue(sheet.description.localizedCaseInsensitiveContains("educação física")
                      || sheet.description.localizedCaseInsensitiveContains("Educação Física")
                      || sheet.description.localizedCaseInsensitiveContains("profissional"))
    }

    func testConfirmationMentionsProfessionalDisclaimer() {
        let profile = UserProfile(name: "João", email: "j@b.com", weight: 80, height: 180, age: 32)
        let text = AssistantWorkoutBuilder.confirmationSummary(
            gender: .male,
            focus: .fatLoss,
            profile: profile
        )
        XCTAssertTrue(text.contains(AssistantWorkoutBuilder.professionalDisclaimer))
        XCTAssertTrue(text.localizedCaseInsensitiveContains("autoriza"))
    }
}
