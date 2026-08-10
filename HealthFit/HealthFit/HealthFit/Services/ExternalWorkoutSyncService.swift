import Combine
import Foundation
import HealthKit

/// Observa treinos do Apple Fitness / outros apps no Saúde, importa no histórico e avisa o IAssistente.
@MainActor
final class ExternalWorkoutSyncService: ObservableObject {
    static let shared = ExternalWorkoutSyncService()

    @Published private(set) var lastImportedCount = 0
    @Published private(set) var pendingAssistantMessage: String?

    private weak var workoutStore: WorkoutStore?
    private var athleteName: String = "Atleta"
    private var isSyncing = false
    private var didBindObserver = false

    private let processedKey = "healthfit.externalWorkouts.processedUUIDs"
    private let pendingMessageKey = "healthfit.externalWorkouts.pendingAssistantMessage"
    private let lookbackDays = 7
    /// Só notifica treinos encerrados recentemente (evita spam no 1º sync).
    private let notifyWindowHours: Double = 6

    private init() {
        pendingAssistantMessage = UserDefaults.standard.string(forKey: pendingMessageKey)
    }

    func bind(workoutStore: WorkoutStore?, athleteName: String? = nil) {
        self.workoutStore = workoutStore
        if let athleteName {
            let trimmed = athleteName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { self.athleteName = trimmed }
        }
        guard workoutStore != nil else { return }
        guard !didBindObserver else { return }
        didBindObserver = true
        HealthKitManager.shared.onExternalWorkoutsChanged = { [weak self] in
            Task { @MainActor in
                await self?.syncRecentExternalWorkouts(reason: .observer)
            }
        }
    }

    func consumePendingAssistantMessage() -> String? {
        let message = pendingAssistantMessage
        pendingAssistantMessage = nil
        UserDefaults.standard.removeObject(forKey: pendingMessageKey)
        return message
    }

    func clearAllLocalData() {
        pendingAssistantMessage = nil
        UserDefaults.standard.removeObject(forKey: pendingMessageKey)
        UserDefaults.standard.removeObject(forKey: processedKey)
        lastImportedCount = 0
    }

    enum SyncReason {
        case startup
        case foreground
        case observer
        case manual
    }

    @discardableResult
    func syncRecentExternalWorkouts(reason: SyncReason) async -> Int {
        guard !isSyncing, let store = workoutStore else { return 0 }
        isSyncing = true
        defer { isSyncing = false }

        let calendar = Calendar.current
        guard let since = calendar.date(byAdding: .day, value: -lookbackDays, to: .now) else { return 0 }

        let samples = await HealthKitManager.shared.fetchExternalWorkouts(since: since)
        guard !samples.isEmpty else { return 0 }

        var processed = loadProcessedUUIDs()
        var imported = 0
        var newestForNotify: HealthKitManager.ExternalWorkoutSample?

        for sample in samples {
            let uuidString = sample.healthKitUUID.uuidString
            if processed.contains(uuidString) { continue }
            if store.sessionHistory.contains(where: { $0.healthKitUUID == sample.healthKitUUID }) {
                processed.insert(uuidString)
                continue
            }

            let session = ExternalWorkoutAssistantEngine.makeSession(from: sample)
            guard store.importExternalCompletedSession(session) else {
                processed.insert(uuidString)
                continue
            }

            processed.insert(uuidString)
            imported += 1

            let hoursSinceEnd = Date().timeIntervalSince(sample.endedAt) / 3600
            if hoursSinceEnd <= notifyWindowHours {
                if newestForNotify == nil || sample.endedAt > newestForNotify!.endedAt {
                    newestForNotify = sample
                }
            }
        }

        saveProcessedUUIDs(processed)
        lastImportedCount = imported

        if let sample = newestForNotify {
            notifyAssistant(about: sample)
        }

        return imported
    }

    private func notifyAssistant(about sample: HealthKitManager.ExternalWorkoutSample) {
        let activity = ExternalWorkoutAssistantEngine.activityDisplayName(for: sample.activityType)
        let minutes = max(1, Int((sample.durationSeconds / 60).rounded()))
        let calories = Int(sample.calories.rounded())

        let fullMessage = ExternalWorkoutAssistantEngine.assistantMessage(
            athleteName: athleteName,
            activityName: activity,
            sourceName: sample.sourceName,
            durationMinutes: minutes,
            calories: calories
        )
        pendingAssistantMessage = fullMessage
        UserDefaults.standard.set(fullMessage, forKey: pendingMessageKey)

        PostWorkoutCheckInService.shared.notifyAssistantMessagePending()
        NotificationService.shared.deliverAssistantMessageNotification(
            body: ExternalWorkoutAssistantEngine.notificationBody(
                activityName: activity,
                sourceName: sample.sourceName
            )
        )
    }

    private func loadProcessedUUIDs() -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: processedKey) ?? []
        return Set(array)
    }

    private func saveProcessedUUIDs(_ set: Set<String>) {
        // Mantém só os mais recentes para não crescer sem limite.
        let trimmed = Array(set).suffix(200)
        UserDefaults.standard.set(Array(trimmed), forKey: processedKey)
    }
}
