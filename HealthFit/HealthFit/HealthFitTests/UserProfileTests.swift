import XCTest
@testable import HealthFit

final class UserProfileTests: XCTestCase {
    func testBMICalculation() {
        let profile = TestFixtures.userProfile(weight: 80, height: 180)
        XCTAssertEqual(profile.bmi, 80.0 / 1.8 / 1.8, accuracy: 0.01)
    }

    func testBasalMetabolicRateMale() {
        let profile = TestFixtures.userProfile(gender: .male, weight: 75, height: 175, age: 28)
        XCTAssertEqual(profile.basalMetabolicRate, 1709)
    }

    func testBasalMetabolicRateFemale() {
        let profile = TestFixtures.userProfile(gender: .female, weight: 60, height: 165, age: 30)
        XCTAssertEqual(profile.basalMetabolicRate, 1320)
    }

    func testEstimatedTDEEEctomorphBonus() {
        let meso = TestFixtures.userProfile(biotype: .mesomorph)
        let ecto = TestFixtures.userProfile(biotype: .ectomorph)
        XCTAssertGreaterThan(ecto.estimatedTDEE, meso.estimatedTDEE)
    }

    func testGreetingNameUsesDisplayNameWhenSet() {
        var profile = TestFixtures.userProfile(name: "João Silva")
        profile.displayName = "Jota"
        XCTAssertEqual(profile.greetingName, "Jota")
        XCTAssertEqual(profile.shownName, "Jota")
    }

    func testGreetingNameFallsBackToFirstName() {
        let profile = TestFixtures.userProfile(name: "João Silva")
        XCTAssertEqual(profile.greetingName, "João")
        XCTAssertEqual(profile.shownName, "João Silva")
    }

    func testEmptyPracticedModalitiesMeansAll() {
        let profile = TestFixtures.userProfile()
        XCTAssertTrue(profile.practicedModalityIDs.isEmpty)
        XCTAssertTrue(profile.practicesAllModalities)
        XCTAssertTrue(profile.practices(PracticeModalityID.strength))
        XCTAssertTrue(profile.practicesCardio(named: "Remo"))
        XCTAssertTrue(profile.practicesAnyCardio)
        XCTAssertEqual(profile.practicedCardioExercises.count, CardioExercise.catalog.count)
    }

    func testPracticedModalitiesFilterAndPersist() throws {
        var profile = TestFixtures.userProfile()
        profile.setPractices(PracticeModalityID.cardio("Remo"), enabled: true)
        // Materializes full list then toggles
        profile.setPractices(PracticeModalityID.cardio("Corrida"), enabled: false)
        XCTAssertFalse(profile.practicesCardio(named: "Corrida"))
        XCTAssertTrue(profile.practicesCardio(named: "Remo"))
        XCTAssertTrue(profile.practices(PracticeModalityID.strength))

        profile.setPracticesAll(false)
        XCTAssertEqual(profile.practicedModalityIDs, [PracticeModalityID.strength])
        XCTAssertFalse(profile.practicesAnyCardio)

        profile.setPracticesAll(true)
        XCTAssertEqual(Set(profile.practicedModalityIDs), Set(PracticeModalityID.allDefaultIDs))

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: data)
        XCTAssertEqual(decoded.practicedModalityIDs, profile.practicedModalityIDs)
    }

    func testCannotClearLastPracticedModality() {
        var profile = TestFixtures.userProfile()
        profile.practicedModalityIDs = [PracticeModalityID.meditation]
        profile.setPractices(PracticeModalityID.meditation, enabled: false)
        XCTAssertTrue(profile.practices(PracticeModalityID.meditation))
    }
}
