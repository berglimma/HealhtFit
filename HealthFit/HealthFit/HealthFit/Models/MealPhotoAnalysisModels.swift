import Foundation

enum MealScanMode: String, CaseIterable, Identifiable, Codable {
    case plate
    case nutritionLabel
    case barcode

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plate: return "Prato"
        case .nutritionLabel: return "Rótulo"
        case .barcode: return "Código"
        }
    }

    var icon: String {
        switch self {
        case .plate: return "fork.knife"
        case .nutritionLabel: return "text.viewfinder"
        case .barcode: return "barcode.viewfinder"
        }
    }

    var captureHint: String {
        switch self {
        case .plate:
            return "Enquadre o prato inteiro, de cima, com boa luz. Evite sombras fortes."
        case .nutritionLabel:
            return "Aproxime da tabela nutricional. Mantenha o texto reto e legível."
        case .barcode:
            return "Centralize o código de barras na foto. Funciona também em produtos embalados no prato."
        }
    }
}

/// Um alimento identificado na foto, com macros da porção atual.
struct DetectedFoodItem: Identifiable, Equatable, Codable, Hashable {
    var id: String
    var name: String
    var proteinGrams: Int
    var carbsGrams: Int
    var fatGrams: Int
    var typicalGrams: Int
    var portionGrams: Int
    var confidence: Double
    var barcode: String?
    /// Macros de referência na porção típica (`typicalGrams`).
    var baseProteinGrams: Int
    var baseCarbsGrams: Int
    var baseFatGrams: Int

    init(
        id: String = UUID().uuidString,
        name: String,
        proteinGrams: Int,
        carbsGrams: Int,
        fatGrams: Int,
        typicalGrams: Int = 150,
        portionGrams: Int? = nil,
        confidence: Double = 0.5,
        barcode: String? = nil,
        baseProteinGrams: Int? = nil,
        baseCarbsGrams: Int? = nil,
        baseFatGrams: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.typicalGrams = max(1, typicalGrams)
        self.portionGrams = max(1, portionGrams ?? typicalGrams)
        self.confidence = min(max(confidence, 0), 1)
        self.barcode = barcode
        self.baseProteinGrams = baseProteinGrams ?? proteinGrams
        self.baseCarbsGrams = baseCarbsGrams ?? carbsGrams
        self.baseFatGrams = baseFatGrams ?? fatGrams
        self.proteinGrams = max(0, proteinGrams)
        self.carbsGrams = max(0, carbsGrams)
        self.fatGrams = max(0, fatGrams)
    }

    var calories: Int {
        MealPhotoAnalysisEntry.estimatedCalories(protein: proteinGrams, carbs: carbsGrams, fat: fatGrams)
    }

    mutating func applyPortionGrams(_ grams: Int) {
        let target = max(1, grams)
        let factor = Double(target) / Double(max(typicalGrams, 1))
        proteinGrams = Int((Double(baseProteinGrams) * factor).rounded())
        carbsGrams = Int((Double(baseCarbsGrams) * factor).rounded())
        fatGrams = Int((Double(baseFatGrams) * factor).rounded())
        portionGrams = target
    }

    static func fromCatalogItem(_ item: FoodMacroItem, confidence: Double) -> DetectedFoodItem {
        DetectedFoodItem(
            name: item.displayName,
            proteinGrams: item.proteinGrams,
            carbsGrams: item.carbsGrams,
            fatGrams: item.fatGrams,
            typicalGrams: item.typicalGrams,
            portionGrams: item.typicalGrams,
            confidence: confidence,
            baseProteinGrams: item.proteinGrams,
            baseCarbsGrams: item.carbsGrams,
            baseFatGrams: item.fatGrams
        )
    }

    static func fromOpenFoodFacts(_ product: OpenFoodFactsService.ProductNutrition, grams: Int) -> DetectedFoodItem {
        let macros100 = OpenFoodFactsService.macros(for: product, grams: 100)
        let macros = OpenFoodFactsService.macros(for: product, grams: grams)
        let label = product.brand.map { "\(product.name) · \($0)" } ?? product.name
        return DetectedFoodItem(
            name: label,
            proteinGrams: macros.protein,
            carbsGrams: macros.carbs,
            fatGrams: macros.fat,
            typicalGrams: 100,
            portionGrams: grams,
            confidence: 0.94,
            barcode: product.barcode,
            baseProteinGrams: macros100.protein,
            baseCarbsGrams: macros100.carbs,
            baseFatGrams: macros100.fat
        )
    }
}

