import XCTest
@testable import HealthFit

final class WorkoutSheetOCRParserTests: XCTestCase {
    func testParseClassicSetsTimesRepsLines() {
        let text = """
        Treino A - Peito e Tríceps
        1. Supino reto 4x12 40kg
        2. Supino Inclinado 3x10
        3. Tríceps Pulley - 4 séries de 12
        Crucifixo Reto 3 x 15 12 kg
        """

        let draft = WorkoutSheetOCRParser.parse(text)
        XCTAssertTrue(draft.title.localizedCaseInsensitiveContains("Treino"))
        XCTAssertGreaterThanOrEqual(draft.exercises.count, 4)

        let supino = draft.exercises.first { $0.name.localizedCaseInsensitiveContains("Supino reto") }
        XCTAssertEqual(supino?.sets, 4)
        XCTAssertEqual(supino?.reps, 12)
        XCTAssertEqual(supino?.weight, 40)

        let pulley = draft.exercises.first { $0.name.localizedCaseInsensitiveContains("Tríceps") || $0.name.localizedCaseInsensitiveContains("Pulley") }
        XCTAssertEqual(pulley?.sets, 4)
        XCTAssertEqual(pulley?.reps, 12)
    }

    func testParseExerciseLineExtractsVolume() {
        let exercise = WorkoutSheetOCRParser.parseExerciseLine("Leg Press 45° 4x15 180kg")
        XCTAssertEqual(exercise?.name.localizedCaseInsensitiveContains("Leg Press"), true)
        XCTAssertEqual(exercise?.sets, 4)
        XCTAssertEqual(exercise?.reps, 15)
        XCTAssertEqual(exercise?.weight, 180)
    }

    func testInferredMuscleGroupForChest() {
        XCTAssertEqual(WorkoutSheetOCRParser.inferredMuscleGroup(for: "Supino Reto"), .chest)
        XCTAssertEqual(WorkoutSheetOCRParser.inferredMuscleGroup(for: "Rosca Direta"), .arms)
    }
}
