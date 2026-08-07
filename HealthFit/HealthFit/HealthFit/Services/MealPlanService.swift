import Foundation
import Combine

@MainActor
final class MealPlanService: ObservableObject {
    @Published var weeklyPlan: [DailyMealPlan] = []
    @Published var shoppingList: [ShoppingItem] = []
    @Published var basalMetabolicRate: Int = 0
    @Published var dailyCalorieTarget: Int = 0
    @Published var estimatedTDEE: Int = 0
    @Published var caloricDeficit: Int = 0
    @Published var customMenuSelection: CustomMenuSelection = .default

    private let planKey = "healthfit_meal_plan"
    private let shoppingKey = "healthfit_shopping_list"
    private let customMenuKey = "healthfit_custom_menu"
    private let purchaseStatsKey = "healthfit_shopping_purchase_stats"
    private var boundUserId: String?

    private enum ScopedKey {
        static let plan = "meal_plan"
        static let shopping = "shopping_list"
        static let customMenu = "custom_menu"
        static let purchaseStats = "shopping_purchase_stats"
    }

    @Published private(set) var purchaseStats: [ShoppingPurchaseStat] = []

    func bind(userId: String?) {
        guard boundUserId != userId else { return }
        boundUserId = userId
        loadSavedData()
        Task {
            await syncFromCloudIfNeeded()
        }
    }

    func clearAllLocalData() {
        weeklyPlan = []
        shoppingList = []
        basalMetabolicRate = 0
        dailyCalorieTarget = 0
        estimatedTDEE = 0
        caloricDeficit = 0
        customMenuSelection = .default
        purchaseStats = []
        UserScopedDefaults.remove(logicalKey: ScopedKey.plan, uid: boundUserId, legacyKey: planKey)
        UserScopedDefaults.remove(logicalKey: ScopedKey.shopping, uid: boundUserId, legacyKey: shoppingKey)
        UserScopedDefaults.remove(logicalKey: ScopedKey.customMenu, uid: boundUserId, legacyKey: customMenuKey)
        UserScopedDefaults.remove(logicalKey: ScopedKey.purchaseStats, uid: boundUserId, legacyKey: purchaseStatsKey)
        boundUserId = nil
        syncMealReminders()
    }

    func generatePlan(for profile: UserProfile) {
        guard customMenuSelection.isReadyToBuild else { return }

        basalMetabolicRate = profile.basalMetabolicRate
        estimatedTDEE = profile.estimatedTDEE
        caloricDeficit = profile.caloricDeficit
        dailyCalorieTarget = profile.dailyCalorieTarget
        ensureDefaultSelections(goal: profile.goal)
        weeklyPlan = Self.buildWeeklyPlan(
            calorieBase: profile.dailyCalorieTarget,
            goal: profile.goal,
            sweetLevel: customMenuSelection.sweetConsumption,
            customSelection: customMenuSelection
        )
        generateShoppingList()
        saveData()
        syncMealReminders()
    }

    func regeneratePlanIfNeeded(for profile: UserProfile) {
        guard !weeklyPlan.isEmpty else { return }
        generatePlan(for: profile)
    }

    func updateSweetConsumption(_ level: SweetConsumptionLevel, profile: UserProfile?) {
        customMenuSelection.sweetConsumption = level
        resetSelectionsForPreferences(profile: profile)
    }

    func updateLactoseTolerance(_ tolerance: LactoseTolerance, profile: UserProfile?) {
        customMenuSelection.lactoseTolerance = tolerance
        resetSelectionsForPreferences(profile: profile)
    }

    func updateMealSelection(_ templateID: UUID, for mealType: MealType, profile: UserProfile?) {
        customMenuSelection.setSelection(templateID, for: mealType)
        if let profile {
            generatePlan(for: profile)
        } else {
            saveData()
        }
    }

    func updateEnergyDrinksPerWeek(_ count: Int, profile: UserProfile?) {
        customMenuSelection.energyDrinksPerWeek = max(0, count)
        generateShoppingList()
    }

    func updateEnergyDrinksPerDay(_ count: Int) {
        customMenuSelection.energyDrinksPerDay = max(0, count)
        saveData()
    }

