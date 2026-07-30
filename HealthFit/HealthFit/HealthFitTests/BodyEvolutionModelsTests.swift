import XCTest
@testable import HealthFit

final class BodyEvolutionModelsTests: XCTestCase {
    func testPhotoSetEligibilityAfter30Days() {
        let captured = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        let set = BodyPhotoSet(
            capturedAt: captured,
            photos: [
                BodyPhotoEntry(slot: .front, localFileName: "front.jpg")
            ]
        )
        XCTAssertTrue(set.isEligibleForComparison())
        XCTAssertEqual(set.daysUntilComparisonEligible(), 0)
        XCTAssertEqual(set.filledCount, 1)
        XCTAssertEqual(BodyPhotoSlot.allCases.count, 6)
    }

    func testPhotoSetNotEligibleBefore30Days() {
        let captured = Calendar.current.date(byAdding: .day, value: -10, to: .now) ?? .now
        let set = BodyPhotoSet(
            capturedAt: captured,
            photos: [
                BodyPhotoEntry(slot: .front, localFileName: "front.jpg")
            ]
        )
        XCTAssertFalse(set.isEligibleForComparison())
        XCTAssertEqual(set.daysUntilComparisonEligible(), 20)
    }

    func testEvaluationSummaryMentionsPhotoDeletionAndPDFRetention() {
        let previous = BodyMeasurements(waistCm: 80, measuredAt: .now.addingTimeInterval(-86400 * 30))
        let current = BodyMeasurements(waistCm: 77, measuredAt: .now)
        let comparison = BodyMeasurementComparison.make(previous: previous, current: current)
        let summary = BodyEvolutionEvaluation.makeSummary(
            comparison: comparison,
            photoCountPrevious: 6,
            photoCountCurrent: 6
        )
        XCTAssertTrue(summary.localizedCaseInsensitiveContains("opcional") || summary.localizedCaseInsensitiveContains("privado") || summary.contains("excluídas") || summary.contains("excluidas"))
        XCTAssertTrue(summary.contains("4"))
        XCTAssertEqual(BodyEvolutionEvaluation.maxRetainedEvaluations, 4)
    }

    func testMaxSlotsIsSix() {
        XCTAssertEqual(BodyPhotoSet().maxPhotos, 6)
        XCTAssertEqual(BodyPhotoSet.emptyEntries().count, 6)
    }
}
