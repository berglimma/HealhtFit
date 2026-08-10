import Foundation
import SwiftUI
import UIKit
import Combine

/// Payload do card de conquista gerado para postagem (Stories / status).
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
    /// Presente quando o treino contou para dupla/equipe.
    var duoTeamId: String?
    var duoTeamName: String?

    var displayDate: Date { endedAt }

    var isDuoTeamCard: Bool {
        guard let duoTeamId, !duoTeamId.isEmpty else { return false }
        return true
    }

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
        routePoints: [RouteCoordinate] = [],
        duoTeamId: String? = nil,
        duoTeamName: String? = nil
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
        self.duoTeamId = duoTeamId
        self.duoTeamName = duoTeamName
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
        duoTeamId = try container.decodeIfPresent(String.self, forKey: .duoTeamId)
        duoTeamName = try container.decodeIfPresent(String.self, forKey: .duoTeamName)
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
        try container.encodeIfPresent(duoTeamId, forKey: .duoTeamId)
        try container.encodeIfPresent(duoTeamName, forKey: .duoTeamName)
    }

    private enum CodingKeys: String, CodingKey {
        case sessionId, workoutSheetId, workoutTitle, startedAt, endedAt
        case athleteName, motivationLine, caloriesBurned, completedExercises, totalExercises
        case averageHeartRate, endedEarly, autoEndedByInactivity, savedAt
        case completedDistanceKm, averagePaceSecondsPerKm, stepCount, routePoints
        case duoTeamId, duoTeamName
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
            autoEndedByInactivity: autoEndedByInactivity,
            duoTeamId: duoTeamId,
            duoTeamName: duoTeamName
        )
        if averageHeartRate > 0 {
            session.heartRateSamples = [
                HeartRateSample(timestamp: endedAt, bpm: averageHeartRate)
            ]
        }
        return session
    }
}

enum WorkoutShareCardSlot: String, CaseIterable, Identifiable {
    case individual
    case duoTeam

    var id: String { rawValue }

    var payloadKey: String {
        switch self {
        case .individual: return "healthfit_last_workout_share_card"
        case .duoTeam: return "healthfit_last_duo_workout_share_card"
        }
    }

    var imageFileName: String {
        switch self {
        case .individual: return "last_workout_share_card.png"
        case .duoTeam: return "last_duo_workout_share_card.png"
        }
    }

    var sectionTitle: String {
        switch self {
        case .individual: return "Último card individual"
        case .duoTeam: return "Último card em grupo"
        }
    }

    var emptyHint: String {
        switch self {
        case .individual:
            return "Nenhum card gerado ainda. Finalize um treino individual para criar o card de postagem."
        case .duoTeam:
            return "Nenhum card de grupo ainda. Ative o modo equipe e finalize um treino para postar."
        }
    }
}

@MainActor
final class WorkoutShareCardStore: ObservableObject {
    static let shared = WorkoutShareCardStore()

    @Published private(set) var lastIndividualCard: LastWorkoutShareCard?
    @Published private(set) var lastDuoCard: LastWorkoutShareCard?
    @Published private(set) var individualPreviewImage: UIImage?
    @Published private(set) var duoPreviewImage: UIImage?

    /// Compat: aponta para o card individual (usos antigos / resumo).
    var lastCard: LastWorkoutShareCard? { lastIndividualCard }
    var previewImage: UIImage? { individualPreviewImage }

    private init() {
        load()
    }

    func card(for slot: WorkoutShareCardSlot) -> LastWorkoutShareCard? {
        switch slot {
        case .individual: return lastIndividualCard
        case .duoTeam: return lastDuoCard
        }
    }

    func previewImage(for slot: WorkoutShareCardSlot) -> UIImage? {
        switch slot {
        case .individual: return individualPreviewImage
        case .duoTeam: return duoPreviewImage
        }
    }

