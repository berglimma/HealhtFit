import XCTest
@testable import HealthFit

final class SubscriptionModelsTests: XCTestCase {
    func testProductIDsMapToTiers() {
        XCTAssertEqual(SubscriptionProductID.basicMonthly.tier, .basic)
        XCTAssertEqual(SubscriptionProductID.fitMonthly.tier, .fit)
        XCTAssertEqual(SubscriptionProductID.aiMonthly.tier, .ai)
        XCTAssertEqual(SubscriptionProductID.completeMonthly.tier, .complete)
    }

    func testHighestTier() {
        XCTAssertEqual(PlanTier.highest(of: [.basic, .ai, .fit]), .ai)
        XCTAssertEqual(PlanTier.highest(of: []), .free)
    }

    func testFeatureGatesRespectTiersWhenEnabled() {
        XCTAssertTrue(FeatureGate.canAccess(.mealPlan, tier: .fit, gatesEnabled: true))
        XCTAssertFalse(FeatureGate.canAccess(.mealPlan, tier: .basic, gatesEnabled: true))
        XCTAssertTrue(FeatureGate.canAccess(.aiChatUnlimited, tier: .ai, gatesEnabled: true))
        XCTAssertFalse(FeatureGate.canAccess(.aiChatUnlimited, tier: .fit, gatesEnabled: true))
        XCTAssertTrue(FeatureGate.canAccess(.completePriority, tier: .complete, gatesEnabled: true))
    }

    func testFeatureGatesOpenWhenDisabled() {
        XCTAssertTrue(FeatureGate.canAccess(.mealPlan, tier: .free, gatesEnabled: false))
        XCTAssertTrue(FeatureGate.canAccess(.completePriority, tier: .free, gatesEnabled: false))
    }

    func testStorefrontCatalogCount() {
        XCTAssertEqual(SubscriptionProductID.storefrontCatalog.count, 4)
    }
}
