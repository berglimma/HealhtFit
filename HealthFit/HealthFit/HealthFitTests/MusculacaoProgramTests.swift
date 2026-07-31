import XCTest
@testable import HealthFit

final class MusculacaoProgramTests: XCTestCase {
    func testResolveFromStandardTitles() {
        XCTAssertEqual(
            MusculacaoProgram.resolve(sheet: nil, fallbackTitle: "Masculino A — Peito e Tríceps"),
            .male
        )
        XCTAssertEqual(
            MusculacaoProgram.resolve(sheet: nil, fallbackTitle: "Feminino B — Pernas e Core"),
            .female
        )
        XCTAssertEqual(
            MusculacaoProgram.resolve(sheet: nil, fallbackTitle: "Mobilidade C — Quadril e Posterior"),
            .mobility
        )
    }

    func testResolveExcludesHomeCardioMeditation() {
        XCTAssertNil(MusculacaoProgram.resolve(sheet: nil, fallbackTitle: "Casa A — Full Body"))
        XCTAssertNil(MusculacaoProgram.resolve(sheet: nil, fallbackTitle: "Cardio — Corrida 5 km"))
        XCTAssertNil(MusculacaoProgram.resolve(sheet: nil, fallbackTitle: "Meditação — Respiração"))
    }

    func testResolveUsesSheetTargetGenderForCustomOrGuided() {
        let sheet = WorkoutSheet(
            title: "Hipertrofia peito",
            targetGender: .female
        )
        XCTAssertEqual(
            MusculacaoProgram.resolve(sheet: sheet, fallbackTitle: "Hipertrofia peito"),
            .female
        )
    }

    func testSessionTitleWinsOverSheetGenderForStandards() {
        let sheet = WorkoutSheet(
            title: "Masculino A — Peito e Tríceps",
            targetGender: .female
        )
        XCTAssertEqual(
            MusculacaoProgram.resolve(sheet: sheet, fallbackTitle: "Masculino A — Peito e Tríceps"),
            .male
        )
    }

    func testDoesNotMixProgramsAcrossTitles() {
        XCTAssertNotEqual(
            MusculacaoProgram.resolve(sheet: nil, fallbackTitle: "Masculino A"),
            MusculacaoProgram.resolve(sheet: nil, fallbackTitle: "Feminino A")
        )
        XCTAssertNotEqual(
            MusculacaoProgram.resolve(sheet: nil, fallbackTitle: "Masculino A"),
            MusculacaoProgram.resolve(sheet: nil, fallbackTitle: "Mobilidade A")
        )
    }
}
