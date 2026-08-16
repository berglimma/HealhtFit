import Foundation
import Combine
import UIKit
import AudioToolbox

@MainActor
final class RestTimerService: ObservableObject {
    @Published var isRunning = false
    @Published var remainingSeconds: Int = 60
    @Published var configuredRestSeconds: Int = 60
    @Published var maxRestSeconds: Int = 120
    @Published var notificationEnabled = true
    /// Quando true, o descanso acabou e o usuário precisa confirmar com "OK vamos lá".
    @Published var isAwaitingResumeAcknowledgment = false
    var onRestOvertime: ((String) -> Void)?

    @Published private(set) var restByExerciseId: [UUID: Int] = [:]
    @Published private(set) var totalRestSeconds: Int = 0
    @Published private(set) var currentExerciseName = ""

    private var timer: Timer?
    private var restStartedAt: Date?
    private var restEndsAt: Date?
    private var currentRestExerciseId: UUID?
    private var hasSignaledRestComplete = false
    private var reminderSoundTimer: Timer?
    private var reminderSoundPlayCount = 0
    private static let maxReminderSoundPlays = 4
    /// Duração efetiva desta pausa (pode diferir do padrão se o usuário ajustou no cronômetro).
    private var activeRestDurationSeconds = 60
    /// Descanso já acumulado por exercício antes desta pausa (para catch-up em background).
    private var restAccumulatedBeforeCurrentPause: [UUID: Int] = [:]

    private let restSecondsKey = "healthfit_rest_seconds"
    private let maxRestKey = "healthfit_max_rest_seconds"
    private let notificationsKey = "healthfit_rest_notifications"
    private let restStateKey = "healthfit_active_rest_state"

    init() {
        let savedRest = UserDefaults.standard.object(forKey: restSecondsKey) as? Int ?? 60
        let savedMax = UserDefaults.standard.object(forKey: maxRestKey) as? Int ?? 120
        configuredRestSeconds = Self.clampRest(savedRest)
        maxRestSeconds = max(configuredRestSeconds, savedMax)
        remainingSeconds = configuredRestSeconds
        activeRestDurationSeconds = configuredRestSeconds
        if UserDefaults.standard.object(forKey: notificationsKey) != nil {
            notificationEnabled = UserDefaults.standard.bool(forKey: notificationsKey)
        }
        restorePersistedRestStateIfNeeded()
        startDisplayTimerIfNeeded()
    }

    /// Fim da pausa atual (para Live Activity / tela bloqueada).
    var restEndDate: Date? { restEndsAt }

    /// Início da pausa atual.
    var restStartDate: Date? { restStartedAt }

    func resetSessionTracking() {
        // Não apaga pausa em andamento (ex.: retorno após fechar o app).
        guard !isRunning, !isAwaitingResumeAcknowledgment else { return }
        restByExerciseId = [:]
        totalRestSeconds = 0
        currentRestExerciseId = nil
        restAccumulatedBeforeCurrentPause = [:]
    }

    func configure(restSeconds: Int, maxRest: Int, notifications: Bool) {
        configuredRestSeconds = Self.clampRest(restSeconds)
        maxRestSeconds = max(configuredRestSeconds, maxRest)
        notificationEnabled = notifications
        persistConfiguration()
        applyConfiguredDurationToActiveRestIfNeeded()
        if !isRunning {
            remainingSeconds = configuredRestSeconds
            activeRestDurationSeconds = configuredRestSeconds
        }
        CrossDeviceSyncCoordinator.pushPreferencesNow(timerService: self)
    }

    /// Aplica preferências vindas do Firestore sem reenviar imediatamente.
    func applyCloudConfiguration(restSeconds: Int, maxRest: Int, notifications: Bool) {
        configuredRestSeconds = Self.clampRest(restSeconds)
        maxRestSeconds = max(configuredRestSeconds, maxRest)
        notificationEnabled = notifications
        UserDefaults.standard.set(configuredRestSeconds, forKey: restSecondsKey)
        UserDefaults.standard.set(maxRestSeconds, forKey: maxRestKey)
        UserDefaults.standard.set(notificationEnabled, forKey: notificationsKey)
        if !isRunning {
            remainingSeconds = configuredRestSeconds
            activeRestDurationSeconds = configuredRestSeconds
        }
    }

