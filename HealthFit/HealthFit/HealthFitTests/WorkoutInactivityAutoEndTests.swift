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

    func testEmailReportIncludesOutdoorRouteMapWhenAttached() {
        var session = WorkoutSession(
            workoutSheetId: UUID(),
            workoutTitle: "Cardio — Corrida livre",
            startedAt: Date(timeIntervalSince1970: 0),
            endedAt: Date(timeIntervalSince1970: 1800),
            totalExercises: 1,
            completedDistanceKm: 5.0,
            averagePaceSecondsPerKm: 360
        )
        session.routePoints = [
            RouteCoordinate(latitude: -23.55, longitude: -46.63, timestamp: Date(timeIntervalSince1970: 0)),
            RouteCoordinate(latitude: -23.551, longitude: -46.631, timestamp: Date(timeIntervalSince1970: 60)),
            RouteCoordinate(latitude: -23.552, longitude: -46.632, timestamp: Date(timeIntervalSince1970: 120))
        ]

        XCTAssertTrue(WorkoutReportBuilder.hasRouteMapForEmail(session))

        let withMap = WorkoutReportBuilder.emailBody(
            session: session,
            athlete: TestFixtures.userProfile(name: "Berg"),
            routeMapAttachmentIncluded: true
        )
        XCTAssertTrue(withMap.contains("Distância: 5.00 km"))
        XCTAssertTrue(withMap.contains("Ritmo médio:"))
        XCTAssertTrue(withMap.contains("Mapa do percurso em anexo"))
        XCTAssertTrue(withMap.contains("rota-treino.png"))

        let withoutMap = WorkoutReportBuilder.emailBody(
            session: session,
            athlete: TestFixtures.userProfile(name: "Berg"),
            routeMapAttachmentIncluded: false
        )
        XCTAssertTrue(withoutMap.contains("disponível no app HealthFit"))
        XCTAssertFalse(withoutMap.contains("em anexo"))

        let html = WorkoutReportBuilder.emailHTMLBody(
            session: session,
            athlete: TestFixtures.userProfile(name: "Berg"),
            routeMapAttachmentIncluded: true
        )
        XCTAssertTrue(html.contains("<html>"))
        XCTAssertTrue(html.contains("Mapa do percurso em anexo"))
    }

    func testEmailReportOutdoorWalkingAndCyclingLines() {
        var walk = WorkoutSession(
            workoutSheetId: UUID(),
            workoutTitle: "Cardio — Caminhada",
            startedAt: Date(timeIntervalSince1970: 0),
            endedAt: Date(timeIntervalSince1970: 2400),
            totalExercises: 1,
            completedDistanceKm: 3.2,
            averagePaceSecondsPerKm: 500
        )
        walk.routePoints = [
            RouteCoordinate(latitude: -23.55, longitude: -46.63),
            RouteCoordinate(latitude: -23.553, longitude: -46.635)
        ]
        XCTAssertTrue(walk.isOutdoorGPSCardio)
        XCTAssertTrue(walk.isOutdoorWalkingSession)

        let walkBody = WorkoutReportBuilder.emailBody(
            session: walk,
            athlete: TestFixtures.userProfile(name: "Ana"),
            routeMapAttachmentIncluded: true
        )
        XCTAssertTrue(walkBody.contains("Distância: 3.20 km"))
        XCTAssertTrue(walkBody.contains("Mapa do percurso em anexo"))

        var bike = WorkoutSession(
            workoutSheetId: UUID(),
            workoutTitle: "Cardio — Mountain bike",
            startedAt: Date(timeIntervalSince1970: 0),
            endedAt: Date(timeIntervalSince1970: 3600),
            totalExercises: 1,
            completedDistanceKm: 20.0
        )
        bike.routePoints = walk.routePoints
        let bikeBody = WorkoutReportBuilder.emailBody(
            session: bike,
            athlete: TestFixtures.userProfile(name: "Ana"),
            routeMapAttachmentIncluded: true
        )
        XCTAssertTrue(bikeBody.contains("Velocidade média:"))
        XCTAssertTrue(bikeBody.contains("Mapa do percurso em anexo"))
    }

    func testStrengthEmailDoesNotIncludeRouteMapLines() {
        let session = TestFixtures.completedWorkoutSession(workoutTitle: "Treino Peito")
        let body = WorkoutReportBuilder.emailBody(
            session: session,
            athlete: TestFixtures.userProfile(name: "Berg")
        )
        XCTAssertFalse(body.contains("Mapa do percurso"))
        XCTAssertFalse(body.contains("rota-treino"))
        XCTAssertTrue(body.contains("Exercícios concluídos:"))
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
