import HealthKit
import XCTest
@testable import HealthFit

final class ExternalWorkoutAssistantEngineTests: XCTestCase {
    func testCardioTitleUsesCardioPrefix() {
        let title = ExternalWorkoutAssistantEngine.sessionTitle(
            activityType: .running,
            sourceName: "Fitness"
        )
        XCTAssertTrue(title.lowercased().hasPrefix("cardio"))
        XCTAssertTrue(title.contains("Corrida"))
        XCTAssertTrue(title.contains("Fitness"))
    }

    func testStrengthTitleWithoutCardioPrefix() {
        let title = ExternalWorkoutAssistantEngine.sessionTitle(
            activityType: .traditionalStrengthTraining,
            sourceName: "Fitness"
        )
        XCTAssertFalse(title.lowercased().hasPrefix("cardio"))
        XCTAssertTrue(title.contains("Musculação"))
    }

    func testMakeSessionMapsSample() {
        let sample = HealthKitManager.ExternalWorkoutSample(
            healthKitUUID: UUID(),
            startedAt: Date().addingTimeInterval(-1800),
            endedAt: Date(),
            durationSeconds: 1800,
            calories: 320,
            averageHeartRate: 142,
            activityType: .cycling,
            sourceName: "Fitness",
            sourceBundleId: "com.apple.Fitness"
        )
        let session = ExternalWorkoutAssistantEngine.makeSession(from: sample)
        XCTAssertEqual(session.source, .appleHealthExternal)
        XCTAssertEqual(session.healthKitUUID, sample.healthKitUUID)
        XCTAssertEqual(session.caloriesBurned, 320, accuracy: 0.1)
        XCTAssertNotNil(session.endedAt)
        XCTAssertTrue(WeeklyProgressAnalyzer.isCardioSession(session))
    }

    func testAssistantMessageMentionsOtherAppAndHealthFit() {
        let text = ExternalWorkoutAssistantEngine.assistantMessage(
            athleteName: "Luan",
            activityName: "Corrida",
            sourceName: "Fitness",
            durationMinutes: 40,
            calories: 400
        )
        XCTAssertTrue(text.contains("outro app"))
        XCTAssertTrue(text.contains("Fitness"))
        XCTAssertTrue(text.contains("HealthFit"))
        XCTAssertTrue(text.contains("Luan"))
    }

    func testImportedSessionCountsInWeeklyFilter() {
        let session = WorkoutSession(
            workoutSheetId: ExternalWorkoutAssistantEngine.externalSheetId,
            workoutTitle: "Cardio — Corrida (Fitness)",
            startedAt: Date().addingTimeInterval(-3600),
            endedAt: Date(),
            caloriesBurned: 280,
            completedExercises: 1,
            totalExercises: 1,
            source: .appleHealthExternal,
            healthKitUUID: UUID(),
            externalSourceName: "Fitness"
        )
        XCTAssertTrue(session.isExternalHealthKitSession)
        XCTAssertTrue(WeeklyProgressAnalyzer.isCardioSession(session))
    }
}
