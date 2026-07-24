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
    private var elapsedSinceStart = 0
    private var currentRestExerciseId: UUID?
    private var hasSignaledRestComplete = false
    private var reminderSoundTimer: Timer?

    private let restSecondsKey = "healthfit_rest_seconds"
    private let maxRestKey = "healthfit_max_rest_seconds"
    private let notificationsKey = "healthfit_rest_notifications"

    init() {
        let savedRest = UserDefaults.standard.object(forKey: restSecondsKey) as? Int ?? 60
        let savedMax = UserDefaults.standard.object(forKey: maxRestKey) as? Int ?? 120
        configuredRestSeconds = max(15, savedRest)
        maxRestSeconds = max(configuredRestSeconds, savedMax)
        remainingSeconds = configuredRestSeconds
        if UserDefaults.standard.object(forKey: notificationsKey) != nil {
            notificationEnabled = UserDefaults.standard.bool(forKey: notificationsKey)
        }
    }

    func resetSessionTracking() {
        restByExerciseId = [:]
        totalRestSeconds = 0
        currentRestExerciseId = nil
    }

    func configure(restSeconds: Int, maxRest: Int, notifications: Bool) {
        configuredRestSeconds = restSeconds
        maxRestSeconds = max(restSeconds, maxRest)
        notificationEnabled = notifications
        persistConfiguration()
        if !isRunning {
            remainingSeconds = configuredRestSeconds
        }
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
        remainingSeconds = configuredRestSeconds
        elapsedSinceStart = 0
        isRunning = true

        if notificationEnabled {
            NotificationService.shared.scheduleRestEndReminder(
                after: TimeInterval(configuredRestSeconds),
                exerciseName: exerciseName
            )
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        stopReminderSoundLoop()
        isRunning = false
        isAwaitingResumeAcknowledgment = false
        currentRestExerciseId = nil
        hasSignaledRestComplete = false
        NotificationService.shared.cancelRestReminders()
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
        elapsedSinceStart = 0
    }

    var progress: Double {
        guard configuredRestSeconds > 0 else { return 0 }
        return 1.0 - (Double(remainingSeconds) / Double(configuredRestSeconds))
    }

    var isOvertime: Bool {
        elapsedSinceStart > configuredRestSeconds
    }

    var isRestComplete: Bool {
        isAwaitingResumeAcknowledgment || (isRunning && remainingSeconds == 0)
    }

    var formattedTime: String {
        if isOvertime {
            let overtime = elapsedSinceStart - configuredRestSeconds
            let minutes = overtime / 60
            let seconds = overtime % 60
            return String(format: "+%02d:%02d", minutes, seconds)
        }
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func tick() {
        elapsedSinceStart += 1

        if isRunning, let exerciseId = currentRestExerciseId {
            restByExerciseId[exerciseId, default: 0] += 1
            totalRestSeconds += 1
        }

        if remainingSeconds > 0 {
            remainingSeconds -= 1
        }

        if remainingSeconds == 0 && !hasSignaledRestComplete {
            hasSignaledRestComplete = true
            handleRestComplete()
        }
    }

    private func handleRestComplete() {
        isAwaitingResumeAcknowledgment = true
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        playRestCompleteSound()
        startReminderSoundLoop()

        // Cancela o lembrete agendado no início da pausa para não duplicar a notificação.
        NotificationService.shared.cancelRestReminders()
        if notificationEnabled {
            NotificationService.shared.deliverRestCompleteNotification(exerciseName: currentExerciseName)
        }
        onRestOvertime?(currentExerciseName)
    }

    private func playRestCompleteSound() {
        // Alerta sonoro do sistema + vibração
        AudioServicesPlaySystemSound(1005)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    private func startReminderSoundLoop() {
        stopReminderSoundLoop()
        reminderSoundTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isAwaitingResumeAcknowledgment else {
                    self?.stopReminderSoundLoop()
                    return
                }
                self.playRestCompleteSound()
            }
        }
    }

    private func stopReminderSoundLoop() {
        reminderSoundTimer?.invalidate()
        reminderSoundTimer = nil
    }
}