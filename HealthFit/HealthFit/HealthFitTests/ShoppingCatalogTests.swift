import XCTest
@testable import HealthFit

final class ShoppingCatalogTests: XCTestCase {
    func testSearchFindsProteinByKeyword() {
        let results = ShoppingCatalog.search(query: "frango", category: nil)
        XCTAssertTrue(results.contains { $0.name.localizedCaseInsensitiveContains("frango") })
    }

    func testCategoryFilterLimitsResults() {
        let results = ShoppingCatalog.search(query: "", category: .dairy)
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy { $0.category == .dairy })
    }
}