extension Array where Element == DetectedFoodItem {
    var totalProtein: Int { reduce(0) { $0 + $1.proteinGrams } }
    var totalCarbs: Int { reduce(0) { $0 + $1.carbsGrams } }
    var totalFat: Int { reduce(0) { $0 + $1.fatGrams } }
    var totalCalories: Int {
        MealPhotoAnalysisEntry.estimatedCalories(protein: totalProtein, carbs: totalCarbs, fat: totalFat)
    }

    var combinedLabel: String {
        let names = map(\.name)
        switch names.count {
        case 0: return "Refeição"
        case 1: return names[0]
        case 2: return "\(names[0]) e \(names[1])"
        default:
            let head = names.dropLast().joined(separator: ", ")
            return "\(head) e \(names.last!)"
        }
    }

    var averageConfidence: Double {
        guard !isEmpty else { return 0 }
        return map(\.confidence).reduce(0, +) / Double(count)
    }
}

/// Registro de análise de refeição por foto — só macros e rótulo; a imagem é descartada.
struct MealPhotoAnalysisEntry: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var mealType: MealType
    var dayKey: String
    var foodLabel: String
    var proteinGrams: Int
    var carbsGrams: Int
    var fatGrams: Int
    var calories: Int
    var confidence: Double
    var analyzedAt: Date
    var photoDiscarded: Bool
    var detectedItems: [DetectedFoodItem]
    var fromNutritionLabel: Bool
    var scanMode: MealScanMode?

    init(
        id: String = UUID().uuidString,
        mealType: MealType,
        dayKey: String = DailyWellnessEntry.dayKey(for: .now),
        foodLabel: String,
        proteinGrams: Int,
        carbsGrams: Int,
        fatGrams: Int,
        calories: Int? = nil,
        confidence: Double = 0,
        analyzedAt: Date = .now,
        photoDiscarded: Bool = true,
        detectedItems: [DetectedFoodItem] = [],
        fromNutritionLabel: Bool = false,
        scanMode: MealScanMode? = nil
    ) {
        self.id = id
        self.mealType = mealType
        self.dayKey = dayKey
        self.foodLabel = foodLabel
        self.proteinGrams = max(0, proteinGrams)
        self.carbsGrams = max(0, carbsGrams)
        self.fatGrams = max(0, fatGrams)
        self.calories = calories ?? Self.estimatedCalories(
            protein: self.proteinGrams,
            carbs: self.carbsGrams,
            fat: self.fatGrams
        )
        self.confidence = min(max(confidence, 0), 1)
        self.analyzedAt = analyzedAt
        self.photoDiscarded = photoDiscarded
        self.detectedItems = detectedItems
        self.fromNutritionLabel = fromNutritionLabel
        self.scanMode = scanMode
    }

    static func estimatedCalories(protein: Int, carbs: Int, fat: Int) -> Int {
        Int((Double(protein) * 4 + Double(carbs) * 4 + Double(fat) * 9).rounded())
    }
}

struct MealPhotoAnalysisDraft: Equatable {
    var mealType: MealType
    var foodLabel: String
    var proteinGrams: Int
    var carbsGrams: Int
    var fatGrams: Int
    var calories: Int
    var confidence: Double
    var items: [DetectedFoodItem]
    var fromNutritionLabel: Bool
    var scanMode: MealScanMode

    var isValid: Bool {
        !foodLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (proteinGrams > 0 || carbsGrams > 0 || fatGrams > 0)
    }

    mutating func syncTotalsFromItems() {
        guard !items.isEmpty else { return }
        foodLabel = items.combinedLabel
        proteinGrams = items.totalProtein
        carbsGrams = items.totalCarbs
        fatGrams = items.totalFat
        calories = items.totalCalories
        confidence = items.averageConfidence
    }

    func asEntry(dayKey: String = DailyWellnessEntry.dayKey(for: .now)) -> MealPhotoAnalysisEntry {
        MealPhotoAnalysisEntry(
            mealType: mealType,
            dayKey: dayKey,
            foodLabel: foodLabel.trimmingCharacters(in: .whitespacesAndNewlines),
            proteinGrams: proteinGrams,
            carbsGrams: carbsGrams,
            fatGrams: fatGrams,
            calories: calories,
            confidence: confidence,
            detectedItems: items,
            fromNutritionLabel: fromNutritionLabel,
            scanMode: scanMode
        )
    }
}
