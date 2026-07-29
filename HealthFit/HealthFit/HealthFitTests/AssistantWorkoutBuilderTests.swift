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
            profile: profile,
            experience: .firstTime,
            location: .gym
        )
        XCTAssertTrue(text.contains(AssistantWorkoutBuilder.professionalDisclaimer))
        XCTAssertTrue(text.localizedCaseInsensitiveContains("autoriza"))
        XCTAssertTrue(text.localizedCaseInsensitiveContains("primeira vez"))
    }

    func testParsesTrainingExperienceAnswers() {
        XCTAssertEqual(AssistantWorkoutBuilder.parseAlreadyTrains(from: "Sim, já treino"), true)
        XCTAssertEqual(AssistantWorkoutBuilder.parseAlreadyTrains(from: "Não, ainda não"), false)
        XCTAssertEqual(AssistantWorkoutBuilder.parseFirstTimeAtGym(from: "Sim, primeira vez"), true)
        XCTAssertEqual(AssistantWorkoutBuilder.parseFirstTimeAtGym(from: "Não, já treinei antes"), false)
        XCTAssertEqual(AssistantTrainingExperience.parseLevel(from: "Intermediário"), .intermediate)
        XCTAssertEqual(AssistantTrainingExperience.fromFirstTimeAnswer(true), .firstTime)
        XCTAssertEqual(AssistantTrainingExperience.fromFirstTimeAnswer(false), .returning)
    }

    func testParsesHomeOnlyPreference() {
        XCTAssertEqual(AssistantWorkoutBuilder.parseHomeOnly(from: "Sim, só em casa"), true)
        XCTAssertEqual(AssistantWorkoutBuilder.parseHomeOnly(from: "Não, na academia"), false)
        XCTAssertEqual(AssistantWorkoutBuilder.parseHomeOnly(from: "quero treinar em casa"), true)
        XCTAssertTrue(AssistantWorkoutBuilder.detectsWorkoutBuildIntent("Montar treino em casa"))
    }

    func testBuildsHomeSheetWithoutWeights() {
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
            profile: profile,
            experience: .beginner,
            location: .homeOnly
        )
        XCTAssertTrue(sheet.title.localizedCaseInsensitiveContains("Casa"))
        XCTAssertTrue(sheet.description.localizedCaseInsensitiveContains("casa"))
        XCTAssertTrue(sheet.exercises.allSatisfy { $0.weight == nil })
        XCTAssertFalse(sheet.exercises.isEmpty)
    }

    func testFirstTimeSheetUsesLighterLoadsThanAdvanced() {
        let profile = UserProfile(
            name: "João",
            email: "j@b.com",
            biotype: .mesomorph,
            gender: .male,
            weight: 80,
            height: 180,
            age: 32
        )
        let beginner = AssistantWorkoutBuilder.buildSheet(
            gender: .male,
            focus: .muscleGain,
            profile: profile,
            experience: .firstTime,
            location: .gym
        )
        let advanced = AssistantWorkoutBuilder.buildSheet(
            gender: .male,
            focus: .muscleGain,
            profile: profile,
            experience: .advanced,
            location: .gym
        )
        let beginnerLoad = beginner.exercises.compactMap(\.weight).reduce(0, +)
        let advancedLoad = advanced.exercises.compactMap(\.weight).reduce(0, +)
        XCTAssertLessThan(beginnerLoad, advancedLoad)
        XCTAssertTrue(beginner.description.localizedCaseInsensitiveContains("primeira vez"))
    }
}
