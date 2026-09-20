import XCTest
@testable import HealthFit

final class RecommendedWorkoutCatalogTests: XCTestCase {
    func testWarmupBlocksHaveExactlyTwoExercises() {
        let upper = GuidedWorkoutCatalog.warmupBlock(style: .upper, level: .intermediate)
        let lower = GuidedWorkoutCatalog.warmupBlock(style: .lower, level: .intermediate)
        XCTAssertEqual(upper.count, 2)
        XCTAssertEqual(lower.count, 2)
        XCTAssertTrue(upper.allSatisfy { $0.notes == GuidedWorkoutCatalog.warmupNote })
        XCTAssertTrue(lower.allSatisfy { $0.notes == GuidedWorkoutCatalog.warmupNote })
    }

    func testCohortIndexAdvancesEvery30Days() {
        let anchor = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let day29 = Calendar.current.date(byAdding: .day, value: 29, to: anchor)!
        let day30 = Calendar.current.date(byAdding: .day, value: 30, to: anchor)!
        let day60 = Calendar.current.date(byAdding: .day, value: 60, to: anchor)!

        XCTAssertEqual(RecommendedWorkoutCatalog.cohortIndex(at: day29, anchor: anchor), 0)
        XCTAssertEqual(RecommendedWorkoutCatalog.cohortIndex(at: day30, anchor: anchor), 1)
        XCTAssertEqual(RecommendedWorkoutCatalog.cohortIndex(at: day60, anchor: anchor), 2)
    }

    func testMaleCohortsHaveDistinctTitles() {
        let c0 = RecommendedWorkoutCatalog.titles(for: .male, cohort: 0)
        let c1 = RecommendedWorkoutCatalog.titles(for: .male, cohort: 1)
        XCTAssertEqual(c0.count, 7)
        XCTAssertEqual(c1.count, 7)
        XCTAssertTrue(c0.isDisjoint(with: c1))
    }

    func testFemaleCohortsIncludeGluteAndLegGrowthSheets() {
        let c0 = RecommendedWorkoutCatalog.titles(for: .female, cohort: 0)
        XCTAssertEqual(c0.count, 8)
        XCTAssertTrue(c0.contains("Feminino G — Glúteos Crescimento"))
        XCTAssertTrue(c0.contains("Feminino H — Pernas Crescimento"))
        XCTAssertTrue(c0.contains("Feminino E — Superior"))
        XCTAssertTrue(c0.contains("Feminino F — Inferior"))
    }

    func testMaleCohortsIncludeSuperiorInferiorLegsSheets() {
        let c0 = RecommendedWorkoutCatalog.titles(for: .male, cohort: 0)
        XCTAssertTrue(c0.contains("Masculino E — Superior Completo"))
        XCTAssertTrue(c0.contains("Masculino F — Inferior Completo"))
        XCTAssertTrue(c0.contains("Masculino G — Pernas Hipertrofia"))
    }

    func testBaselineSheetsIncludeTwoWarmupExercises() {
        let sheet = RecommendedWorkoutCatalog.baselineMaleSheets[0]
        let warmups = sheet.exercises.filter { $0.notes == GuidedWorkoutCatalog.warmupNote }
        XCTAssertEqual(warmups.count, 2)
    }
}
