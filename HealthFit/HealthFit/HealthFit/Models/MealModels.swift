import Foundation

struct Meal: Identifiable, Codable, Hashable {
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

enum MealType: String, CaseIterable, Codable, Identifiable, Hashable {
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

struct MealPlanOption: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var subtitle: String
    var meals: [Meal]

    init(id: UUID = UUID(), name: String, subtitle: String = "", meals: [Meal]) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.meals = meals
    }

    var totalCalories: Int { meals.reduce(0) { $0 + $1.calories } }
    var totalProtein: Int { meals.reduce(0) { $0 + $1.protein } }
}

struct DailyMealPlan: Identifiable, Codable {
    var id: UUID
    var dayOfWeek: String
    var options: [MealPlanOption]

    init(id: UUID = UUID(), dayOfWeek: String, options: [MealPlanOption]) {
        self.id = id
        self.dayOfWeek = dayOfWeek
        self.options = options
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        dayOfWeek = try container.decode(String.self, forKey: .dayOfWeek)
        if let options = try container.decodeIfPresent([MealPlanOption].self, forKey: .options), !options.isEmpty {
            self.options = options
        } else if let meals = try container.decodeIfPresent([Meal].self, forKey: .meals) {
            self.options = [MealPlanOption(name: "Opção 1", subtitle: "Cardápio padrão", meals: meals)]
        } else {
            self.options = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(dayOfWeek, forKey: .dayOfWeek)
        try container.encode(options, forKey: .options)
    }

    private enum CodingKeys: String, CodingKey {
        case id, dayOfWeek, options, meals
    }

    var meals: [Meal] { options.first?.meals ?? [] }
    var totalCalories: Int { options.first?.totalCalories ?? 0 }
    var totalProtein: Int { options.first?.totalProtein ?? 0 }
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
