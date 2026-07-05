import XCTest
@testable import HealthFit

final class ExerciseVideoCatalogTests: XCTestCase {
    func testExactMatchForBenchPress() {
        let exercise = Exercise(name: "Supino Reto", muscleGroup: .chest)
        let video = ExerciseVideoCatalog.localVideo(for: exercise)
        XCTAssertEqual(video?.exerciseName, "Supino Reto")
        XCTAssertTrue(video?.storagePath.contains("supino_reto") ?? false)
    }

    func testKeywordFallbackForCustomExerciseName() {
        let exercise = Exercise(name: "Supino com halteres inclinado", muscleGroup: .chest)
        let video = ExerciseVideoCatalog.localVideo(for: exercise)
        XCTAssertNotNil(video)
        XCTAssertTrue(video?.storagePath.hasPrefix("exerciseVideos/") ?? false)
    }

    func testMuscleGroupFallbackUsesGroupStoragePath() {
        let exercise = Exercise(name: "Exercício personalizado XYZ", muscleGroup: .legs)
        let video = ExerciseVideoCatalog.localVideo(for: exercise)
        XCTAssertEqual(video?.storagePath, "exerciseVideos/groups/pernas.mp4")
    }

    func testGroupStoragePaths() {
        XCTAssertEqual(ExerciseVideoStorageService.groupStoragePath(for: .chest), "exerciseVideos/groups/peito.mp4")
        XCTAssertEqual(ExerciseVideoStorageService.groupStoragePath(for: .legs), "exerciseVideos/groups/pernas.mp4")
    }
}
