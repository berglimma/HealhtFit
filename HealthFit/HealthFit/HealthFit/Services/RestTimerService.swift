import Foundation
import Combine

@MainActor
final class RestTimerService: ObservableObject {
    @Published var isRunning = false
    @Published var remainingSeconds: Int = 60
    @Published var configuredRestSeconds: Int = 60
    @Published var maxRestSeconds: Int = 120
    @Published var notificationEnabled = true

    private var timer: Timer?
    private var elapsedSinceStart = 0
    private var currentExerciseName = ""

    func configure(restSeconds: Int, maxRest: Int, notifications: Bool) {
        configuredRestSeconds = restSeconds
        maxRestSeconds = max(restSeconds, maxRest)
        notificationEnabled = notifications
    }

    func startRest(for exerciseName: String) {
        stopTimer()
        currentExerciseName = exerciseName
        remainingSeconds = configuredRestSeconds
        elapsedSinceStart = 0
        isRunning = true

        if notificationEnabled {
            NotificationService.shared.cancelRestReminders()
            NotificationService.shared.scheduleRestReminder(
                after: TimeInterval(maxRestSeconds),
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
        isRunning = false
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
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func tick() {
        elapsedSinceStart += 1

        if remainingSeconds > 0 {
            remainingSeconds -= 1
        }

        if remainingSeconds == 0 && elapsedSinceStart == configuredRestSeconds {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }
}

import UIKit
