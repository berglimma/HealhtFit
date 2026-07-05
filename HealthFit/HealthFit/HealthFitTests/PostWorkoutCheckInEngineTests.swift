import XCTest
@testable import HealthFit

final class PostWorkoutCheckInEngineTests: XCTestCase {
    func testIsDueAfterNinetyMinutes() {
        let session = TestFixtures.completedWorkoutSession(endedAt: Date().addingTimeInterval(-91 * 60))
        let checkIn = PendingPostWorkoutCheckIn(session: session)

        XCTAssertTrue(PostWorkoutCheckInEngine.isDue(checkIn))
    }

    func testIsNotDueBeforeNinetyMinutes() {
        let session = TestFixtures.completedWorkoutSession(endedAt: Date().addingTimeInterval(-30 * 60))
        let checkIn = PendingPostWorkoutCheckIn(session: session)

        XCTAssertFalse(PostWorkoutCheckInEngine.isDue(checkIn))
    }

    func testClassifiesPositiveFeelings() {
        XCTAssertEqual(PostWorkoutCheckInEngine.classifyFeeling("Estou ótimo!"), .great)
        XCTAssertEqual(PostWorkoutCheckInEngine.classifyFeeling("Me sinto bem"), .good)
    }

    func testClassifiesNegativeFeelings() {
        XCTAssertEqual(PostWorkoutCheckInEngine.classifyFeeling("Estou cansado"), .tired)
        XCTAssertEqual(PostWorkoutCheckInEngine.classifyFeeling("Estou com dores no joelho"), .sore)
    }

    func testOpeningMessageMentionsWorkoutTitle() {
        let session = TestFixtures.completedWorkoutSession(workoutTitle: "Treino A — Peito")
        let checkIn = PendingPostWorkoutCheckIn(session: session)
        let message = PostWorkoutCheckInEngine.openingMessage(checkIn: checkIn, athleteName: "João")

        XCTAssertTrue(message.contains("90 minutos"))
        XCTAssertTrue(message.contains("Treino A — Peito"))
        XCTAssertTrue(message.contains("João"))
    }

    func testResponseSequenceReturnsThreeMessages() {
        let session = TestFixtures.completedWorkoutSession(workoutTitle: "Cardio leve")
        let checkIn = PendingPostWorkoutCheckIn(session: session)
        let responses = PostWorkoutCheckInEngine.responseSequence(
            feeling: .good,
            checkIn: checkIn,
            athleteName: "Maria"
        )

        XCTAssertEqual(responses.count, 3)
        XCTAssertTrue(responses[0].contains("Maria"))
        XCTAssertTrue(responses[2].localizedCaseInsensitiveContains("treino"))
    }

    func testStrengthWorkoutKindDetection() {
        let session = TestFixtures.completedWorkoutSession(workoutTitle: "Treino B")
        let checkIn = PendingPostWorkoutCheckIn(session: session)
        XCTAssertEqual(checkIn.workoutKind, .strength)
    }

    func testCardioWorkoutKindDetection() {
        var session = TestFixtures.completedWorkoutSession(workoutTitle: "Corrida")
        session.cardioIntensityLabel = "Moderado"
        let checkIn = PendingPostWorkoutCheckIn(session: session)
        XCTAssertEqual(checkIn.workoutKind, .cardio)
    }

    func testPositiveFarewellPraisesUser() {
        let session = TestFixtures.completedWorkoutSession()
        let checkIn = PendingPostWorkoutCheckIn(session: session)
        let responses = PostWorkoutCheckInEngine.responseSequence(
            feeling: .great,
            checkIn: checkIn,
            athleteName: "Ana"
        )

        XCTAssertTrue(responses[2].localizedCaseInsensitiveContains("evoluindo"))
    }

    func testNegativeFarewellAlertsRecovery() {
        let session = TestFixtures.completedWorkoutSession()
        let checkIn = PendingPostWorkoutCheckIn(session: session)
        let responses = PostWorkoutCheckInEngine.responseSequence(
            feeling: .sore,
            checkIn: checkIn,
            athleteName: "Ana"
        )

        XCTAssertTrue(responses[2].localizedCaseInsensitiveContains("Cuide-se"))
    }
}
