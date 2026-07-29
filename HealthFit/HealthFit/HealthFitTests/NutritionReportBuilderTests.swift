import XCTest
@testable import HealthFit

final class NutritionReportBuilderTests: XCTestCase {
    func testHasNutritionistRequiresEmail() {
        var profile = TestFixtures.userProfile()
        XCTAssertFalse(profile.hasNutritionist)

        profile.nutritionistName = "Dra. Ana"
        XCTAssertFalse(profile.hasNutritionist)

        profile.nutritionistEmail = "ana@nutri.com"
        XCTAssertTrue(profile.hasNutritionist)
    }

    func testEmailBodyIsAddressedToNutritionistOnly() {
        var athlete = TestFixtures.userProfile(name: "João Silva")
        athlete.nutritionistName = "Dra. Ana"
        athlete.nutritionistEmail = "ana@nutri.com"
        athlete.personalTrainerName = "Coach Berg"
        athlete.personalTrainerEmail = "berg@pt.com"

        let day = DailyMealPlan(
            dayOfWeek: "Segunda",
            options: [
                MealPlanOption(
                    name: "Montado",
                    subtitle: "Personalizado",
                    meals: [
                        Meal(
                            name: "Ovos mexidos",
                            mealType: .breakfast,
                            calories: 350,
                            protein: 28,
                            carbs: 10,
                            fat: 20,
                            ingredients: ["Ovos", "Espinafre"]
                        )
                    ]
                )
            ]
        )

        let body = NutritionReportBuilder.emailBody(
            athlete: athlete,
            weeklyPlan: [day],
            customMenu: .default,
            shoppingList: []
        )

        XCTAssertTrue(body.contains("Dra. Ana"))
        XCTAssertTrue(body.contains("João Silva"))
        XCTAssertTrue(body.contains("Ovos mexidos"))
        XCTAssertTrue(body.localizedCaseInsensitiveContains("nutricionista"))
        XCTAssertFalse(body.contains("Coach Berg"))
        XCTAssertFalse(body.contains("berg@pt.com"))
    }

    func testPreferredOptionPrefersMontado() {
        let day = DailyMealPlan(
            dayOfWeek: "Terça",
            options: [
                MealPlanOption(name: "Opção 1", meals: []),
                MealPlanOption(name: "Montado", meals: [])
            ]
        )
        XCTAssertEqual(NutritionReportBuilder.preferredOption(from: day, selectedIndex: 0)?.name, "Montado")
    }

    func testNutritionistFieldsSurviveCodableRoundTrip() throws {
        var profile = TestFixtures.userProfile()
        profile.nutritionistName = "Nutri Luan"
        profile.nutritionistEmail = "luan@nutri.com"

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: data)

        XCTAssertEqual(decoded.nutritionistName, "Nutri Luan")
        XCTAssertEqual(decoded.nutritionistEmail, "luan@nutri.com")
        XCTAssertTrue(decoded.hasNutritionist)
    }

    func testMealCompletionSurvivesCodableRoundTrip() throws {
        let meal = Meal(
            name: "Frango grelhado",
            mealType: .lunch,
            calories: 420,
            protein: 40,
            carbs: 20,
            fat: 12,
            ingredients: ["Frango"],
            isCompleted: true
        )
        let data = try JSONEncoder().encode(meal)
        let decoded = try JSONDecoder().decode(Meal.self, from: data)
        XCTAssertTrue(decoded.isCompleted)
    }

    func testReportShowsMealCompletionStatus() {
        var athlete = TestFixtures.userProfile(name: "Maria")
        athlete.nutritionistEmail = "nutri@test.com"

        let day = DailyMealPlan(
            dayOfWeek: "Quarta",
            options: [
                MealPlanOption(
                    name: "Opção 1",
                    meals: [
                        Meal(
                            name: "Salada",
                            mealType: .lunch,
                            calories: 300,
                            protein: 20,
                            carbs: 15,
                            fat: 10,
                            ingredients: ["Alface"],
                            isCompleted: true
                        ),
                        Meal(
                            name: "Iogurte",
                            mealType: .afternoonSnack,
                            calories: 150,
                            protein: 12,
                            carbs: 10,
                            fat: 4,
                            ingredients: ["Iogurte"],
                            isCompleted: false
                        )
                    ]
                )
            ]
        )

        let body = NutritionReportBuilder.emailBody(
            athlete: athlete,
            weeklyPlan: [day],
            customMenu: .default,
            shoppingList: []
        )

        XCTAssertTrue(body.contains("[Concluída]"))
        XCTAssertTrue(body.contains("[Pendente]"))
        XCTAssertTrue(body.contains("1/2 refeições concluídas"))
    }
}
