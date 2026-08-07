import XCTest
@testable import HealthFit

final class WorkoutInactivityAutoEndTests: XCTestCase {
    func testAutoEndLimitIsTwoHoursThirtyMinutes() {
        XCTAssertEqual(WorkoutStore.autoEndInactivityLimit, 2.5 * 60 * 60, accuracy: 0.1)
    }

    @MainActor
    func testCalorieGoalSessionDoesNotAutoEndByInactivity() {
        let store = WorkoutStore()
        store.clearAllLocalData()
        defer { store.clearAllLocalData() }

        let walk = CardioExercise.catalog.first(where: { $0.name == "Caminhada" })
            ?? TestFixtures.runningExercise
        let config = CardioWorkoutConfig(
            exercise: walk,
            intensity: .medium,
            targetCalories: 250,
            isFreeRun: true
        )
        XCTAssertTrue(store.startCardioSession(config: config))
        guard var session = store.activeSession else {
            return XCTFail("Sessão ativa esperada")
        }
        session.startedAt = Date().addingTimeInterval(-(WorkoutStore.autoEndInactivityLimit + 60))
        store.activeSession = session

        let ended = store.autoEndStaleActiveSessionIfNeeded(
            now: .now,
            athleteName: "Teste"
        )
        XCTAssertNil(ended)
        XCTAssertNotNil(store.activeSession)
        XCTAssertEqual(store.activeSession?.targetCalories, 250)
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
            caloriesBurned: 420,
            totalExercises: 1,
            completedDistanceKm: 5.0,
            averagePaceSecondsPerKm: 360,
            targetCalories: 400,
            stepCount: 5200
        )
        session.heartRateSamples = [HeartRateSample(bpm: 148)]
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
        // Mapa primeiro, métricas abaixo do mapa.
        let mapIdx = withMap.range(of: "Mapa do percurso:")!.lowerBound
        let metricsIdx = withMap.range(of: "Métricas da sessão:")!.lowerBound
        XCTAssertTrue(mapIdx < metricsIdx)
        XCTAssertTrue(withMap.contains("Legenda:"))
        XCTAssertTrue(withMap.contains("Evolução calórica: 420 / 400 kcal"))
        XCTAssertTrue(withMap.contains("BPM: 148"))
        XCTAssertTrue(withMap.contains("Kcal: 420"))
        XCTAssertTrue(withMap.contains("Ritmo:"))
        XCTAssertTrue(withMap.contains("Passos: 5200"))
        XCTAssertTrue(withMap.contains("Km: 5.00"))
        XCTAssertTrue(withMap.contains("Tempo:"))

        let withoutMap = WorkoutReportBuilder.emailBody(
            session: session,
            athlete: TestFixtures.userProfile(name: "Berg"),
            routeMapAttachmentIncluded: false
        )
        XCTAssertTrue(withoutMap.contains("disponível no app HealthFit"))
        XCTAssertFalse(withoutMap.contains("Mapa do percurso:\nLegenda"))
        XCTAssertTrue(withoutMap.contains("Métricas da sessão:"))

        let tinyPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")!
        let html = WorkoutReportBuilder.emailHTMLBody(
            session: session,
            athlete: TestFixtures.userProfile(name: "Berg"),
            routeMapAttachmentIncluded: true,
            routeMapPNGData: tinyPNG
        )
        XCTAssertTrue(html.contains("<html>"))
        XCTAssertTrue(html.contains("Mapa do percurso"))
        XCTAssertTrue(html.contains("data:image/png;base64,"))
        XCTAssertTrue(html.contains("<img "))
        XCTAssertTrue(html.contains("Métricas da sessão"))
        XCTAssertTrue(html.contains("<strong>BPM:</strong>"))
        XCTAssertTrue(html.contains("<strong>Kcal:</strong>"))
        XCTAssertTrue(html.contains("<strong>Ritmo:</strong>"))
        XCTAssertTrue(html.contains("<strong>Passos:</strong>"))
        XCTAssertTrue(html.contains("<strong>Km:</strong>"))
        XCTAssertTrue(html.contains("<strong>Tempo:</strong>"))
    }

    func testEmailReportOutdoorWalkingAndCyclingLines() {
        var walk = WorkoutSession(
            workoutSheetId: UUID(),
            workoutTitle: "Cardio — Caminhada",
            startedAt: Date(timeIntervalSince1970: 0),
            endedAt: Date(timeIntervalSince1970: 2400),
            caloriesBurned: 180,
            totalExercises: 1,
            completedDistanceKm: 3.2,
            averagePaceSecondsPerKm: 500,
            stepCount: 4100
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
        XCTAssertTrue(walkBody.contains("Mapa do percurso:"))
        XCTAssertTrue(walkBody.contains("Km: 3.20"))
        XCTAssertTrue(walkBody.contains("Passos: 4100"))
        XCTAssertTrue(walkBody.contains("Ritmo:"))

        var bike = WorkoutSession(
            workoutSheetId: UUID(),
            workoutTitle: "Cardio — Mountain bike",
            startedAt: Date(timeIntervalSince1970: 0),
            endedAt: Date(timeIntervalSince1970: 3600),
            caloriesBurned: 650,
            totalExercises: 1,
            completedDistanceKm: 20.0
        )
        bike.routePoints = walk.routePoints
        let bikeBody = WorkoutReportBuilder.emailBody(
            session: bike,
            athlete: TestFixtures.userProfile(name: "Ana"),
            routeMapAttachmentIncluded: true
        )
        XCTAssertTrue(bikeBody.contains("Ritmo:"))
        XCTAssertTrue(bikeBody.contains("km/h"))
        XCTAssertTrue(bikeBody.contains("Mapa do percurso:"))
        XCTAssertTrue(bikeBody.contains("Km: 20.00"))
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