    /// Ajusta o tempo padrão e, se a pausa estiver rodando, reaplica no cronômetro/notificação.
    func adjustConfiguredRestSeconds(by delta: Int) {
        let next = Self.clampRest(configuredRestSeconds + delta)
        configure(
            restSeconds: next,
            maxRest: max(maxRestSeconds, next),
            notifications: notificationEnabled
        )
    }

    private func persistConfiguration() {
        UserDefaults.standard.set(configuredRestSeconds, forKey: restSecondsKey)
        UserDefaults.standard.set(maxRestSeconds, forKey: maxRestKey)
        UserDefaults.standard.set(notificationEnabled, forKey: notificationsKey)
    }

    func startRest(for exerciseName: String, exerciseId: UUID) {
        timer?.invalidate()
        timer = nil
        stopReminderSoundLoop()
        NotificationService.shared.cancelRestReminders()
        hasSignaledRestComplete = false
        isAwaitingResumeAcknowledgment = false

        currentExerciseName = exerciseName
        currentRestExerciseId = exerciseId
        activeRestDurationSeconds = configuredRestSeconds
        remainingSeconds = activeRestDurationSeconds
        let now = Date()
        restStartedAt = now
        restEndsAt = now.addingTimeInterval(TimeInterval(activeRestDurationSeconds))
        restAccumulatedBeforeCurrentPause[exerciseId] = restByExerciseId[exerciseId, default: 0]
        isRunning = true

        scheduleEndNotificationIfNeeded(after: activeRestDurationSeconds)
        persistRestState()
        startDisplayTimerIfNeeded()
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        stopReminderSoundLoop()
        isRunning = false
        isAwaitingResumeAcknowledgment = false
        currentRestExerciseId = nil
        hasSignaledRestComplete = false
        restStartedAt = nil
        restEndsAt = nil
        NotificationService.shared.cancelRestReminders()
        clearPersistedRestState()
    }

    /// Confirma o fim do descanso e retoma o treino.
    func acknowledgeRestAndResume() {
        stopReminderSoundLoop()
        isAwaitingResumeAcknowledgment = false
        stopTimer()
    }

    func reset() {
        stopTimer()
        remainingSeconds = configuredRestSeconds
        activeRestDurationSeconds = configuredRestSeconds
    }

    /// Recalcula com base no relógio do sistema (segundo plano / app reaberto).
    func handleAppBecameActive() {
        syncFromWallClock(announceCompletion: true)
        startDisplayTimerIfNeeded()
    }

    func handleAppEnteredBackground() {
        syncFromWallClock(announceCompletion: false)
        persistRestState()
        // Sem UI: para som/vibração e timer de display; a notificação local cobre o aviso.
        stopReminderSoundLoop()
        stopDisplayTimer()
    }

    private func stopDisplayTimer() {
        timer?.invalidate()
        timer = nil
    }

    var progress: Double {
        progress(at: Date())
    }

    func progress(at date: Date) -> Double {
        guard activeRestDurationSeconds > 0 else { return 0 }
        let remaining: Int
        if let endsAt = restEndsAt {
            remaining = max(0, Int(ceil(endsAt.timeIntervalSince(date))))
        } else {
            remaining = remainingSeconds
        }
        return 1.0 - (Double(remaining) / Double(activeRestDurationSeconds))
    }

    var isOvertime: Bool {
        isOvertime(at: Date())
    }

    func isOvertime(at date: Date) -> Bool {
        guard let endsAt = restEndsAt else {
            return remainingSeconds == 0 && isRunning
        }
        return date > endsAt && (isRunning || isAwaitingResumeAcknowledgment)
    }

