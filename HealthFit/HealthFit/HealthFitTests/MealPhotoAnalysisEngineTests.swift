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
