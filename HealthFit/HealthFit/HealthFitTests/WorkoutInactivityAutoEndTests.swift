import XCTest
@testable import HealthFit

final class WorkoutInactivityAutoEndTests: XCTestCase {
    func testAutoEndLimitIsTwoHoursThirtyMinutes() {
        XCTAssertEqual(WorkoutStore.autoEndInactivityLimit, 2.5 * 60 * 60, accuracy: 0.1)
    }

    func testEmailReportIncludesAutoEndLines() {
        var session = TestFixtures.completedWorkoutSession(workoutTitle: "Treino Costas")
        session.endedEarly = true
        session.autoEndedByInactivity = true
        session.earlyEndJustification = WorkoutStore.autoEndJustification

        let body = WorkoutReportBuilder.emailBody(
            session: session,
            athlete: TestFixtures.userProfile(name: "Berg"),
            allSessions: [session]
        )

        XCTAssertTrue(body.contains("Automático por inatividade"))
        XCTAssertTrue(body.contains("2h30") || body.contains("esqueceu"))
        XCTAssertTrue(body.contains(WorkoutStore.autoEndJustification) || body.contains("Detalhe:"))
        XCTAssertTrue(body.contains("Encerramentos automáticos por inatividade"))
    }

    func testForgottenNotificationMentionsAthlete() {
        var session = TestFixtures.completedWorkoutSession(workoutTitle: "Cardio HIIT")
        session.autoEndedByInactivity = true
        let message = MotivationMessages.workoutEndMessage(session: session, athleteName: "Ana")

        XCTAssertTrue(message.contains("Ana"))
        XCTAssertTrue(message.contains("Cardio HIIT"))
    }

    func testAssistantOpeningIncludesMotivation() {
        let opening = MotivationMessages.forgottenWorkoutAssistantOpening(
            workoutTitle: "Treino A",
            athleteName: "Luan"
        )

        XCTAssertTrue(opening.contains("Luan"))
        XCTAssertTrue(opening.contains("Treino A"))
        XCTAssertTrue(opening.contains("2h30"))
    }
}