    func builtMenuMeals(for profile: UserProfile) -> [Meal] {
        guard customMenuSelection.isReadyToBuild else { return [] }
        ensureDefaultSelections(goal: profile.goal)
        guard let lactose = customMenuSelection.lactoseTolerance else { return [] }

        return Self.mealsFromSelection(
            calorieBase: profile.dailyCalorieTarget,
            goal: profile.goal,
            sweetLevel: customMenuSelection.sweetConsumption,
            lactoseTolerance: lactose,
            selection: customMenuSelection,
            variation: 0,
            useCustomSelections: true
        )
    }

    func builtMenuOption(for profile: UserProfile) -> MealPlanOption {
        let meals = builtMenuMeals(for: profile)
        return MealPlanOption(
            name: "Meu Cardápio",
            subtitle: "Montado por você",
            meals: meals
        )
    }

    func generateShoppingList() {
        var ingredientCounts: [String: (quantity: String, category: ShoppingCategory)] = [:]

        for day in weeklyPlan {
            for option in day.options {
                for meal in option.meals {
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
        }

        for staple in Self.weeklyStaples {
            guard !ingredientAlreadyListed(staple.name, in: ingredientCounts) else { continue }
            ingredientCounts[staple.name] = (staple.quantity, staple.category)
        }

        for staple in Self.supplementStaples {
            guard !ingredientAlreadyListed(staple.name, in: ingredientCounts) else { continue }
            ingredientCounts[staple.name] = (staple.quantity, staple.category)
        }

        let energyCount = customMenuSelection.energyDrinksPerWeek
        if energyCount > 0 {
            ingredientCounts["Energético"] = ("\(energyCount) un/semana", .other)
        }

        let weekStart = Calendar.current.startOfDay(for: .now)
        shoppingList = ingredientCounts.map { name, info in
            ShoppingItem(name: name, quantity: info.quantity, category: info.category, weekStartDate: weekStart)
        }.sorted { $0.category.rawValue < $1.category.rawValue }

        saveData()
    }

    func togglePurchased(_ item: ShoppingItem) {
        if let index = shoppingList.firstIndex(where: { $0.id == item.id }) {
            let wasPurchased = shoppingList[index].isPurchased
            shoppingList[index].isPurchased.toggle()

            if !wasPurchased && shoppingList[index].isPurchased {
                recordPurchase(name: shoppingList[index].name)
            }

            saveData()
        }
    }

    func setMealCompleted(
        dayIndex: Int,
        optionIndex: Int,
        mealId: UUID,
        completed: Bool
    ) {
        guard weeklyPlan.indices.contains(dayIndex),
              weeklyPlan[dayIndex].options.indices.contains(optionIndex),
              let mealIndex = weeklyPlan[dayIndex].options[optionIndex].meals.firstIndex(where: { $0.id == mealId })
        else { return }

        weeklyPlan[dayIndex].options[optionIndex].meals[mealIndex].isCompleted = completed
        objectWillChange.send()
        saveData()
    }

    func toggleMealCompleted(dayIndex: Int, optionIndex: Int, mealId: UUID) {
        guard weeklyPlan.indices.contains(dayIndex),
              weeklyPlan[dayIndex].options.indices.contains(optionIndex),
              let mealIndex = weeklyPlan[dayIndex].options[optionIndex].meals.firstIndex(where: { $0.id == mealId })
        else { return }

        let current = weeklyPlan[dayIndex].options[optionIndex].meals[mealIndex].isCompleted
        setMealCompleted(
            dayIndex: dayIndex,
            optionIndex: optionIndex,
            mealId: mealId,
            completed: !current
        )
    }

    var topPurchasedItems: [ShoppingPurchaseStat] {
        purchaseStats
            .sorted {
                if $0.purchaseCount == $1.purchaseCount {
                    return $0.lastPurchasedAt > $1.lastPurchasedAt
                }
                return $0.purchaseCount > $1.purchaseCount
            }
    }

    func recordPurchase(name: String) {
        let normalized = normalizedIngredient(name)
        guard !normalized.isEmpty else { return }

        if let index = purchaseStats.firstIndex(where: { $0.normalizedName == normalized }) {
            purchaseStats[index].purchaseCount += 1
            purchaseStats[index].lastPurchasedAt = .now
            if purchaseStats[index].displayName.count < name.count {
                purchaseStats[index].displayName = name
            }
        } else {
            purchaseStats.append(
                ShoppingPurchaseStat(
                    normalizedName: normalized,
                    displayName: name,
                    purchaseCount: 1,
                    lastPurchasedAt: .now
                )
            )
        }

        savePurchaseStats()
    }

    func removePurchaseStat(_ stat: ShoppingPurchaseStat) {
        purchaseStats.removeAll { $0.normalizedName == stat.normalizedName }
        savePurchaseStats()
    }

    func buildWeeklyShoppingReport(referenceDate: Date = .now) -> WeeklyShoppingReport {
        ShoppingReportBuilder.build(
            shoppingList: shoppingList,
            purchaseStats: purchaseStats,
            energyDrinksPerWeek: customMenuSelection.energyDrinksPerWeek,
            referenceDate: referenceDate
        )
    }

    func addCatalogItem(_ catalogItem: ShoppingCatalogItem) {
        guard !containsShoppingItem(named: catalogItem.name) else { return }

        let weekStart = Calendar.current.startOfDay(for: .now)
        shoppingList.append(
            ShoppingItem(
                name: catalogItem.name,
                quantity: catalogItem.defaultQuantity,
                category: catalogItem.category,
                weekStartDate: weekStart
            )
        )
        shoppingList.sort { $0.category.rawValue < $1.category.rawValue }
        saveData()
    }

    @discardableResult
    func addCustomShoppingItem(
        name: String,
        quantity: String = "1 un",
        category: ShoppingCategory
    ) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        guard !containsShoppingItem(named: trimmedName) else { return false }

        let trimmedQuantity = quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        let weekStart = Calendar.current.startOfDay(for: .now)
        shoppingList.append(
            ShoppingItem(
                name: trimmedName,
                quantity: trimmedQuantity.isEmpty ? "1 un" : trimmedQuantity,
                category: category,
                weekStartDate: weekStart
            )
        )
        shoppingList.sort { $0.category.rawValue < $1.category.rawValue }
        saveData()
        return true
    }

    func containsShoppingItem(named name: String) -> Bool {
        let normalized = normalizedIngredient(name)
        return shoppingList.contains { normalizedIngredient($0.name) == normalized }
    }

    func filteredShoppingList(query: String, category: ShoppingCategory?) -> [ShoppingItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var items = shoppingList

        if let category {
            items = items.filter { $0.category == category }
        }

        guard !trimmed.isEmpty else { return items }

        let normalizedQuery = normalizedIngredient(trimmed)
        return items.filter { item in
            let name = normalizedIngredient(item.name)
            return name.contains(normalizedQuery)
        }
    }

    func loadSavedData() {
        weeklyPlan = []
        shoppingList = []
        customMenuSelection = .default
        purchaseStats = []

        if let data = UserScopedDefaults.data(forLogicalKey: ScopedKey.plan, uid: boundUserId, legacyKey: planKey),
           let plan = try? JSONDecoder().decode([DailyMealPlan].self, from: data) {
            weeklyPlan = plan
        }
        if let data = UserScopedDefaults.data(forLogicalKey: ScopedKey.shopping, uid: boundUserId, legacyKey: shoppingKey),
           let list = try? JSONDecoder().decode([ShoppingItem].self, from: data) {
            shoppingList = list
        }
        if let data = UserScopedDefaults.data(forLogicalKey: ScopedKey.customMenu, uid: boundUserId, legacyKey: customMenuKey),
           let selection = try? JSONDecoder().decode(CustomMenuSelection.self, from: data) {
            customMenuSelection = selection
        }
        loadPurchaseStats()
        syncMealReminders()
    }

    private func syncMealReminders() {
        NotificationService.shared.updateMealReminders(hasMealPlan: !weeklyPlan.isEmpty)
    }

    private func loadPurchaseStats() {
        guard let data = UserScopedDefaults.data(
            forLogicalKey: ScopedKey.purchaseStats,
            uid: boundUserId,
            legacyKey: purchaseStatsKey
        ),
              let stats = try? JSONDecoder().decode([ShoppingPurchaseStat].self, from: data) else {
            purchaseStats = []
            return
        }
        purchaseStats = stats
    }

    private func savePurchaseStats() {
        if let data = try? JSONEncoder().encode(purchaseStats) {
            UserScopedDefaults.setData(
                data,
                forLogicalKey: ScopedKey.purchaseStats,
                uid: boundUserId,
                legacyKey: purchaseStatsKey
            )
        }
    }

    private func saveData() {
        if let data = try? JSONEncoder().encode(weeklyPlan) {
            UserScopedDefaults.setData(data, forLogicalKey: ScopedKey.plan, uid: boundUserId, legacyKey: planKey)
        }
        if let data = try? JSONEncoder().encode(shoppingList) {
            UserScopedDefaults.setData(data, forLogicalKey: ScopedKey.shopping, uid: boundUserId, legacyKey: shoppingKey)
        }
        if let data = try? JSONEncoder().encode(customMenuSelection) {
            UserScopedDefaults.setData(data, forLogicalKey: ScopedKey.customMenu, uid: boundUserId, legacyKey: customMenuKey)
        }
        Task {
            await pushToCloudIfNeeded()
        }
    }

    private func syncFromCloudIfNeeded() async {
        guard let userId = boundUserId, MealPlanFirestoreService.isAvailable else { return }
        guard weeklyPlan.isEmpty else { return }
        if let remote = try? await MealPlanFirestoreService.fetchPlan(userId: userId) {
            weeklyPlan = remote.weeklyPlan
            shoppingList = remote.shoppingList
            customMenuSelection = remote.customMenuSelection
            basalMetabolicRate = remote.basalMetabolicRate
            dailyCalorieTarget = remote.dailyCalorieTarget
            estimatedTDEE = remote.estimatedTDEE
            caloricDeficit = remote.caloricDeficit
            if let data = try? JSONEncoder().encode(weeklyPlan) {
                UserScopedDefaults.setData(data, forLogicalKey: ScopedKey.plan, uid: boundUserId, legacyKey: planKey)
            }
            if let data = try? JSONEncoder().encode(shoppingList) {
                UserScopedDefaults.setData(data, forLogicalKey: ScopedKey.shopping, uid: boundUserId, legacyKey: shoppingKey)
            }
            if let data = try? JSONEncoder().encode(customMenuSelection) {
                UserScopedDefaults.setData(data, forLogicalKey: ScopedKey.customMenu, uid: boundUserId, legacyKey: customMenuKey)
            }
            syncMealReminders()
        }
    }

    private func pushToCloudIfNeeded() async {
        guard let userId = boundUserId, MealPlanFirestoreService.isAvailable else { return }
        let snapshot = MealPlanCloudSnapshot(
            weeklyPlan: weeklyPlan,
            shoppingList: shoppingList,
            customMenuSelection: customMenuSelection,
            basalMetabolicRate: basalMetabolicRate,
            dailyCalorieTarget: dailyCalorieTarget,
            estimatedTDEE: estimatedTDEE,
            caloricDeficit: caloricDeficit
        )
        try? await MealPlanFirestoreService.savePlan(snapshot, userId: userId)
    }

    private func ensureDefaultSelections(goal: FitnessGoal = .maintenance) {
        guard let lactose = customMenuSelection.lactoseTolerance else { return }

        for mealType in MealType.allCases {
            if customMenuSelection.selectedTemplateID(for: mealType) == nil {
                let template = MealCatalog.defaultTemplate(
                    for: mealType,
                    sweetLevel: customMenuSelection.sweetConsumption,
                    goal: goal,
                    lactoseTolerance: lactose,
                    index: mealTypeCalorieOrder.firstIndex(of: mealType) ?? 0
                )
                customMenuSelection.setSelection(template.id, for: mealType)
            } else if let selectedID = customMenuSelection.selectedTemplateID(for: mealType),
                      let template = MealCatalog.template(id: selectedID),
                      lactose == .intolerant && template.containsLactose {
                let replacement = MealCatalog.defaultTemplate(
                    for: mealType,
                    sweetLevel: customMenuSelection.sweetConsumption,
                    goal: goal,
                    lactoseTolerance: lactose,
                    index: 0
                )
                customMenuSelection.setSelection(replacement.id, for: mealType)
            }
        }
    }

    private func resetSelectionsForPreferences(profile: UserProfile?) {
        customMenuSelection.selections = [:]
        ensureDefaultSelections(goal: profile?.goal ?? .maintenance)
        if let profile, customMenuSelection.isReadyToBuild {
            generatePlan(for: profile)
        } else {
            saveData()
        }
    }

    private var mealTypeCalorieOrder: [MealType] {
        MealType.allCases
    }

    private static let weeklyStaples: [(name: String, quantity: String, category: ShoppingCategory)] = [
        ("Banana", "1 cacho", .fruits),
        ("Maçã", "6 un", .fruits),
        ("Laranja", "4 un", .fruits),
        ("Mamão", "1 un", .fruits),
        ("Abacaxi", "1 un", .fruits),
        ("Morango", "1 pote", .fruits),
        ("Uva", "1 cacho", .fruits),
        ("Manga", "2 un", .fruits),
        ("Kiwi", "4 un", .fruits),
        ("Abacate", "2 un", .fruits),
        ("Pera", "3 un", .fruits),
        ("Melancia", "1 fatia", .fruits),
        ("Arroz integral", "1 kg", .grains),
        ("Aveia", "500 g", .grains),
        ("Feijão preto", "500 g", .grains),
        ("Lentilha", "300 g", .grains),
        ("Quinoa", "300 g", .grains),
        ("Pão integral", "1 pacote", .grains),
        ("Batata doce", "1 kg", .grains),
        ("Grão-de-bico", "300 g", .grains),
        ("Macarrão integral", "500 g", .grains),
        ("Goma de tapioca", "500 g", .grains),
        ("Peito de frango", "1 kg", .proteins),
        ("Ovos", "1 dúzia", .proteins),
        ("Carne patinho", "500 g", .proteins),
        ("Carne moída", "600 g", .proteins),
        ("Bifes", "600 g", .proteins),
        ("Tilápia", "600 g", .proteins),
        ("Salmão", "400 g", .proteins),
        ("Atum em lata", "2 un", .proteins),
        ("Peito de peru", "200 g", .proteins),
        ("Camarão", "300 g", .proteins),
    ]

    private static let supplementStaples: [(name: String, quantity: String, category: ShoppingCategory)] = [
        ("Creatina", "300 g", .supplements),
        ("Ômega 3", "1 frasco", .supplements),
        ("Ômega 3-6-9", "1 frasco", .supplements),
        ("Beta-alanina", "300 g", .supplements),
        ("Pré-treino (até 400 mg cafeína)", "1 un", .supplements),
    ]

    private func ingredientAlreadyListed(
        _ stapleName: String,
        in counts: [String: (quantity: String, category: ShoppingCategory)]
    ) -> Bool {
        let staple = normalizedIngredient(stapleName)
        return counts.keys.contains { key in
            let listed = normalizedIngredient(key)
            return listed.contains(staple) || staple.contains(listed)
        }
    }

    private func normalizedIngredient(_ name: String) -> String {
        name.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
    }

    private func categorizeIngredient(_ name: String) -> ShoppingCategory {
        let lower = normalizedIngredient(name)

        if containsAny(lower, keywords: [
            "frango", "carne", "peixe", "ovo", "ovos", "claras", "atum", "salmao",
            "tilapia", "camarao", "peru", "patinho", "tofu", "tempeh", "camarão",
            "bife", "bifes", "moida", "moída"
        ]) {
            return .proteins
        }
        if containsAny(lower, keywords: ["whey", "creatina", "omega", "ômega", "beta-alanina", "beta alanina", "pre-treino", "pre treino", "pré-treino"]) {
            return .supplements
        }
        if containsAny(lower, keywords: [
            "leite", "iogurte", "queijo", "cottage", "coalho"
        ]) {
            return .dairy
        }
        if containsAny(lower, keywords: [
            "arroz", "aveia", "pao", "batata", "macarrao", "tapioca", "quinoa",
            "feijao", "lentilha", "mandioca", "cuscuz", "granola", "chia",
            "farinha", "tortilla", "inhame", "graodebico", "grão-de-bico",
            "milho", "centeio"
        ]) {
            return .grains
        }
        if containsAny(lower, keywords: [
            "banana", "maca", "morango", "mirtilo", "fruta", "abacate", "mamao",
            "manga", "kiwi", "uva", "pera", "laranja", "abacaxi", "melancia",
            "melao", "framboesa", "goiaba", "maracuja", "pessego", "ameixa",
            "acai", "açaí", "polpa de acai"
        ]) {
            return .fruits
        }
        if containsAny(lower, keywords: ["bolo", "mel", "cacau", "barra", "energetico", "energético"]) {
            return .other
        }
        return .vegetables
    }

    private func containsAny(_ text: String, keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }

    private static func buildWeeklyPlan(
        calorieBase: Int,
        goal: FitnessGoal,
        sweetLevel: SweetConsumptionLevel,
        customSelection: CustomMenuSelection
    ) -> [DailyMealPlan] {
        guard let lactose = customSelection.lactoseTolerance else { return [] }

        let days = ["Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado", "Domingo"]
        let optionTemplates = goal == .fatLoss
            ? [
                ("Opção 1", "Déficit proteico"),
                ("Opção 2", "Low carb restrito"),
                ("Opção 3", "Leve e saciante"),
            ]
            : [
                ("Opção 1", "Foco proteico"),
                ("Opção 2", "Equilibrado"),
                ("Opção 3", "Prático e leve"),
            ]

        return days.enumerated().map { index, day in
            let options = optionTemplates.enumerated().map { optionIndex, template in
                let variation = (index + optionIndex) % 3
                let meals = mealsFromSelection(
                    calorieBase: calorieBase,
                    goal: goal,
                    sweetLevel: sweetLevel,
                    lactoseTolerance: lactose,
                    selection: customSelection,
                    variation: variation,
                    useCustomSelections: false
                )
                return MealPlanOption(
                    name: template.0,
                    subtitle: template.1,
                    meals: meals
                )
            }

            let customMeals = mealsFromSelection(
                calorieBase: calorieBase,
                goal: goal,
                sweetLevel: sweetLevel,
                lactoseTolerance: lactose,
                selection: customSelection,
                variation: 0,
                useCustomSelections: true
            )
            let customOption = MealPlanOption(
                name: "Montado",
                subtitle: "Suas escolhas",
                meals: customMeals
            )

            return DailyMealPlan(dayOfWeek: day, options: options + [customOption])
        }
    }

    private static func mealsFromSelection(
        calorieBase: Int,
        goal: FitnessGoal,
        sweetLevel: SweetConsumptionLevel,
        lactoseTolerance: LactoseTolerance,
        selection: CustomMenuSelection,
        variation: Int,
        useCustomSelections: Bool
    ) -> [Meal] {
        let proteins = goal == .muscleGain ? 2 : 1

        return MealType.allCases.map { mealType in
            let targetCalories = max(Int(Double(calorieBase) * mealType.calorieShare), 120)
            let template: MealTemplate

            if useCustomSelections,
               let selectedID = selection.selectedTemplateID(for: mealType),
               let selected = MealCatalog.template(id: selectedID),
               lactoseTolerance == .tolerant || !selected.containsLactose {
                template = selected
            } else {
                let alternatives = MealCatalog.templates(
                    for: mealType,
                    sweetLevel: sweetLevel,
                    goal: goal,
                    lactoseTolerance: lactoseTolerance
                )
                let index = (variation + mealTypeCalorieIndex(mealType)) % max(alternatives.count, 1)
                template = alternatives.isEmpty
                    ? MealCatalog.defaultTemplate(
                        for: mealType,
                        sweetLevel: sweetLevel,
                        goal: goal,
                        lactoseTolerance: lactoseTolerance,
                        index: index
                    )
                    : alternatives[index]
            }

            return template.scaled(to: targetCalories, proteinMultiplier: proteins)
        }
    }

    private static func mealTypeCalorieIndex(_ mealType: MealType) -> Int {
        MealType.allCases.firstIndex(of: mealType) ?? 0
    }
}
