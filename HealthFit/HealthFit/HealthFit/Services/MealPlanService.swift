import Foundation
import Combine

@MainActor
final class MealPlanService: ObservableObject {
    @Published var weeklyPlan: [DailyMealPlan] = []
    @Published var shoppingList: [ShoppingItem] = []
    @Published var basalMetabolicRate: Int = 0
    @Published var dailyCalorieTarget: Int = 0

    private let planKey = "healthfit_meal_plan"
    private let shoppingKey = "healthfit_shopping_list"

    func generatePlan(for profile: UserProfile) {
        basalMetabolicRate = profile.basalMetabolicRate
        dailyCalorieTarget = profile.dailyCalorieTarget
        weeklyPlan = Self.buildWeeklyPlan(
            calorieBase: profile.dailyCalorieTarget,
            goal: profile.goal
        )
        generateShoppingList()
        saveData()
    }

    func regeneratePlanIfNeeded(for profile: UserProfile) {
        guard !weeklyPlan.isEmpty else { return }
        generatePlan(for: profile)
    }

    func generateShoppingList() {
        var ingredientCounts: [String: (quantity: String, category: ShoppingCategory)] = [:]

        for day in weeklyPlan {
            for meal in day.meals {
                for ingredient in meal.ingredients {
                    let parts = ingredient.split(separator: " ", maxSplits: 1)
                    let name = String(parts.last ?? Substring(ingredient))
                    let qty = parts.count > 1 ? String(parts[0]) : "1 un"

                    if let existing = ingredientCounts[name] {
                        ingredientCounts[name] = (existing.quantity, existing.category)
                    } else {
                        ingredientCounts[name] = (qty, categorizeIngredient(name))
                    }
                }
            }
        }

        let weekStart = Calendar.current.startOfDay(for: .now)
        shoppingList = ingredientCounts.map { name, info in
            ShoppingItem(name: name, quantity: info.quantity, category: info.category, weekStartDate: weekStart)
        }.sorted { $0.category.rawValue < $1.category.rawValue }

        saveData()
    }

    func togglePurchased(_ item: ShoppingItem) {
        if let index = shoppingList.firstIndex(where: { $0.id == item.id }) {
            shoppingList[index].isPurchased.toggle()
            saveData()
        }
    }

    func loadSavedData() {
        if let data = UserDefaults.standard.data(forKey: planKey),
           let plan = try? JSONDecoder().decode([DailyMealPlan].self, from: data) {
            weeklyPlan = plan
        }
        if let data = UserDefaults.standard.data(forKey: shoppingKey),
           let list = try? JSONDecoder().decode([ShoppingItem].self, from: data) {
            shoppingList = list
        }
    }

    private func saveData() {
        if let data = try? JSONEncoder().encode(weeklyPlan) {
            UserDefaults.standard.set(data, forKey: planKey)
        }
        if let data = try? JSONEncoder().encode(shoppingList) {
            UserDefaults.standard.set(data, forKey: shoppingKey)
        }
    }

    private func categorizeIngredient(_ name: String) -> ShoppingCategory {
        let lower = name.lowercased()
        if lower.contains("frango") || lower.contains("carne") || lower.contains("peixe") || lower.contains("ovo") || lower.contains("atum") {
            return .proteins
        }
        if lower.contains("leite") || lower.contains("iogurte") || lower.contains("queijo") || lower.contains("whey") {
            return .dairy
        }
        if lower.contains("arroz") || lower.contains("aveia") || lower.contains("pão") || lower.contains("batata") || lower.contains("macarrão") {
            return .grains
        }
        if lower.contains("banana") || lower.contains("maçã") || lower.contains("morango") {
            return .fruits
        }
        if lower.contains("whey") || lower.contains("creatina") {
            return .supplements
        }
        return .vegetables
    }

    private static func buildWeeklyPlan(calorieBase: Int, goal: FitnessGoal) -> [DailyMealPlan] {
        let days = ["Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado", "Domingo"]

        return days.enumerated().map { index, day in
            let variation = index % 3
            return DailyMealPlan(dayOfWeek: day, meals: mealsForDay(variation: variation, calorieBase: calorieBase, goal: goal))
        }
    }

