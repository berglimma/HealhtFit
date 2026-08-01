import Foundation
import SwiftUI
import UIKit
import Combine

/// Payload do último card de conquista gerado para postagem (Stories / status).
struct LastWorkoutShareCard: Codable, Equatable {
    var sessionId: UUID
    var workoutSheetId: UUID
    var workoutTitle: String
    var startedAt: Date
    var endedAt: Date
    var athleteName: String
    var motivationLine: String
    var caloriesBurned: Double
    var completedExercises: Int
    var totalExercises: Int
    var averageHeartRate: Double
    var endedEarly: Bool
    var autoEndedByInactivity: Bool
    var savedAt: Date
    /// Campos de corrida (opcionais — cards antigos sem esses keys).
    var completedDistanceKm: Double?
    var averagePaceSecondsPerKm: Int?
    var stepCount: Int?
    var routePoints: [RouteCoordinate]

    var displayDate: Date { endedAt }

    init(
        sessionId: UUID,
        workoutSheetId: UUID,
        workoutTitle: String,
        startedAt: Date,
        endedAt: Date,
        athleteName: String,
        motivationLine: String,
        caloriesBurned: Double,
        completedExercises: Int,
        totalExercises: Int,
        averageHeartRate: Double,
        endedEarly: Bool,
        autoEndedByInactivity: Bool,
        savedAt: Date,
        completedDistanceKm: Double? = nil,
        averagePaceSecondsPerKm: Int? = nil,
        stepCount: Int? = nil,
        routePoints: [RouteCoordinate] = []
    ) {
        self.sessionId = sessionId
        self.workoutSheetId = workoutSheetId
        self.workoutTitle = workoutTitle
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.athleteName = athleteName
        self.motivationLine = motivationLine
        self.caloriesBurned = caloriesBurned
        self.completedExercises = completedExercises
        self.totalExercises = totalExercises
        self.averageHeartRate = averageHeartRate
        self.endedEarly = endedEarly
        self.autoEndedByInactivity = autoEndedByInactivity
        self.savedAt = savedAt
        self.completedDistanceKm = completedDistanceKm
        self.averagePaceSecondsPerKm = averagePaceSecondsPerKm
        self.stepCount = stepCount
        self.routePoints = routePoints
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decode(UUID.self, forKey: .sessionId)
        workoutSheetId = try container.decode(UUID.self, forKey: .workoutSheetId)
        workoutTitle = try container.decode(String.self, forKey: .workoutTitle)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decode(Date.self, forKey: .endedAt)
        athleteName = try container.decode(String.self, forKey: .athleteName)
        motivationLine = try container.decode(String.self, forKey: .motivationLine)
        caloriesBurned = try container.decode(Double.self, forKey: .caloriesBurned)
        completedExercises = try container.decode(Int.self, forKey: .completedExercises)
        totalExercises = try container.decode(Int.self, forKey: .totalExercises)
        averageHeartRate = try container.decode(Double.self, forKey: .averageHeartRate)
        endedEarly = try container.decode(Bool.self, forKey: .endedEarly)
        autoEndedByInactivity = try container.decode(Bool.self, forKey: .autoEndedByInactivity)
        savedAt = try container.decode(Date.self, forKey: .savedAt)
        completedDistanceKm = try container.decodeIfPresent(Double.self, forKey: .completedDistanceKm)
        averagePaceSecondsPerKm = try container.decodeIfPresent(Int.self, forKey: .averagePaceSecondsPerKm)
        stepCount = try container.decodeIfPresent(Int.self, forKey: .stepCount)
        routePoints = try container.decodeIfPresent([RouteCoordinate].self, forKey: .routePoints) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(workoutSheetId, forKey: .workoutSheetId)
        try container.encode(workoutTitle, forKey: .workoutTitle)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(endedAt, forKey: .endedAt)
        try container.encode(athleteName, forKey: .athleteName)
        try container.encode(motivationLine, forKey: .motivationLine)
        try container.encode(caloriesBurned, forKey: .caloriesBurned)
        try container.encode(completedExercises, forKey: .completedExercises)
        try container.encode(totalExercises, forKey: .totalExercises)
        try container.encode(averageHeartRate, forKey: .averageHeartRate)
        try container.encode(endedEarly, forKey: .endedEarly)
        try container.encode(autoEndedByInactivity, forKey: .autoEndedByInactivity)
        try container.encode(savedAt, forKey: .savedAt)
        try container.encodeIfPresent(completedDistanceKm, forKey: .completedDistanceKm)
        try container.encodeIfPresent(averagePaceSecondsPerKm, forKey: .averagePaceSecondsPerKm)
        try container.encodeIfPresent(stepCount, forKey: .stepCount)
        if !routePoints.isEmpty {
            try container.encode(routePoints, forKey: .routePoints)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case sessionId, workoutSheetId, workoutTitle, startedAt, endedAt
        case athleteName, motivationLine, caloriesBurned, completedExercises, totalExercises
        case averageHeartRate, endedEarly, autoEndedByInactivity, savedAt
        case completedDistanceKm, averagePaceSecondsPerKm, stepCount, routePoints
    }

    func makeSession() -> WorkoutSession {
        var session = WorkoutSession(
            id: sessionId,
            workoutSheetId: workoutSheetId,
            workoutTitle: workoutTitle,
            startedAt: startedAt,
            endedAt: endedAt,
            caloriesBurned: caloriesBurned,
            completedExercises: completedExercises,
            totalExercises: totalExercises,
            completedDistanceKm: completedDistanceKm,
            averagePaceSecondsPerKm: averagePaceSecondsPerKm,
            routePoints: routePoints,
            stepCount: stepCount,
            endedEarly: endedEarly,
            autoEndedByInactivity: autoEndedByInactivity
        )
        if averageHeartRate > 0 {
            session.heartRateSamples = [
                HeartRateSample(timestamp: endedAt, bpm: averageHeartRate)
            ]
        }
        return session
    }
}

@MainActor
final class WorkoutShareCardStore: ObservableObject {
    static let shared = WorkoutShareCardStore()

