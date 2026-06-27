import Foundation
import Combine

@MainActor
final class RestTimerService: ObservableObject {
    @Published var isRunning = false
    @Published var remainingSeconds: Int = 60
    @Published var configuredRestSeconds: Int = 60
    @Published var maxRestSeconds: Int = 120
    @Published var notificationEnabled = true
    var onRestOvertime: ((String) -> Void)?

    @Published private(set) var restByExerciseId: [UUID: Int] = [:]
    @Published private(set) var totalRestSeconds: Int = 0

    private var timer: Timer?
    private var elapsedSinceStart = 0
    private var currentExerciseName = ""
    private var currentRestExerciseId: UUID?
    private var hasSentOvertimeNotification = false

    func resetSessionTracking() {
        restByExerciseId = [:]
        totalRestSeconds = 0
        currentRestExerciseId = nil
    }

    func configure(restSeconds: Int, maxRest: Int, notifications: Bool) {
        configuredRestSeconds = restSeconds
        maxRestSeconds = max(restSeconds, maxRest)
        notificationEnabled = notifications
    }

    func startRest(for exerciseName: String, exerciseId: UUID) {
        timer?.invalidate()
        timer = nil
        NotificationService.shared.cancelRestReminders()
        hasSentOvertimeNotification = false

        currentExerciseName = exerciseName
        currentRestExerciseId = exerciseId
        remainingSeconds = configuredRestSeconds
        elapsedSinceStart = 0
        isRunning = true

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        currentRestExerciseId = nil
        hasSentOvertimeNotification = false
        NotificationService.shared.cancelRestReminders()
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

        if remainingSeconds == 0 && elapsedSinceStart == configuredRestSeconds {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }

        notifyOvertimeIfNeeded()
    }

    private func notifyOvertimeIfNeeded() {
        guard notificationEnabled,
              !hasSentOvertimeNotification,
              elapsedSinceStart > configuredRestSeconds else { return }

        hasSentOvertimeNotification = true
        NotificationService.shared.deliverRestOvertimeNotification(exerciseName: currentExerciseName)
        onRestOvertime?(currentExerciseName)
    }
}

import UIKit
