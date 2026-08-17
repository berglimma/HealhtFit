import XCTest
@testable import HealthFit

final class HealthAssistantEngineTests: XCTestCase {
    func testWelcomeMessageIncludesFirstName() {
        let message = HealthAssistantEngine.welcomeMessage(context: TestFixtures.assistantContext())
        XCTAssertTrue(message.contains("João"))
        XCTAssertTrue(message.contains("assistente HealthFit"))
        XCTAssertTrue(message.contains(HealthAssistantEngine.healthSafetyDisclaimer))
    }

    func testPainAnswerDirectsToHealthcareProfessionalNotAI() {
        let answer = HealthAssistantEngine.answer(for: "Estou com dor no ombro", context: TestFixtures.assistantContext())
        XCTAssertTrue(answer.contains(HealthAssistantEngine.healthSafetyDisclaimer))
        XCTAssertTrue(answer.localizedCaseInsensitiveContains("qualificado e habilitado"))
    }

    func testWelcomeMessageUsesDisplayName() {
        var user = TestFixtures.userProfile(name: "João Silva")
        user.displayName = "Jota"
        let message = HealthAssistantEngine.welcomeMessage(context: TestFixtures.assistantContext(user: user))
        XCTAssertTrue(message.contains("Jota"))
        XCTAssertFalse(message.contains("João"))
    }

    func testAnswersIMCQuestionWithUserData() {
        let context = TestFixtures.assistantContext(user: TestFixtures.userProfile(weight: 80, height: 180))
        let answer = HealthAssistantEngine.answer(for: "Qual é meu IMC?", context: context)
        XCTAssertTrue(answer.contains("IMC"))
        XCTAssertTrue(answer.contains("80"))
    }

    func testAnswersEctomorphDefinition() {
        let answer = HealthAssistantEngine.answer(for: "O que é ectomorfo?", context: TestFixtures.assistantContext())
        XCTAssertTrue(answer.localizedCaseInsensitiveContains("ectomorfo"))
        XCTAssertTrue(answer.localizedCaseInsensitiveContains("metabolismo"))
    }

    func testFallbackForUnknownQuestionListsTopics() {
        let answer = HealthAssistantEngine.answer(for: "xyzabc pergunta desconhecida", context: TestFixtures.assistantContext())
        XCTAssertTrue(answer.contains("Não encontrei uma resposta exata"))
        XCTAssertTrue(answer.contains("Reformule a pergunta"))
    }

    func testAnswersAlcoholQuestionWithNegativeEffects() {
        let answer = HealthAssistantEngine.answer(for: "Posso beber álcool ou cerveja?", context: TestFixtures.assistantContext())
        XCTAssertTrue(answer.localizedCaseInsensitiveContains("álcool"))
        XCTAssertTrue(answer.localizedCaseInsensitiveContains("recuperação"))
        XCTAssertTrue(answer.localizedCaseInsensitiveContains("calorias"))
    }

    func testAnswersZeroAlcoholBeerGuidance() {
        let answer = HealthAssistantEngine.answer(for: "Cerveja zero álcool é liberada?", context: TestFixtures.assistantContext())
        XCTAssertTrue(answer.contains("Pode"))
        XCTAssertTrue(answer.contains("Não pode"))
        XCTAssertTrue(answer.localizedCaseInsensitiveContains("zero álcool"))
    }

    func testAnswersLightBeerProsAndCons() {
        let answer = HealthAssistantEngine.answer(for: "Cerveja light faz mal?", context: TestFixtures.assistantContext())
        XCTAssertTrue(answer.localizedCaseInsensitiveContains("positiv"))
        XCTAssertTrue(answer.localizedCaseInsensitiveContains("negativ"))
        XCTAssertTrue(answer.localizedCaseInsensitiveContains("light"))
    }