    /// Persiste o card mostrado no fim do treino (metadata + imagem renderizada).
    /// Treinos com `duoTeamId` vão para o slot de grupo; os demais, para o individual.
    func remember(
        session: WorkoutSession,
        athleteName: String,
        motivationLine: String,
        recentSessions: [WorkoutSession] = [],
        profileImage: UIImage? = nil
    ) {
        let slot: WorkoutShareCardSlot = session.isDuoTeamSession ? .duoTeam : .individual
        if card(for: slot)?.sessionId == session.id, previewImage(for: slot) != nil {
            return
        }

        let endedAt = session.endedAt ?? session.startedAt
        let duoLine: String = {
            guard session.isDuoTeamSession else { return motivationLine }
            let team = session.duoTeamName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if team.isEmpty {
                return motivationLine.isEmpty
                    ? "Treino em dupla/equipe no HealthFit."
                    : "\(motivationLine) · Treino em grupo"
            }
            if motivationLine.isEmpty {
                return "Treino com a equipe “\(team)”."
            }
            return "\(motivationLine) · Equipe “\(team)”"
        }()

        let payload = LastWorkoutShareCard(
            sessionId: session.id,
            workoutSheetId: session.workoutSheetId,
            workoutTitle: session.workoutTitle,
            startedAt: session.startedAt,
            endedAt: endedAt,
            athleteName: athleteName,
            motivationLine: duoLine,
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
            routePoints: session.routePoints,
            duoTeamId: session.duoTeamId,
            duoTeamName: session.duoTeamName
        )

        setCard(payload, slot: slot)
        persistPayload(payload, slot: slot)

        if let image = WorkoutShareCardRenderer.renderImage(
            session: session,
            athleteName: athleteName,
            motivationLine: duoLine,
            recentSessions: recentSessions,
            profileImage: profileImage
        ) {
            setPreviewImage(image, slot: slot)
            saveImage(image, slot: slot)
        }
    }

    /// Atualiza só a imagem do slot individual (compat).
    func updatePreviewImage(_ image: UIImage) {
        updatePreviewImage(image, slot: .individual)
    }

    func updatePreviewImage(_ image: UIImage, slot: WorkoutShareCardSlot) {
        setPreviewImage(image, slot: slot)
        saveImage(image, slot: slot)
    }

    func reset() {
        lastIndividualCard = nil
        lastDuoCard = nil
        individualPreviewImage = nil
        duoPreviewImage = nil
        for slot in WorkoutShareCardSlot.allCases {
            UserDefaults.standard.removeObject(forKey: slot.payloadKey)
            if let url = imageURL(for: slot) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private func setCard(_ payload: LastWorkoutShareCard, slot: WorkoutShareCardSlot) {
        switch slot {
        case .individual: lastIndividualCard = payload
        case .duoTeam: lastDuoCard = payload
        }
    }

    private func setPreviewImage(_ image: UIImage?, slot: WorkoutShareCardSlot) {
        switch slot {
        case .individual: individualPreviewImage = image
        case .duoTeam: duoPreviewImage = image
        }
    }

    private func load() {
        for slot in WorkoutShareCardSlot.allCases {
            if let data = UserDefaults.standard.data(forKey: slot.payloadKey),
               let payload = try? JSONDecoder().decode(LastWorkoutShareCard.self, from: data) {
                // Migração: card antigo com duo no slot individual → move para duo.
                if slot == .individual, payload.isDuoTeamCard {
                    setCard(payload, slot: .duoTeam)
                    persistPayload(payload, slot: .duoTeam)
                    UserDefaults.standard.removeObject(forKey: slot.payloadKey)
                } else {
                    setCard(payload, slot: slot)
                }
            }
            if let url = imageURL(for: slot),
               FileManager.default.fileExists(atPath: url.path),
               let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                // Se o payload foi migrado, a imagem antiga individual pode ser a do duo.
                if slot == .individual, lastIndividualCard == nil, lastDuoCard != nil, duoPreviewImage == nil {
                    setPreviewImage(image, slot: .duoTeam)
                    saveImage(image, slot: .duoTeam)
                    try? FileManager.default.removeItem(at: url)
                } else {
                    setPreviewImage(image, slot: slot)
                }
            }
        }
    }

    private func persistPayload(_ payload: LastWorkoutShareCard, slot: WorkoutShareCardSlot) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: slot.payloadKey)
    }

    private func imageURL(for slot: WorkoutShareCardSlot) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(slot.imageFileName)
    }

    private func saveImage(_ image: UIImage, slot: WorkoutShareCardSlot) {
        guard let url = imageURL(for: slot),
              let data = image.pngData() else { return }
        try? data.write(to: url, options: .atomic)
    }
}
