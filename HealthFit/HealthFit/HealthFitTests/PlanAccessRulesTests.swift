import XCTest
@testable import HealthFit

final class PlanAccessRulesTests: XCTestCase {
    func testCorridaRequiresBasicPlan() {
        let corrida = TestFixtures.runningExercise
        XCTAssertEqual(PlanAccessRules.requiredFeature(for: corrida), .fullWorkouts)
        XCTAssertEqual(FeatureGate.minimumPlan(for: .fullWorkouts), .basic)
        XCTAssertFalse(FeatureGate.canAccess(.fullWorkouts, tier: .free, gatesEnabled: true))
        XCTAssertTrue(FeatureGate.canAccess(.fullWorkouts, tier: .basic, gatesEnabled: true))
    }

    func testCaminhadaRemainsFree() {
        let walk = CardioExercise.catalog.first { $0.name == "Caminhada" }!
        XCTAssertNil(PlanAccessRules.requiredFeature(for: walk))
    }

    func testSurfRequiresFitPlan() {
        let surf = CardioExercise.catalog.first { $0.name == "Surf" }!
        XCTAssertEqual(PlanAccessRules.requiredFeature(for: surf), .advancedModalities)
    }

    func testDuoTeamRequiresBasicPlan() {
        XCTAssertEqual(FeatureGate.minimumPlan(for: .duoTeam), .basic)
        XCTAssertFalse(FeatureGate.canAccess(.duoTeam, tier: .free, gatesEnabled: true))
        XCTAssertTrue(FeatureGate.canAccess(.duoTeam, tier: .basic, gatesEnabled: true))
    }
}
