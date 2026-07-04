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
    case morningSnack = "Lanche"
    case lunch = "Almoço"
    case afternoonSnack = "Lanche da Tarde"
    case dinner = "Jantar"
    case supper = "Ceia"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .morningSnack: return "cup.and.saucer.fill"
        case .lunch: return "sun.max.fill"
        case .afternoonSnack: return "leaf.fill"
        case .dinner: return "moon.stars.fill"
        case .supper: return "moon.zzz.fill"
        }
    }

    var shortLabel: String {
        switch self {
        case .breakfast: return "Café"
        case .morningSnack: return "Lanche"
        case .lunch: return "Almoço"
        case .afternoonSnack: return "Lanche T."
        case .dinner: return "Janta"
        case .supper: return "Ceia"
        }
    }

    /// Participação aproximada nas calorias diárias.
    var calorieShare: Double {
        switch self {
        case .breakfast: return 0.20
        case .morningSnack: return 0.10
        case .lunch: return 0.30
        case .afternoonSnack: return 0.10
        case .dinner: return 0.22
        case .supper: return 0.08
        }
    }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case MealType.breakfast.rawValue: self = .breakfast
        case MealType.morningSnack.rawValue, "Lanche da Manhã": self = .morningSnack
        case MealType.lunch.rawValue: self = .lunch
        case MealType.afternoonSnack.rawValue: self = .afternoonSnack
        case MealType.dinner.rawValue: self = .dinner
        case MealType.supper.rawValue: self = .supper
        default:
            if value == "Lanche" { self = .morningSnack }
            else if value == "Jantar" { self = .dinner }
            else { self = .breakfast }
        }
    }
}

enum SweetConsumptionLevel: String, CaseIterable, Codable, Identifiable {
    case low = "Pouco"
    case moderate = "Moderado"
    case high = "Muito"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .low: return "leaf.fill"
        case .moderate: return "birthday.cake"
        case .high: return "birthday.cake.fill"
        }
    }

    var detail: String {
        switch self {
        case .low:
            return "Priorizamos opções com pouco açúcar e frutas no lugar de doces."
        case .moderate:
            return "Cardápio equilibrado com doces ocasionais."
        case .high:
            return "Incluímos sobremesas e lanches doces — acompanhe as porções."
        }
    }
}

enum LactoseTolerance: String, CaseIterable, Codable, Identifiable {
    case tolerant = "Sim, tolero"
    case intolerant = "Intolerância"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .tolerant: return "cup.and.saucer.fill"
        case .intolerant: return "drop.triangle.fill"
        }
    }

    var detail: String {
        switch self {
        case .tolerant:
            return "Incluímos iogurte, leite, queijo e whey com leite nas opções."
        case .intolerant:
            return "Removemos laticínios e priorizamos alternativas sem lactose."
        }
    }
}

struct MealTemplate: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var mealType: MealType
    var calories: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var ingredients: [String]
    var instructions: String
    var isSweet: Bool
    var containsLactose: Bool
    var isFatLossFocused: Bool

    init(
        id: UUID = UUID(),
        name: String,
        mealType: MealType,
        calories: Int,
        protein: Int,
        carbs: Int,
        fat: Int,
        ingredients: [String],
        instructions: String,
        isSweet: Bool = false,
        containsLactose: Bool = false,
        isFatLossFocused: Bool = false
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
        self.isSweet = isSweet
        self.containsLactose = containsLactose
        self.isFatLossFocused = isFatLossFocused
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        mealType = try container.decode(MealType.self, forKey: .mealType)
        calories = try container.decode(Int.self, forKey: .calories)
        protein = try container.decode(Int.self, forKey: .protein)
        carbs = try container.decode(Int.self, forKey: .carbs)
        fat = try container.decode(Int.self, forKey: .fat)
        ingredients = try container.decode([String].self, forKey: .ingredients)
        instructions = try container.decodeIfPresent(String.self, forKey: .instructions) ?? ""
        isSweet = try container.decodeIfPresent(Bool.self, forKey: .isSweet) ?? false
        containsLactose = try container.decodeIfPresent(Bool.self, forKey: .containsLactose) ?? false
        isFatLossFocused = try container.decodeIfPresent(Bool.self, forKey: .isFatLossFocused) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, mealType, calories, protein, carbs, fat, ingredients, instructions
        case isSweet, containsLactose, isFatLossFocused
    }

    func scaled(to targetCalories: Int, proteinMultiplier: Int = 1) -> Meal {
        let factor = targetCalories > 0 ? Double(targetCalories) / Double(max(calories, 1)) : 1
        return Meal(
            name: name,
            mealType: mealType,
            calories: targetCalories,
            protein: Int(Double(protein * proteinMultiplier) * factor),
            carbs: Int(Double(carbs) * factor),
            fat: Int(Double(fat) * factor),
            ingredients: ingredients,
            instructions: instructions
        )
    }
}

struct CustomMenuSelection: Codable, Equatable {
    var sweetConsumption: SweetConsumptionLevel
    var lactoseTolerance: LactoseTolerance?
    var selections: [String: UUID]
    var energyDrinksPerWeek: Int

    static let `default` = CustomMenuSelection(
        sweetConsumption: .moderate,
        lactoseTolerance: nil,
        selections: [:],
        energyDrinksPerWeek: 0
    )

    var isReadyToBuild: Bool {
        lactoseTolerance != nil
    }

    init(
        sweetConsumption: SweetConsumptionLevel,
        lactoseTolerance: LactoseTolerance? = nil,
        selections: [String: UUID] = [:],
        energyDrinksPerWeek: Int = 0
    ) {
        self.sweetConsumption = sweetConsumption
        self.lactoseTolerance = lactoseTolerance
        self.selections = selections
        self.energyDrinksPerWeek = max(0, energyDrinksPerWeek)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sweetConsumption = try container.decodeIfPresent(SweetConsumptionLevel.self, forKey: .sweetConsumption) ?? .moderate
        lactoseTolerance = try container.decodeIfPresent(LactoseTolerance.self, forKey: .lactoseTolerance)
        selections = try container.decodeIfPresent([String: UUID].self, forKey: .selections) ?? [:]
        energyDrinksPerWeek = max(0, try container.decodeIfPresent(Int.self, forKey: .energyDrinksPerWeek) ?? 0)
    }

    private enum CodingKeys: String, CodingKey {
        case sweetConsumption, lactoseTolerance, selections, energyDrinksPerWeek
    }

    func selectedTemplateID(for mealType: MealType) -> UUID? {
        selections[mealType.rawValue]
    }

    mutating func setSelection(_ templateID: UUID, for mealType: MealType) {
        selections[mealType.rawValue] = templateID
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

enum SupplementGuidance {
    static let preWorkoutCaffeineLimit = "até 400 mg de cafeína por dose"

    static let whoEnergyDrinkWarning = """
    A OMS recomenda limitar bebidas energéticas e açucaradas. Em adultos saudáveis, a cafeína total não deve ultrapassar cerca de 400 mg por dia. A ingestão de açúcares livres deve ficar abaixo de 10% das calorias diárias (idealmente 5%). Mais de 2 energéticos por semana pode elevar cafeína e açúcar acima do recomendado, com riscos para sono, pressão arterial e coração.
    """
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
