import XCTest
@testable import HealthFit

@MainActor
final class CustomWorkoutFocusGroupTests: XCTestCase {
    func testChestExercisesAreClassified() {
        XCTAssertEqual(CustomWorkoutFocusGroup.focusGroup(for: "Supino Reto"), .chest)
        XCTAssertEqual(CustomWorkoutFocusGroup.focusGroup(for: "Flexão de Braços"), .chest)
    }

    func testArmsAreSplitIntoBicepsAndTriceps() {
        XCTAssertEqual(CustomWorkoutFocusGroup.focusGroup(for: "Rosca Direta"), .biceps)
        XCTAssertEqual(CustomWorkoutFocusGroup.focusGroup(for: "Tríceps Pulley"), .triceps)
    }

    func testTrapeziusExercisesAreSeparated() {
        XCTAssertEqual(CustomWorkoutFocusGroup.focusGroup(for: "Encolhimento com Barra"), .trapezius)
        XCTAssertEqual(CustomWorkoutFocusGroup.focusGroup(for: "Remada Alta"), .trapezius)
    }

    func testPresetExercisesForMultipleFocusGroups() {
        let exercises = WorkoutStore.presetExercises(for: [.chest, .triceps])
        let names = Set(exercises.map(\.name))

        XCTAssertTrue(names.contains("Supino Reto"))
        XCTAssertTrue(names.contains("Tríceps Pulley"))
        XCTAssertFalse(names.contains("Rosca Direta"))
    }

    func testAllFocusGroupsHaveCatalogExercises() {
        for group in CustomWorkoutFocusGroup.allCases {
            let exercises = WorkoutStore.presetExercises(for: [group])
            XCTAssertFalse(exercises.isEmpty, "Catálogo vazio para \(group.rawValue)")
        }
    }
}