    private let payloadKey = "healthfit_last_workout_share_card"
    private let imageFileName = "last_workout_share_card.png"

    @Published private(set) var lastCard: LastWorkoutShareCard?
    @Published private(set) var previewImage: UIImage?

    private init() {
        load()
    }

    /// Persiste o card mostrado no fim do treino (metadata + imagem renderizada).
    func remember(
        session: WorkoutSession,
        athleteName: String,
        motivationLine: String,
        recentSessions: [WorkoutSession] = [],
        profileImage: UIImage? = nil
    ) {
        if lastCard?.sessionId == session.id, previewImage != nil {
            return
        }

        let endedAt = session.endedAt ?? session.startedAt
        let payload = LastWorkoutShareCard(
            sessionId: session.id,
            workoutSheetId: session.workoutSheetId,
            workoutTitle: session.workoutTitle,
            startedAt: session.startedAt,
            endedAt: endedAt,
            athleteName: athleteName,
            motivationLine: motivationLine,
            caloriesBurned: session.caloriesBurned,
            completedExercises: session.completedExercises,
            totalExercises: session.totalExercises,
            averageHeartRate: session.averageHeartRate,
            endedEarly: session.endedEarly,
            autoEndedByInactivity: session.autoEndedByInactivity,
            savedAt: .now,
            completedDistanceKm: session.completedDistanceKm,
            averagePaceSecondsPerKm: session.averagePaceSecondsPerKm,
            stepCount: session.stepCount,
            routePoints: session.routePoints
        )

        lastCard = payload
        persistPayload(payload)

        if let image = WorkoutShareCardRenderer.renderImage(
            session: session,
            athleteName: athleteName,
            motivationLine: motivationLine,
            recentSessions: recentSessions,
            profileImage: profileImage
        ) {
            previewImage = image
            saveImage(image)
        }
    }

    /// Atualiza só a imagem (ex.: após renderizar para compartilhar).
    func updatePreviewImage(_ image: UIImage) {
        previewImage = image
        saveImage(image)
    }

    func reset() {
        lastCard = nil
        previewImage = nil
        UserDefaults.standard.removeObject(forKey: payloadKey)
        if let url = imageURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: payloadKey),
           let payload = try? JSONDecoder().decode(LastWorkoutShareCard.self, from: data) {
            lastCard = payload
        }
        if let url = imageURL,
           FileManager.default.fileExists(atPath: url.path),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            previewImage = image
        }
    }

    private func persistPayload(_ payload: LastWorkoutShareCard) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: payloadKey)
    }

    private var imageURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(imageFileName)
    }

    private func saveImage(_ image: UIImage) {
        guard let url = imageURL,
              let data = image.pngData() else { return }
        try? data.write(to: url, options: .atomic)
    }
}
