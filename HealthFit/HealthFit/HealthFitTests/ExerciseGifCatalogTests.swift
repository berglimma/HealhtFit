import XCTest
@testable import HealthFit

final class ExerciseGifCatalogTests: XCTestCase {
    func testExactMatchForBenchPressGif() {
        let exercise = Exercise(name: "Supino Reto", muscleGroup: .chest)
        let url = ExerciseGifCatalog.gifURL(for: exercise)
        XCTAssertEqual(url?.absoluteString, "https://static.exercisedb.dev/media/EIeI8Vf.gif")
    }

    func testKeywordFallbackForCustomExerciseName() {
        let exercise = Exercise(name: "Supino com halteres inclinado", muscleGroup: .chest)
        let mediaId = ExerciseGifCatalog.mediaId(forExerciseName: exercise.name, muscleGroup: exercise.muscleGroup)
        XCTAssertEqual(mediaId, "EIeI8Vf")
    }

    func testMuscleGroupFallbackUsesGroupGif() {
        let exercise = Exercise(name: "Exercício personalizado XYZ", muscleGroup: .legs)
        let url = ExerciseGifCatalog.gifURL(for: exercise)
        XCTAssertEqual(url?.absoluteString, "https://static.exercisedb.dev/media/qXTaZnJ.gif")
    }

    func testAllCatalogExercisesHaveGifMapping() {
        for (name, _) in ExerciseVideoCatalog.bundledVideos() {
            let group = inferredGroup(for: name)
            let mediaId = ExerciseGifCatalog.mediaId(forExerciseName: name, muscleGroup: group)
            XCTAssertNotNil(mediaId, "GIF ausente para \(name)")
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
