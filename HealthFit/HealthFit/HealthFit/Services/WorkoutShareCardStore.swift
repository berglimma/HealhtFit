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

    var displayDate: Date { endedAt }

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
        motivationLine: String
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
            savedAt: .now
        )

        lastCard = payload
        persistPayload(payload)

        if let image = WorkoutShareCardRenderer.renderImage(
            session: session,
            athleteName: athleteName,
            motivationLine: motivationLine
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
