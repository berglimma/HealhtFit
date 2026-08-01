import XCTest
@testable import HealthFit

final class ExerciseGifCatalogTests: XCTestCase {
    func testExactMatchForBenchPressGif() {
        let exercise = Exercise(name: "Supino Reto", muscleGroup: .chest)
        let url = ExerciseGifCatalog.remoteGifURL(for: exercise)
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.absoluteString.contains("barbell-bench-press.gif") == true)
        XCTAssertTrue(url?.absoluteString.contains("jsdelivr.net") == true)
    }

    func testKeywordFallbackForCustomExerciseName() {
        let exercise = Exercise(name: "Supino com halteres inclinado", muscleGroup: .chest)
        let path = ExerciseGifCatalog.filePath(forExerciseName: exercise.name, muscleGroup: exercise.muscleGroup)
        XCTAssertNotNil(path)
        XCTAssertTrue(path?.contains("bench") == true || path?.contains("incline") == true)
    }

    func testMuscleGroupFallbackUsesGroupGif() {
        let exercise = Exercise(name: "Exercício personalizado XYZ", muscleGroup: .legs)
        let url = ExerciseGifCatalog.remoteGifURL(for: exercise)
        XCTAssertTrue(url?.absoluteString.contains("barbell-full-squat.gif") == true)
    }

    func testBundledFallbackStillAvailable() {
        let exercise = Exercise(name: "Supino Reto", muscleGroup: .chest)
        let url = ExerciseGifCatalog.bundledGifURL(for: exercise)
        XCTAssertEqual(url?.lastPathComponent, "peito.gif")
    }

    func testAbdominalBicicletaMapsToAirBikeGif() {
        let path = ExerciseGifCatalog.filePath(
            forExerciseName: "Abdominal Bicicleta",
            muscleGroup: .core
        )
        XCTAssertEqual(path, "abs/air-bike.gif")
    }

    func testPolichineloMapsToStarJumpGif() {
        let path = ExerciseGifCatalog.filePath(
            forExerciseName: "Polichinelo",
            muscleGroup: .fullBody
        )
        XCTAssertEqual(path, "cardio/star-jump-male.gif")
    }

    func testJumpingJackKeywordMapsToStarJumpGif() {
        let path = ExerciseGifCatalog.filePath(
            forExerciseName: "Jumping Jacks",
            muscleGroup: .fullBody
        )
        XCTAssertEqual(path, "cardio/star-jump-male.gif")
    }

    func testPulldownTrianguloMapsToVBarGif() {
        let path = ExerciseGifCatalog.filePath(
            forExerciseName: "Pulldown Triângulo",
            muscleGroup: .back
        )
        XCTAssertEqual(path, "lats/cable-lateral-pulldown-with-v-bar.gif")
    }

    func testPulldownTrianguloKeywordMapsToVBarGif() {
        let path = ExerciseGifCatalog.filePath(
            forExerciseName: "Puxada Triângulo na Polia",
            muscleGroup: .back
        )
        XCTAssertEqual(path, "lats/cable-lateral-pulldown-with-v-bar.gif")
    }

    func testCirculosDeBracosMapsToRoundArmGif() {
        let path = ExerciseGifCatalog.filePath(
            forExerciseName: "Círculos de Braços",
            muscleGroup: .shoulders
        )
        XCTAssertEqual(path, "delts/weighted-round-arm.gif")
    }

    func testArmCircleKeywordMapsToRoundArmGif() {
        let path = ExerciseGifCatalog.filePath(
            forExerciseName: "Arm Circles Warmup",
            muscleGroup: .shoulders
        )
        XCTAssertEqual(path, "delts/weighted-round-arm.gif")
    }

    func testAllCatalogExercisesHaveGifMapping() {
        for (name, _) in ExerciseVideoCatalog.bundledVideos() {
            let group = inferredGroup(for: name)
            let path = ExerciseGifCatalog.filePath(forExerciseName: name, muscleGroup: group)
            XCTAssertNotNil(path, "GIF ausente para \(name)")
        }
    }

    private func inferredGroup(for exerciseName: String) -> MuscleGroup {
        let normalized = exerciseName.lowercased()
        if normalized.contains("supino") || normalized.contains("crucifixo") || normalized.contains("crossover") || normalized.contains("flexão") || normalized.contains("flexao") {
            return .chest
        }
        if normalized.contains("rosca") || normalized.contains("tríceps") || normalized.contains("triceps") || normalized.contains("mergulho") {
            return .arms
        }
        if normalized.contains("remada") || normalized.contains("puxada") || normalized.contains("barra fixa") || normalized.contains("face pull") || normalized.contains("encolhimento") {
            return .back
        }
        if normalized.contains("agachamento") || normalized.contains("leg press") || normalized.contains("hack") || normalized.contains("extensora") || normalized.contains("flexora") || normalized.contains("stiff") || normalized.contains("afundo") || normalized.contains("panturrilha") {
            return .legs
        }
        if normalized.contains("desenvolvimento") || normalized.contains("elevação") || normalized.contains("elevacao") || normalized.contains("arnold") {
            return .shoulders
        }
        if normalized.contains("abdominal") || normalized.contains("prancha") || normalized.contains("mountain") || normalized.contains("russian") {
            return .core
        }
        return .fullBody
    }
}
