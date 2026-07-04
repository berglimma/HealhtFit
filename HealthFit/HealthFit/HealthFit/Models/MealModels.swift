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

struct ShoppingCatalogItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    let defaultQuantity: String
    let category: ShoppingCategory
    let keywords: [String]

    init(
        id: UUID = UUID(),
        name: String,
        defaultQuantity: String,
        category: ShoppingCategory,
        keywords: [String] = []
    ) {
        self.id = id
        self.name = name
        self.defaultQuantity = defaultQuantity
        self.category = category
        self.keywords = keywords
    }
}

enum ShoppingCatalog {
    static let searchableCategories: [ShoppingCategory] = [
        .proteins, .vegetables, .fruits, .grains, .dairy, .supplements
    ]

    static let items: [ShoppingCatalogItem] = proteins + vegetables + fruits + grains + dairy + supplements

    static func search(query: String, category: ShoppingCategory?) -> [ShoppingCatalogItem] {
        let normalizedQuery = normalize(query)
        let scoped = category.map { cat in items.filter { $0.category == cat } } ?? items

        guard !normalizedQuery.isEmpty else {
            return scoped.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        return scoped.filter { item in
            matches(item: item, normalizedQuery: normalizedQuery)
        }
        .sorted { lhs, rhs in
            score(item: lhs, normalizedQuery: normalizedQuery) > score(item: rhs, normalizedQuery: normalizedQuery)
        }
    }

    static func item(named name: String) -> ShoppingCatalogItem? {
        let normalized = normalize(name)
        return items.first { normalize($0.name) == normalized }
    }

    private static func matches(item: ShoppingCatalogItem, normalizedQuery: String) -> Bool {
        if normalize(item.name).contains(normalizedQuery) { return true }
        return item.keywords.contains { normalize($0).contains(normalizedQuery) }
    }

    private static func score(item: ShoppingCatalogItem, normalizedQuery: String) -> Int {
        let name = normalize(item.name)
        if name == normalizedQuery { return 100 }
        if name.hasPrefix(normalizedQuery) { return 80 }
        if name.contains(normalizedQuery) { return 60 }
        if item.keywords.contains(where: { normalize($0).contains(normalizedQuery) }) { return 40 }
        return 0
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Proteínas

    private static let proteins: [ShoppingCatalogItem] = [
        ShoppingCatalogItem(name: "Peito de frango", defaultQuantity: "1 kg", category: .proteins, keywords: ["frango", "ave"]),
        ShoppingCatalogItem(name: "Coxa de frango", defaultQuantity: "800 g", category: .proteins),
        ShoppingCatalogItem(name: "Carne patinho", defaultQuantity: "500 g", category: .proteins, keywords: ["boi", "bovina"]),
        ShoppingCatalogItem(name: "Carne moída magra", defaultQuantity: "500 g", category: .proteins),
        ShoppingCatalogItem(name: "Alcatra", defaultQuantity: "500 g", category: .proteins),
        ShoppingCatalogItem(name: "Filé mignon", defaultQuantity: "400 g", category: .proteins),
        ShoppingCatalogItem(name: "Ovos", defaultQuantity: "1 dúzia", category: .proteins, keywords: ["ovo"]),
        ShoppingCatalogItem(name: "Claras de ovo", defaultQuantity: "500 ml", category: .proteins),
        ShoppingCatalogItem(name: "Salmão", defaultQuantity: "400 g", category: .proteins, keywords: ["peixe"]),
        ShoppingCatalogItem(name: "Tilápia", defaultQuantity: "600 g", category: .proteins, keywords: ["peixe"]),
        ShoppingCatalogItem(name: "Atum em lata", defaultQuantity: "2 un", category: .proteins, keywords: ["peixe", "conserva"]),
        ShoppingCatalogItem(name: "Sardinha em lata", defaultQuantity: "2 un", category: .proteins),
        ShoppingCatalogItem(name: "Camarão", defaultQuantity: "300 g", category: .proteins, keywords: ["frutos do mar"]),
        ShoppingCatalogItem(name: "Peito de peru", defaultQuantity: "200 g", category: .proteins),
        ShoppingCatalogItem(name: "Presunto magro", defaultQuantity: "200 g", category: .proteins),
        ShoppingCatalogItem(name: "Tofu", defaultQuantity: "300 g", category: .proteins, keywords: ["vegetal", "soja"]),
        ShoppingCatalogItem(name: "Tempeh", defaultQuantity: "200 g", category: .proteins, keywords: ["soja"]),
    ]

    // MARK: - Vegetais

    private static let vegetables: [ShoppingCatalogItem] = [
        ShoppingCatalogItem(name: "Alface", defaultQuantity: "1 maço", category: .vegetables, keywords: ["folha", "salada"]),
        ShoppingCatalogItem(name: "Rúcula", defaultQuantity: "1 maço", category: .vegetables, keywords: ["folha", "salada"]),
        ShoppingCatalogItem(name: "Espinafre", defaultQuantity: "1 maço", category: .vegetables, keywords: ["folha"]),
        ShoppingCatalogItem(name: "Couve", defaultQuantity: "1 maço", category: .vegetables),
        ShoppingCatalogItem(name: "Brócolis", defaultQuantity: "500 g", category: .vegetables),
        ShoppingCatalogItem(name: "Couve-flor", defaultQuantity: "1 un", category: .vegetables),
        ShoppingCatalogItem(name: "Cenoura", defaultQuantity: "500 g", category: .vegetables),
        ShoppingCatalogItem(name: "Tomate", defaultQuantity: "500 g", category: .vegetables),
        ShoppingCatalogItem(name: "Tomate cereja", defaultQuantity: "1 pote", category: .vegetables),
        ShoppingCatalogItem(name: "Pepino", defaultQuantity: "2 un", category: .vegetables),
        ShoppingCatalogItem(name: "Abobrinha", defaultQuantity: "3 un", category: .vegetables),
        ShoppingCatalogItem(name: "Berinjela", defaultQuantity: "2 un", category: .vegetables),
        ShoppingCatalogItem(name: "Pimentão", defaultQuantity: "3 un", category: .vegetables),
        ShoppingCatalogItem(name: "Cebola", defaultQuantity: "500 g", category: .vegetables),
        ShoppingCatalogItem(name: "Alho", defaultQuantity: "1 cabeça", category: .vegetables),
        ShoppingCatalogItem(name: "Batata", defaultQuantity: "1 kg", category: .vegetables),
        ShoppingCatalogItem(name: "Batata doce", defaultQuantity: "1 kg", category: .grains, keywords: ["carboidrato"]),
        ShoppingCatalogItem(name: "Mandioca", defaultQuantity: "1 kg", category: .vegetables, keywords: ["aipim"]),
        ShoppingCatalogItem(name: "Chuchu", defaultQuantity: "2 un", category: .vegetables),
        ShoppingCatalogItem(name: "Vagem", defaultQuantity: "300 g", category: .vegetables),
        ShoppingCatalogItem(name: "Beterraba", defaultQuantity: "500 g", category: .vegetables),
        ShoppingCatalogItem(name: "Repolho", defaultQuantity: "1 un", category: .vegetables),
        ShoppingCatalogItem(name: "Mix de folhas", defaultQuantity: "1 pote", category: .vegetables, keywords: ["salada"]),
    ]

    // MARK: - Frutas

    private static let fruits: [ShoppingCatalogItem] = [
        ShoppingCatalogItem(name: "Banana", defaultQuantity: "1 cacho", category: .fruits),
        ShoppingCatalogItem(name: "Maçã", defaultQuantity: "6 un", category: .fruits),
        ShoppingCatalogItem(name: "Laranja", defaultQuantity: "4 un", category: .fruits),
        ShoppingCatalogItem(name: "Mamão", defaultQuantity: "1 un", category: .fruits, keywords: ["papaia"]),
        ShoppingCatalogItem(name: "Abacaxi", defaultQuantity: "1 un", category: .fruits),
        ShoppingCatalogItem(name: "Morango", defaultQuantity: "1 pote", category: .fruits),
        ShoppingCatalogItem(name: "Uva", defaultQuantity: "1 cacho", category: .fruits),
        ShoppingCatalogItem(name: "Manga", defaultQuantity: "2 un", category: .fruits),
        ShoppingCatalogItem(name: "Kiwi", defaultQuantity: "4 un", category: .fruits),
        ShoppingCatalogItem(name: "Abacate", defaultQuantity: "2 un", category: .fruits),
        ShoppingCatalogItem(name: "Pera", defaultQuantity: "3 un", category: .fruits),
        ShoppingCatalogItem(name: "Melancia", defaultQuantity: "1 fatia", category: .fruits),
        ShoppingCatalogItem(name: "Melão", defaultQuantity: "1 un", category: .fruits),
        ShoppingCatalogItem(name: "Goiaba", defaultQuantity: "4 un", category: .fruits),
        ShoppingCatalogItem(name: "Maracujá", defaultQuantity: "4 un", category: .fruits),
        ShoppingCatalogItem(name: "Açaí", defaultQuantity: "500 g", category: .fruits, keywords: ["polpa"]),
        ShoppingCatalogItem(name: "Mirtilo", defaultQuantity: "1 pote", category: .fruits, keywords: ["blueberry"]),
        ShoppingCatalogItem(name: "Framboesa", defaultQuantity: "1 pote", category: .fruits),
        ShoppingCatalogItem(name: "Limão", defaultQuantity: "6 un", category: .fruits),
        ShoppingCatalogItem(name: "Tangerina", defaultQuantity: "6 un", category: .fruits, keywords: ["mexerica"]),
    ]

    // MARK: - Grãos

    private static let grains: [ShoppingCatalogItem] = [
        ShoppingCatalogItem(name: "Arroz integral", defaultQuantity: "1 kg", category: .grains, keywords: ["arroz"]),
        ShoppingCatalogItem(name: "Arroz branco", defaultQuantity: "1 kg", category: .grains),
        ShoppingCatalogItem(name: "Aveia", defaultQuantity: "500 g", category: .grains, keywords: ["flocos"]),
        ShoppingCatalogItem(name: "Feijão preto", defaultQuantity: "500 g", category: .grains, keywords: ["feijao", "leguminosa"]),
        ShoppingCatalogItem(name: "Feijão carioca", defaultQuantity: "500 g", category: .grains),
        ShoppingCatalogItem(name: "Lentilha", defaultQuantity: "300 g", category: .grains, keywords: ["leguminosa"]),
        ShoppingCatalogItem(name: "Grão-de-bico", defaultQuantity: "300 g", category: .grains, keywords: ["leguminosa"]),
        ShoppingCatalogItem(name: "Quinoa", defaultQuantity: "300 g", category: .grains),
        ShoppingCatalogItem(name: "Pão integral", defaultQuantity: "1 pacote", category: .grains, keywords: ["pao"]),
        ShoppingCatalogItem(name: "Macarrão integral", defaultQuantity: "500 g", category: .grains, keywords: ["massa"]),
        ShoppingCatalogItem(name: "Goma de tapioca", defaultQuantity: "500 g", category: .grains, keywords: ["tapioca"]),
        ShoppingCatalogItem(name: "Granola", defaultQuantity: "300 g", category: .grains),
        ShoppingCatalogItem(name: "Chia", defaultQuantity: "200 g", category: .grains, keywords: ["semente"]),
        ShoppingCatalogItem(name: "Linhaça", defaultQuantity: "200 g", category: .grains, keywords: ["semente"]),
        ShoppingCatalogItem(name: "Farinha de aveia", defaultQuantity: "300 g", category: .grains),
        ShoppingCatalogItem(name: "Cuscuz", defaultQuantity: "500 g", category: .grains),
        ShoppingCatalogItem(name: "Milho verde", defaultQuantity: "2 espigas", category: .grains),
        ShoppingCatalogItem(name: "Tortilla integral", defaultQuantity: "1 pacote", category: .grains),
    ]

    // MARK: - Laticínios

    private static let dairy: [ShoppingCatalogItem] = [
        ShoppingCatalogItem(name: "Leite desnatado", defaultQuantity: "1 L", category: .dairy, keywords: ["leite"]),
        ShoppingCatalogItem(name: "Leite sem lactose", defaultQuantity: "1 L", category: .dairy),
        ShoppingCatalogItem(name: "Iogurte natural", defaultQuantity: "4 un", category: .dairy, keywords: ["iogurte"]),
        ShoppingCatalogItem(name: "Iogurte grego", defaultQuantity: "2 un", category: .dairy),
        ShoppingCatalogItem(name: "Queijo cottage", defaultQuantity: "200 g", category: .dairy, keywords: ["queijo"]),
        ShoppingCatalogItem(name: "Queijo minas", defaultQuantity: "300 g", category: .dairy, keywords: ["queijo"]),
        ShoppingCatalogItem(name: "Queijo coalho", defaultQuantity: "200 g", category: .dairy, keywords: ["queijo"]),
        ShoppingCatalogItem(name: "Queijo mussarela 300 g", defaultQuantity: "300 g", category: .dairy, keywords: ["queijo", "mussarela"]),
        ShoppingCatalogItem(name: "Queijo mussarela 600 g", defaultQuantity: "600 g", category: .dairy, keywords: ["queijo", "mussarela"]),
        ShoppingCatalogItem(name: "Queijo cheddar", defaultQuantity: "300 g", category: .dairy, keywords: ["queijo", "cheddar"]),
        ShoppingCatalogItem(name: "Requeijão light", defaultQuantity: "1 un", category: .dairy),
        ShoppingCatalogItem(name: "Ricota", defaultQuantity: "250 g", category: .dairy, keywords: ["queijo"]),
        ShoppingCatalogItem(name: "Leite de amêndoas", defaultQuantity: "1 L", category: .dairy, keywords: ["vegetal", "sem lactose"]),
        ShoppingCatalogItem(name: "Manteiga", defaultQuantity: "200 g", category: .dairy),
        ShoppingCatalogItem(name: "Creme de ricota", defaultQuantity: "200 g", category: .dairy),
    ]

    // MARK: - Suplementos

    private static let supplements: [ShoppingCatalogItem] = [
        ShoppingCatalogItem(name: "Whey protein", defaultQuantity: "900 g", category: .supplements, keywords: ["proteina", "whey"]),
        ShoppingCatalogItem(name: "Creatina", defaultQuantity: "300 g", category: .supplements),
        ShoppingCatalogItem(name: "Ômega 3", defaultQuantity: "1 frasco", category: .supplements, keywords: ["omega", "oleo de peixe"]),
        ShoppingCatalogItem(name: "Ômega 3-6-9", defaultQuantity: "1 frasco", category: .supplements, keywords: ["omega"]),
        ShoppingCatalogItem(name: "Beta-alanina", defaultQuantity: "300 g", category: .supplements, keywords: ["beta alanina"]),
        ShoppingCatalogItem(name: "Pré-treino (até 400 mg cafeína)", defaultQuantity: "1 un", category: .supplements, keywords: ["pre treino", "cafeina"]),
        ShoppingCatalogItem(name: "Multivitamínico", defaultQuantity: "1 frasco", category: .supplements, keywords: ["vitamina"]),
        ShoppingCatalogItem(name: "Vitamina D", defaultQuantity: "1 frasco", category: .supplements),
        ShoppingCatalogItem(name: "Vitamina C", defaultQuantity: "1 frasco", category: .supplements),
        ShoppingCatalogItem(name: "Magnésio", defaultQuantity: "1 frasco", category: .supplements),
        ShoppingCatalogItem(name: "ZMA", defaultQuantity: "1 frasco", category: .supplements, keywords: ["zinco"]),
        ShoppingCatalogItem(name: "Glutamina", defaultQuantity: "300 g", category: .supplements),
        ShoppingCatalogItem(name: "BCAA", defaultQuantity: "300 g", category: .supplements, keywords: ["aminoacido"]),
        ShoppingCatalogItem(name: "Colágeno", defaultQuantity: "300 g", category: .supplements),
        ShoppingCatalogItem(name: "Psyllium", defaultQuantity: "200 g", category: .supplements, keywords: ["fibra"]),
    ]
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
