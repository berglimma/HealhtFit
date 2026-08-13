import XCTest
@testable import HealthFit

final class MealPhotoAnalysisEngineTests: XCTestCase {
    func testCaloriesFromMacros() {
        let calories = MealPhotoAnalysisEntry.estimatedCalories(protein: 30, carbs: 40, fat: 10)
        XCTAssertEqual(calories, 370)
    }

    func testCatalogMatchesChicken() {
        let item = FoodMacroCatalog.item(matching: "grilled chicken")
        XCTAssertEqual(item?.displayName, "Frango grelhado")
        XCTAssertGreaterThan(item?.proteinGrams ?? 0, 20)
    }

    func testCatalogMatchesVisionLabelPizza() {
        let item = FoodMacroCatalog.item(matchingVisionLabel: "pepperoni pizza")
        XCTAssertEqual(item?.displayName, "Pizza")
    }

    func testOCRTextFindsMultipleFoods() {
        let hits = MealPhotoAnalysisEngine.matchAllInText(
            "Marmita: frango grelhado, arroz branco e brocolis",
            sourceBoost: 0.85
        )
        let names = Set(hits.map(\.item.displayName))
        XCTAssertTrue(names.contains("Frango grelhado"))
        XCTAssertTrue(names.contains("Arroz") || names.contains("Arroz e feijão"))
        XCTAssertTrue(names.contains("Brócolis"))
    }

    func testMergeHitsKeepsBestAndDropsWeakGeneric() {
        let frango = FoodMacroCatalog.item(matching: "frango")!
        let prato = FoodMacroCatalog.item(matching: "marmita")!
        let arroz = FoodMacroCatalog.item(matching: "arroz")!
        let merged = MealPhotoAnalysisEngine.mergeHits([
            .init(item: frango, confidence: 0.8, source: "vision"),
            .init(item: prato, confidence: 0.3, source: "vision"),
            .init(item: arroz, confidence: 0.7, source: "ocr"),
            .init(item: frango, confidence: 0.5, source: "ocr"),
        ])
        let names = merged.map(\.item.displayName)
        XCTAssertTrue(names.contains("Frango grelhado"))
        XCTAssertTrue(names.contains("Arroz"))
        XCTAssertFalse(names.contains("Prato feito"))
        XCTAssertEqual(merged.first(where: { $0.item.displayName == "Frango grelhado" })?.confidence, 0.8)
    }

    func testMergeConsolidatesRiceAndBeans() {
        let arroz = FoodMacroCatalog.item(matching: "arroz")!
        let feijao = FoodMacroCatalog.item(matching: "feijao")!
        let merged = MealPhotoAnalysisEngine.mergeHits([
            .init(item: arroz, confidence: 0.7, source: "ocr"),
            .init(item: feijao, confidence: 0.68, source: "ocr"),
        ])
        let names = merged.map(\.item.displayName)
        XCTAssertTrue(names.contains("Arroz e feijão"))
        XCTAssertFalse(names.contains("Arroz"))
        XCTAssertFalse(names.contains("Feijão"))
    }

    func testMergeDropsPotatoWhenSweetPotatoPresent() {
        let doce = FoodMacroCatalog.item(matching: "batata doce")!
        let batata = FoodMacroCatalog.item(matching: "batata frita")!
        let merged = MealPhotoAnalysisEngine.mergeHits([
            .init(item: doce, confidence: 0.85, source: "ocr"),
            .init(item: batata, confidence: 0.6, source: "ocr"),
        ])
        let names = merged.map(\.item.displayName)
        XCTAssertTrue(names.contains("Batata doce"))
        XCTAssertFalse(names.contains("Batata"))
    }

    func testShortKeywordRequiresWordBoundary() {
        XCTAssertTrue(MealPhotoAnalysisEngine.textContainsKeyword("pao frances na mesa", keyword: "pao"))
        XCTAssertFalse(MealPhotoAnalysisEngine.textContainsKeyword("paodeacucar", keyword: "pao"))
        XCTAssertFalse(MealPhotoAnalysisEngine.textContainsKeyword("orangeade gelada", keyword: "orange"))
    }

    func testParseNutritionLabelPortuguese() {
        let text = """
        Informação Nutricional
        Porção 100 g
        Valor energético 220 kcal
        Carboidratos 28 g
        Proteínas 18 g
        Gorduras totais 6 g
        """
        let reading = MealPhotoAnalysisEngine.parseNutritionLabel(from: text)
        XCTAssertNotNil(reading)
        XCTAssertEqual(reading?.proteinGrams, 18)
        XCTAssertEqual(reading?.carbsGrams, 28)
        XCTAssertEqual(reading?.fatGrams, 6)
        XCTAssertEqual(reading?.calories, 220)
        XCTAssertTrue(reading?.isPer100g == true)
    }

    func testParseNutritionLabelEnglish() {
        let text = """
        Nutrition Facts
        Calories 150
        Total Carbohydrate 12 g
        Protein 20 g
        Total Fat 4 g
        """
        let reading = MealPhotoAnalysisEngine.parseNutritionLabel(from: text)
        XCTAssertNotNil(reading)
        XCTAssertEqual(reading?.proteinGrams, 20)
        XCTAssertEqual(reading?.carbsGrams, 12)
        XCTAssertEqual(reading?.fatGrams, 4)
    }

    func testComposeEstimateJoinsFoodNames() {
        let frango = FoodMacroCatalog.item(matching: "frango")!
        let arroz = FoodMacroCatalog.item(matching: "arroz")!
        let estimate = MealPhotoAnalysisEngine.composeEstimate(
            from: [
                .init(item: frango, confidence: 0.9, source: "vision"),
                .init(item: arroz, confidence: 0.8, source: "ocr"),
            ],
            ocrBoosted: true
        )
        XCTAssertTrue(estimate.foodLabel.contains("Frango"))
        XCTAssertTrue(estimate.foodLabel.contains("Arroz"))
        XCTAssertEqual(estimate.detectedFoods.count, 2)
        XCTAssertGreaterThan(estimate.proteinGrams, 30)
        XCTAssertFalse(estimate.fromNutritionLabel)
    }

    func testDraftRequiresFoodAndMacros() {
        var draft = MealPhotoAnalysisDraft(
            mealType: .lunch,
            foodLabel: "",
            proteinGrams: 20,
            carbsGrams: 30,
            fatGrams: 10,
            calories: 290,
            confidence: 0.5
        )
        XCTAssertFalse(draft.isValid)

        draft.foodLabel = "Arroz e feijão"
        XCTAssertTrue(draft.isValid)

        let entry = draft.asEntry()
        XCTAssertTrue(entry.photoDiscarded)
        XCTAssertEqual(entry.mealType, .lunch)
    }

    func testAllMealTypesAvailableForAnalysis() {
        let labels = MealType.allCases.map(\.shortLabel)
        XCTAssertEqual(labels, ["Café", "Lanche", "Almoço", "Lanche T.", "Janta", "Ceia"])
    }
}
