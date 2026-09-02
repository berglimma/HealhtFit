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
        // Free: só o essencial (sem cardápio)
        XCTAssertFalse(FeatureGate.canAccess(.mealPlan, tier: .free, gatesEnabled: true))
        XCTAssertFalse(FeatureGate.canAccess(.shoppingList, tier: .free, gatesEnabled: true))
        XCTAssertFalse(FeatureGate.canAccess(.fullWorkouts, tier: .free, gatesEnabled: true))

        // Básico: treinos + Watch
        XCTAssertTrue(FeatureGate.canAccess(.fullWorkouts, tier: .basic, gatesEnabled: true))
        XCTAssertTrue(FeatureGate.canAccess(.appleWatchSync, tier: .basic, gatesEnabled: true))
        XCTAssertTrue(FeatureGate.canAccess(.duoTeam, tier: .basic, gatesEnabled: true))
        XCTAssertFalse(FeatureGate.canAccess(.duoTeam, tier: .free, gatesEnabled: true))
        XCTAssertFalse(FeatureGate.canAccess(.mealPlan, tier: .basic, gatesEnabled: true))

        // Fit: cardápio + modalidades + IA limitada
        XCTAssertTrue(FeatureGate.canAccess(.mealPlan, tier: .fit, gatesEnabled: true))
        XCTAssertTrue(FeatureGate.canAccess(.shoppingList, tier: .fit, gatesEnabled: true))
        XCTAssertTrue(FeatureGate.canAccess(.customWorkouts, tier: .fit, gatesEnabled: true))
        XCTAssertTrue(FeatureGate.canAccess(.advancedModalities, tier: .fit, gatesEnabled: true))
        XCTAssertTrue(FeatureGate.canAccess(.aiChatLimited, tier: .fit, gatesEnabled: true))
        XCTAssertFalse(FeatureGate.canAccess(.mealPhotoAnalysis, tier: .fit, gatesEnabled: true))
        XCTAssertFalse(FeatureGate.canAccess(.aiChatUnlimited, tier: .fit, gatesEnabled: true))

        // IA Plus: foto de nutrição + análises
        XCTAssertTrue(FeatureGate.canAccess(.mealPhotoAnalysis, tier: .ai, gatesEnabled: true))
        XCTAssertTrue(FeatureGate.canAccess(.nutritionCoach, tier: .ai, gatesEnabled: true))
        XCTAssertTrue(FeatureGate.canAccess(.aiChatUnlimited, tier: .ai, gatesEnabled: true))
        XCTAssertTrue(FeatureGate.canAccess(.monthlyReport, tier: .ai, gatesEnabled: true))
        XCTAssertTrue(FeatureGate.canAccess(.advancedSportAnalytics, tier: .ai, gatesEnabled: true))

        XCTAssertTrue(FeatureGate.canAccess(.completePriority, tier: .complete, gatesEnabled: true))
    }

    func testFeatureGatesOpenWhenDisabled() {
        XCTAssertTrue(FeatureGate.canAccess(.mealPlan, tier: .free, gatesEnabled: false))
        XCTAssertTrue(FeatureGate.canAccess(.mealPhotoAnalysis, tier: .free, gatesEnabled: false))
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
