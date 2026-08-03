import XCTest
@testable import HealthFit

final class AssistantImprovementAnalysisEngineTests: XCTestCase {
    func testMatchesPortugueseImprovementPhrases() {
        let phrases = [
            "o que preciso melhorar",
            "Como evoluir?",
            "Análise do meu progresso",
            "O que está fraco?",
            "Me dá um feedback do progresso",
            "No que devo melhorar?",
        ]
        for phrase in phrases {
            XCTAssertTrue(
                AssistantImprovementAnalysisEngine.matches(phrase),
                "Deveria reconhecer: \(phrase)"
            )
        }
    }

    func testDoesNotMatchLoadProgressionOrBodyEvolution() {
        XCTAssertFalse(AssistantImprovementAnalysisEngine.matches("como evoluir a carga"))
        XCTAssertFalse(AssistantImprovementAnalysisEngine.matches("progressão de carga e plateau"))
        XCTAssertFalse(AssistantImprovementAnalysisEngine.matches("Como está minha evolução corporal?"))
    }

    func testDoesNotMatchUnrelatedQuestions() {
        XCTAssertFalse(AssistantImprovementAnalysisEngine.matches("Qual é meu IMC?"))
        XCTAssertFalse(AssistantImprovementAnalysisEngine.matches("Quanto de proteína comer?"))
    }

    func testSparseAnswerMentionsMissingDataAndMotivation() {
        let context = TestFixtures.assistantContext(
            sleepHours: nil,
            weeklyWorkoutCount: 0,
            hoursSinceLastWorkout: nil,
            recentWorkoutSessions: [],
            hasMealPlan: false
        )
        let answer = AssistantImprovementAnalysisEngine.answer(context: context)

        XCTAssertTrue(answer.localizedCaseInsensitiveContains("melhorar") || answer.contains("Prioridades"))
        XCTAssertTrue(answer.localizedCaseInsensitiveContains("son"))
        XCTAssertTrue(answer.localizedCaseInsensitiveContains("treino") || answer.localizedCaseInsensitiveContains("cardápio"))
        XCTAssertTrue(answer.contains("Você consegue") || answer.localizedCaseInsensitiveContains("consegue"))
    }

    func testAnswerIncludesWorkoutNumbersWhenSessionsExist() {
        let session = TestFixtures.completedWorkoutSession(
            workoutTitle: "Treino A",
            endedAt: .now,
            completedExercises: 4,
            totalExercises: 6
        )
        let early = WorkoutSession(
            workoutSheetId: TestFixtures.sheetId,
            workoutTitle: "Treino B",
            startedAt: .now.addingTimeInterval(-7200),
            endedAt: .now.addingTimeInterval(-3600),
            completedExercises: 2,
            totalExercises: 6,
            endedEarly: true
        )
        let context = TestFixtures.assistantContext(
            sleepHours: 6.0,
            weeklyWorkoutCount: 2,
            recentWorkoutSessions: [session, early],
            hasMealPlan: true,
            todayMealsCompleted: 1,
            todayMealsTotal: 4,
            weekMealsCompleted: 3,
            weekMealsTotal: 28
        )

        let answer = AssistantImprovementAnalysisEngine.answer(context: context)

        XCTAssertTrue(answer.contains("7 dias") || answer.contains("sessão"))
        XCTAssertTrue(answer.contains("6.0") || answer.contains("6,0") || answer.contains("sono") || answer.localizedCaseInsensitiveContains("sono"))
        XCTAssertTrue(answer.contains("1/4") || answer.contains("refeições"))
        XCTAssertTrue(answer.contains("Prioridades") || answer.contains("🎯"))
        XCTAssertTrue(answer.localizedCaseInsensitiveContains("consegue") || answer.contains("💪"))
    }

    func testEngineAnswerIsRoutedFromHealthAssistantEngine() {
        let context = TestFixtures.assistantContext(
            recentWorkoutSessions: [TestFixtures.completedWorkoutSession()]
        )
        let answer = HealthAssistantEngine.answer(for: "O que preciso melhorar?", context: context)
        XCTAssertTrue(answer.contains("Prioridades") || answer.contains("🎯"))
        XCTAssertFalse(answer.contains("Não encontrei uma resposta exata"))
    }

    func testIMCIntentStillWorks() {
        let answer = HealthAssistantEngine.answer(
            for: "Qual é meu IMC?",
            context: TestFixtures.assistantContext(user: TestFixtures.userProfile(weight: 80, height: 180))
        )
        XCTAssertTrue(answer.contains("IMC"))
        XCTAssertFalse(answer.contains("Prioridades para evoluir"))
    }

    func testMealAdherenceAggregatesCompletions() {
        let meals = [
            Meal(
                name: "Café",
                mealType: .breakfast,
                calories: 300,
                protein: 20,
                carbs: 30,
                fat: 10,
                ingredients: [],
                instructions: "",
                isCompleted: true
            ),
            Meal(
                name: "Almoço",
                mealType: .lunch,
                calories: 500,
                protein: 40,
                carbs: 50,
                fat: 15,
                ingredients: [],
                instructions: "",
                isCompleted: false
            ),
        ]
        let plan = (0..<7).map { index in
            DailyMealPlan(
                dayOfWeek: ["Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado", "Domingo"][index],
                options: [MealPlanOption(name: "Opção 1", subtitle: "", meals: meals)]
            )
        }
        let result = AssistantImprovementAnalysisEngine.mealAdherence(from: plan)
        XCTAssertTrue(result.hasPlan)
        XCTAssertEqual(result.todayTotal, 2)
        XCTAssertEqual(result.todayCompleted, 1)
        XCTAssertEqual(result.weekTotal, 14)
        XCTAssertEqual(result.weekCompleted, 7)
    }
}