    private static func mealsForDay(variation: Int, calorieBase: Int, goal: FitnessGoal) -> [Meal] {
        let breakfastCal = calorieBase / 4
        let lunchCal = calorieBase / 3
        let snackCal = calorieBase / 8
        let dinnerCal = calorieBase - breakfastCal - lunchCal - snackCal

        let proteins = goal == .muscleGain ? 2 : 1

        switch variation {
        case 0:
            return [
                Meal(name: "Omelete Proteico", mealType: .breakfast, calories: breakfastCal, protein: 30 * proteins, carbs: 25, fat: 15,
                     ingredients: ["3 un ovos", "50g queijo cottage", "1 fatia pão integral", "Tomate cereja"],
                     instructions: "Bata os ovos, adicione o queijo e cozinhe em frigideira antiaderente."),
                Meal(name: "Frango com Arroz", mealType: .lunch, calories: lunchCal, protein: 45 * proteins, carbs: 60, fat: 12,
                     ingredients: ["200g peito de frango", "150g arroz integral", "Brócolis", "Azeite"],
                     instructions: "Grelhe o frango temperado e sirva com arroz e brócolis no vapor."),
                Meal(name: "Shake de Whey", mealType: .snack, calories: snackCal, protein: 25, carbs: 15, fat: 5,
                     ingredients: ["30g whey protein", "1 banana", "200ml leite desnatado"],
                     instructions: "Bata todos os ingredientes no liquidificador."),
                Meal(name: "Salmão com Batata Doce", mealType: .dinner, calories: dinnerCal, protein: 40, carbs: 45, fat: 18,
                     ingredients: ["180g salmão", "200g batata doce", "Aspargos", "Limão"],
                     instructions: "Asse o salmão com limão e sirva com batata doce assada.")
            ]
        case 1:
            return [
                Meal(name: "Aveia com Frutas", mealType: .breakfast, calories: breakfastCal, protein: 20, carbs: 55, fat: 10,
                     ingredients: ["80g aveia", "1 banana", "Morangos", "Mel"],
                     instructions: "Cozinhe a aveia com leite e adicione as frutas por cima."),
                Meal(name: "Carne com Legumes", mealType: .lunch, calories: lunchCal, protein: 50 * proteins, carbs: 40, fat: 15,
                     ingredients: ["200g patinho moído", "Abobrinha", "Cenoura", "Arroz"],
                     instructions: "Refogue a carne com os legumes e acompanhe com arroz."),
                Meal(name: "Iogurte com Granola", mealType: .snack, calories: snackCal, protein: 15, carbs: 25, fat: 8,
                     ingredients: ["200g iogurte grego", "30g granola", "Mel"],
                     instructions: "Misture o iogurte com granola e mel."),
                Meal(name: "Atum com Salada", mealType: .dinner, calories: dinnerCal, protein: 35, carbs: 30, fat: 12,
                     ingredients: ["2 latas atum", "Mix de folhas", "Tomate", "Azeite"],
                     instructions: "Monte a salada e adicione o atum por cima.")
            ]
        default:
            return [
                Meal(name: "Panqueca de Banana", mealType: .breakfast, calories: breakfastCal, protein: 25, carbs: 45, fat: 12,
                     ingredients: ["2 ovos", "1 banana", "Aveia", "Canela"],
                     instructions: "Misture e faça panquecas em frigideira."),
                Meal(name: "Peixe Grelhado", mealType: .lunch, calories: lunchCal, protein: 42, carbs: 50, fat: 10,
                     ingredients: ["200g tilápia", "Quinoa", "Espinafre", "Alho"],
                     instructions: "Grelhe o peixe e sirva com quinoa e espinafre."),
                Meal(name: "Barra Proteica", mealType: .snack, calories: snackCal, protein: 20, carbs: 20, fat: 6,
                     ingredients: ["1 barra proteica", "Castanhas"],
                     instructions: "Consuma como lanche prático."),
                Meal(name: "Frango Desfiado", mealType: .dinner, calories: dinnerCal, protein: 38, carbs: 35, fat: 10,
                     ingredients: ["180g frango desfiado", "Batata inglesa", "Salada verde"],
                     instructions: "Cozinhe o frango e sirva com batata cozida e salada.")
            ]
        }
    }
}