    func testAnswersAnabolicSteroidsWarning() {
        let questions = [
            "Posso usar esteróides anabolizantes?",
            "Quero fazer um ciclo de testosterona",
            "Deca e winstrol fazem bem?",
            "Anavar é seguro para ganhar massa?",
            "Quero ciclar",
            "Quero efetuar um ciclo",
            "Quero tomar suco"
        ]

        for question in questions {
            let answer = HealthAssistantEngine.answer(for: question, context: TestFixtures.assistantContext())
            XCTAssertTrue(answer.contains("ALERTA"), "Falhou para: \(question)")
            XCTAssertTrue(answer.localizedCaseInsensitiveContains("jamais"), "Falhou para: \(question)")
            XCTAssertTrue(answer.localizedCaseInsensitiveContains("médico"), "Falhou para: \(question)")
            XCTAssertTrue(answer.localizedCaseInsensitiveContains("testosterona"), "Falhou para: \(question)")
            XCTAssertTrue(answer.localizedCaseInsensitiveContains("nandrolona"), "Falhou para: \(question)")
            XCTAssertTrue(answer.localizedCaseInsensitiveContains("prejudica"), "Falhou para: \(question)")
        }
    }

    @MainActor
    func testIdleReturnMessageAfterThreeMinutesWithoutTyping() {
        let service = HealthAssistantService()
        let context = TestFixtures.assistantContext()
        service.bootstrap(context: context)
        service.handleTabReturn()

        service.setLastUserInteractionForTests(Date().addingTimeInterval(-181))
        service.handleTabReturn()

        XCTAssertTrue(
            service.messages.contains { $0.text == HealthAssistantEngine.idleReturnMessage && !$0.isUser }
        )
    }

    @MainActor
    func testTypingResetsIdleReturnTimer() {
        let service = HealthAssistantService()
        service.bootstrap(context: TestFixtures.assistantContext())
        service.handleTabReturn()
        service.setLastUserInteractionForTests(Date().addingTimeInterval(-181))

        service.recordUserInteraction()
        service.handleTabReturn()

        let idleMessages = service.messages.filter { $0.text == HealthAssistantEngine.idleReturnMessage }
        XCTAssertEqual(idleMessages.count, 0)
    }

    func testAnswersGratitudePhrases() {
        for phrase in ["obrigado", "Obrigada!", "muito grato", "valeu", "agradecida"] {
            let answer = HealthAssistantEngine.answer(for: phrase, context: TestFixtures.assistantContext())
            XCTAssertTrue(answer.localizedCaseInsensitiveContains("de nada"), "Falhou para: \(phrase)")
            XCTAssertTrue(answer.localizedCaseInsensitiveContains("IAssistente"), "Falhou para: \(phrase)")
        }
    }

    func testGratitudeDoesNotOverrideHealthQuestion() {
        let answer = HealthAssistantEngine.answer(
            for: "Obrigado, qual é meu IMC?",
            context: TestFixtures.assistantContext(user: TestFixtures.userProfile(weight: 80, height: 180))
        )
        XCTAssertTrue(answer.contains("IMC"))
        XCTAssertFalse(answer.localizedCaseInsensitiveContains("de nada"))
    }

    func testFemaleCycleChangeAdvisesGynecologist() {
        let user = TestFixtures.userProfile(name: "Ana Costa", gender: .female)
        let answer = HealthAssistantEngine.answer(
            for: "Meu ciclo menstrual atrasou",
            context: TestFixtures.assistantContext(user: user)
        )
        XCTAssertTrue(answer.localizedCaseInsensitiveContains("ginecologista"))
        XCTAssertTrue(answer.localizedCaseInsensitiveContains("alter"))
    }

    func testMaleDoesNotReceiveMenstrualCycleAdvice() {
        let answer = HealthAssistantEngine.answer(
            for: "Meu ciclo menstrual atrasou",
            context: TestFixtures.assistantContext()
        )
        XCTAssertFalse(answer.localizedCaseInsensitiveContains("ginecologista"))
        XCTAssertFalse(answer.localizedCaseInsensitiveContains("menstru"))
    }

    func testWelcomeIncludesGynecologistAdviceOnlyForFemale() {
        let female = HealthAssistantEngine.welcomeMessage(
            context: TestFixtures.assistantContext(user: TestFixtures.userProfile(gender: .female))
        )
        XCTAssertTrue(female.localizedCaseInsensitiveContains("ginecologista"))

        let male = HealthAssistantEngine.welcomeMessage(context: TestFixtures.assistantContext())
        XCTAssertFalse(male.localizedCaseInsensitiveContains("ginecologista"))
        XCTAssertFalse(male.localizedCaseInsensitiveContains("ciclo menstrual"))
    }
}