    var isRestComplete: Bool {
        isAwaitingResumeAcknowledgment || (isRunning && remainingSeconds == 0)
    }

    var formattedTime: String {
        formattedTime(at: Date())
    }

    func formattedTime(at date: Date) -> String {
        if isOvertime(at: date) {
            let overtime: Int
            if let endsAt = restEndsAt {
                overtime = max(0, Int(date.timeIntervalSince(endsAt)))
            } else {
                overtime = 0
            }
            let minutes = overtime / 60
            let seconds = overtime % 60
            return String(format: "+%02d:%02d", minutes, seconds)
        }
        let remaining: Int
        if let endsAt = restEndsAt {
            remaining = max(0, Int(ceil(endsAt.timeIntervalSince(date))))
        } else {
            remaining = remainingSeconds
        }
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func applyConfiguredDurationToActiveRestIfNeeded() {
        guard isRunning, !isAwaitingResumeAcknowledgment else { return }
        guard let startedAt = restStartedAt else { return }

        activeRestDurationSeconds = configuredRestSeconds
        restEndsAt = startedAt.addingTimeInterval(TimeInterval(activeRestDurationSeconds))
        syncFromWallClock(announceCompletion: true)

        guard remainingSeconds > 0 else { return }
        NotificationService.shared.cancelRestReminders()
        scheduleEndNotificationIfNeeded(after: remainingSeconds)
        WatchConnectivityManager.shared.sendRestTimerStart(
            seconds: remainingSeconds,
            exerciseName: currentExerciseName
        )
        persistRestState()
    }

    private func scheduleEndNotificationIfNeeded(after seconds: Int) {
        guard notificationEnabled, seconds > 0 else { return }
        NotificationService.shared.scheduleRestEndReminder(
            after: TimeInterval(seconds),
            exerciseName: currentExerciseName
        )
    }

    private func startDisplayTimerIfNeeded() {
        guard timer == nil, isRunning || isAwaitingResumeAcknowledgment else { return }
        let box = WeakMainActorBox(self)
        let displayTimer = Timer(timeInterval: 1, repeats: true) { _ in
            box.run { this in
                this.syncFromWallClock(announceCompletion: true)
            }
        }
        RunLoop.main.add(displayTimer, forMode: .common)
        timer = displayTimer
    }

    private func syncFromWallClock(announceCompletion: Bool) {
        guard isRunning || isAwaitingResumeAcknowledgment else { return }
        guard let endsAt = restEndsAt, let startedAt = restStartedAt else { return }

        let now = Date()
        let remaining = max(0, Int(ceil(endsAt.timeIntervalSince(now))))
        remainingSeconds = remaining

        let elapsed = max(0, Int(now.timeIntervalSince(startedAt)))
        if let exerciseId = currentRestExerciseId {
            let base = restAccumulatedBeforeCurrentPause[exerciseId, default: 0]
            // Conta o descanso real decorrido (inclui overtime após o fim).
            let actualPause = max(elapsed, 0)
            restByExerciseId[exerciseId] = base + actualPause
            totalRestSeconds = restByExerciseId.values.reduce(0, +)
        }

        if remaining == 0, isRunning, !hasSignaledRestComplete {
            hasSignaledRestComplete = true
            if announceCompletion {
                handleRestComplete()
            } else {
                // Em background: deixa a notificação agendada avisar; UI confirma ao voltar.
                isAwaitingResumeAcknowledgment = true
                isRunning = true
                persistRestState()
            }
        } else if isAwaitingResumeAcknowledgment {
            persistRestState()
        }
    }

    private func handleRestComplete() {
        isAwaitingResumeAcknowledgment = true
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        playRestCompleteSound()
        startReminderSoundLoop()

        NotificationService.shared.cancelRestReminders()
        if notificationEnabled {
            NotificationService.shared.deliverRestCompleteNotification(exerciseName: currentExerciseName)
        }
        onRestOvertime?(currentExerciseName)
        persistRestState()
    }

    private func playRestCompleteSound() {
        AudioServicesPlaySystemSound(1005)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    private func startReminderSoundLoop() {
        stopReminderSoundLoop()
        reminderSoundPlayCount = 0
        let box = WeakMainActorBox(self)
        let timer = Timer(timeInterval: 3, repeats: true) { _ in
            box.run { this in
                guard this.isAwaitingResumeAcknowledgment else {
                    this.stopReminderSoundLoop()
                    return
                }
                this.reminderSoundPlayCount += 1
                if this.reminderSoundPlayCount > Self.maxReminderSoundPlays {
                    this.stopReminderSoundLoop()
                    return
                }
                this.playRestCompleteSound()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        reminderSoundTimer = timer
    }

    private func stopReminderSoundLoop() {
        reminderSoundTimer?.invalidate()
        reminderSoundTimer = nil
        reminderSoundPlayCount = 0
    }

    private struct PersistedRestState: Codable {
        var isRunning: Bool
        var isAwaitingResumeAcknowledgment: Bool
        var exerciseName: String
        var exerciseId: UUID?
        var startedAt: Date
        var endsAt: Date
        var durationSeconds: Int
        var restByExercise: [String: Int]
        var totalRestSeconds: Int
        var accumulatedBeforePause: [String: Int]
    }

    private func persistRestState() {
        guard isRunning || isAwaitingResumeAcknowledgment,
              let startedAt = restStartedAt,
              let endsAt = restEndsAt else {
            clearPersistedRestState()
            return
        }
        let state = PersistedRestState(
            isRunning: isRunning,
            isAwaitingResumeAcknowledgment: isAwaitingResumeAcknowledgment,
            exerciseName: currentExerciseName,
            exerciseId: currentRestExerciseId,
            startedAt: startedAt,
            endsAt: endsAt,
            durationSeconds: activeRestDurationSeconds,
            restByExercise: Dictionary(uniqueKeysWithValues: restByExerciseId.map { ($0.key.uuidString, $0.value) }),
            totalRestSeconds: totalRestSeconds,
            accumulatedBeforePause: Dictionary(
                uniqueKeysWithValues: restAccumulatedBeforeCurrentPause.map { ($0.key.uuidString, $0.value) }
            )
        )
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: restStateKey)
        }
    }

    private func clearPersistedRestState() {
        UserDefaults.standard.removeObject(forKey: restStateKey)
    }

    private func restorePersistedRestStateIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: restStateKey),
              let state = try? JSONDecoder().decode(PersistedRestState.self, from: data) else { return }

        currentExerciseName = state.exerciseName
        currentRestExerciseId = state.exerciseId
        restStartedAt = state.startedAt
        restEndsAt = state.endsAt
        activeRestDurationSeconds = max(1, state.durationSeconds)
        isAwaitingResumeAcknowledgment = state.isAwaitingResumeAcknowledgment
        isRunning = state.isRunning || state.isAwaitingResumeAcknowledgment
        hasSignaledRestComplete = state.isAwaitingResumeAcknowledgment || state.endsAt <= Date()
        restByExerciseId = Dictionary(
            uniqueKeysWithValues: state.restByExercise.compactMap { key, value in
                guard let id = UUID(uuidString: key) else { return nil }
                return (id, value)
            }
        )
        restAccumulatedBeforeCurrentPause = Dictionary(
            uniqueKeysWithValues: state.accumulatedBeforePause.compactMap { key, value in
                guard let id = UUID(uuidString: key) else { return nil }
                return (id, value)
            }
        )
        totalRestSeconds = state.totalRestSeconds
        syncFromWallClock(announceCompletion: false)
        if remainingSeconds == 0 {
            isAwaitingResumeAcknowledgment = true
            hasSignaledRestComplete = true
        }
    }

    private static func clampRest(_ value: Int) -> Int {
        min(300, max(15, value))
    }
}
