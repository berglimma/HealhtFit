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
        XCTAssertTrue(FeatureGate.canAccess(.mealPlan, tier: .free, gatesEnabled: true))
        XCTAssertTrue(FeatureGate.canAccess(.shoppingList, tier: .free, gatesEnabled: true))
        XCTAssertTrue(FeatureGate.canAccess(.nutritionCoach, tier: .basic, gatesEnabled: true))
        XCTAssertTrue(FeatureGate.canAccess(.aiChatUnlimited, tier: .ai, gatesEnabled: true))
        XCTAssertFalse(FeatureGate.canAccess(.aiChatUnlimited, tier: .fit, gatesEnabled: true))
        XCTAssertTrue(FeatureGate.canAccess(.completePriority, tier: .complete, gatesEnabled: true))
    }

    func testFeatureGatesOpenWhenDisabled() {
        XCTAssertTrue(FeatureGate.canAccess(.mealPlan, tier: .free, gatesEnabled: false))
        XCTAssertTrue(FeatureGate.canAccess(.completePriority, tier: .free, gatesEnabled: false))
    }

    func testStorefrontCatalogCount() {
        XCTAssertEqual(SubscriptionProductID.storefrontCatalog.count, 8)
    }

    func testYearlyProductsMapToSameTiers() {
        XCTAssertEqual(SubscriptionProductID.basicYearly.tier, .basic)
        XCTAssertEqual(SubscriptionProductID.fitYearly.tier, .fit)
        XCTAssertEqual(SubscriptionProductID.aiYearly.tier, .ai)
        XCTAssertEqual(SubscriptionProductID.completeYearly.tier, .complete)
        XCTAssertEqual(SubscriptionProductID.basicYearly.billingPeriod, .yearly)
        XCTAssertEqual(SubscriptionProductID.basicMonthly.billingPeriod, .monthly)
    }

    func testProductIDLookupByPeriod() {
        XCTAssertEqual(SubscriptionProductID.productID(tier: .complete, period: .yearly), .completeYearly)
        XCTAssertEqual(SubscriptionProductID.productID(tier: .fit, period: .monthly), .fitMonthly)
        XCTAssertNil(SubscriptionProductID.productID(tier: .free, period: .yearly))
    }

    func testYearlyDiscountPercent() {
        XCTAssertEqual(SubscriptionBillingPeriod.yearlyDiscountPercent, 20)
    }
}
