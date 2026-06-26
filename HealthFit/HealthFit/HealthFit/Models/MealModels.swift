import Foundation

struct Meal: Identifiable, Codable {
    var id: UUID
    var name: String
    var mealType: MealType
    var calories: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var ingredients: [String]
    var instructions: String

    init(
        id: UUID = UUID(),
        name: String,
        mealType: MealType,
        calories: Int,
        protein: Int,
        carbs: Int,
        fat: Int,
        ingredients: [String],
        instructions: String = ""
    ) {
        self.id = id
        self.name = name
        self.mealType = mealType
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.ingredients = ingredients
        self.instructions = instructions
    }
}

enum MealType: String, CaseIterable, Codable, Identifiable {
    case breakfast = "Café da Manhã"
    case lunch = "Almoço"
    case snack = "Lanche"
    case dinner = "Jantar"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .snack: return "leaf.fill"
        case .dinner: return "moon.stars.fill"
        }
    }
}

struct DailyMealPlan: Identifiable, Codable {
    var id: UUID
    var dayOfWeek: String
    var meals: [Meal]
    var totalCalories: Int {
        meals.reduce(0) { $0 + $1.calories }
    }
    var totalProtein: Int {
        meals.reduce(0) { $0 + $1.protein }
    }

    init(id: UUID = UUID(), dayOfWeek: String, meals: [Meal]) {
        self.id = id
        self.dayOfWeek = dayOfWeek
        self.meals = meals
    }
}

struct ShoppingItem: Identifiable, Codable {
    var id: UUID
    var name: String
    var quantity: String
    var category: ShoppingCategory
    var isPurchased: Bool
    var weekStartDate: Date

    init(
        id: UUID = UUID(),
        name: String,
        quantity: String,
        category: ShoppingCategory,
        isPurchased: Bool = false,
        weekStartDate: Date = .now
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.category = category
        self.isPurchased = isPurchased
        self.weekStartDate = weekStartDate
    }
}

enum ShoppingCategory: String, CaseIterable, Codable, Identifiable {
    case proteins = "Proteínas"
    case vegetables = "Vegetais"
    case fruits = "Frutas"
    case grains = "Grãos"
    case dairy = "Laticínios"
    case supplements = "Suplementos"
    case other = "Outros"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .proteins: return "fish.fill"
        case .vegetables: return "carrot.fill"
        case .fruits: return "apple.logo"
        case .grains: return "leaf.fill"
        case .dairy: return "cup.and.saucer.fill"
        case .supplements: return "pills.fill"
        case .other: return "cart.fill"
        }
    }
}
