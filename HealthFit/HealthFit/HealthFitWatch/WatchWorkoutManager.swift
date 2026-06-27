import Foundation
import WatchConnectivity
import HealthKit
import Combine
import UserNotifications
import WatchKit

@MainActor
final class WatchWorkoutManager: NSObject, ObservableObject {
    @Published var isActive = false
    @Published var workoutName = ""
    @Published var heartRate: Double = 0
    @Published var calories: Double = 0
    @Published var restRemainingSeconds = 0
    @Published var isResting = false
    @Published var isRestOvertime = false
    @Published var restExerciseName = ""
    @Published var restOvertimeSeconds = 0

    private var session: WCSession?
    private var heartRateTimer: Timer?
    private var restTimer: Timer?
    private var configuredRestSeconds = 60
    private var restElapsedSeconds = 0
    private var hasSentRestOvertimeNotification = false
    private let healthStore = HKHealthStore()

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    func startWorkout(name: String) {
        workoutName = name
        isActive = true
        calories = 0
        startHeartRateMonitoring()
    }

    func stopWorkout() {
        isActive = false
        heartRateTimer?.invalidate()
        heartRateTimer = nil
        stopRestCountdown()
        sendMetricsToPhone()
    }

    func startRestCountdown(seconds: Int, exerciseName: String) {
        stopRestCountdown()
        configuredRestSeconds = max(seconds, 1)
        restExerciseName = exerciseName
        restRemainingSeconds = configuredRestSeconds
        restElapsedSeconds = 0
        isResting = true
        isRestOvertime = false
        restOvertimeSeconds = 0
        hasSentRestOvertimeNotification = false

        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickRest()
            }
        }
    }

    func stopRestCountdown() {
        restTimer?.invalidate()
        restTimer = nil
        isResting = false
        isRestOvertime = false
        restRemainingSeconds = 0
        restElapsedSeconds = 0
        restOvertimeSeconds = 0
        restExerciseName = ""
        hasSentRestOvertimeNotification = false
    }

    func notifyRestOvertime(exerciseName: String) {
        guard !hasSentRestOvertimeNotification else { return }
        hasSentRestOvertimeNotification = true
        isRestOvertime = true
        restExerciseName = exerciseName.isEmpty ? restExerciseName : exerciseName
        deliverWatchRestOvertimeNotification(exerciseName: restExerciseName)
        WKInterfaceDevice.current().play(.notification)
    }

    private func tickRest() {
        restElapsedSeconds += 1

        if restRemainingSeconds > 0 {
            restRemainingSeconds -= 1
        }

        if restRemainingSeconds == 0 && restElapsedSeconds == configuredRestSeconds {
            WKInterfaceDevice.current().play(.retry)
        }

        if restElapsedSeconds > configuredRestSeconds {
            isRestOvertime = true
            restOvertimeSeconds = restElapsedSeconds - configuredRestSeconds
            notifyRestOvertime(exerciseName: restExerciseName)
        }
    }

    private func deliverWatchRestOvertimeNotification(exerciseName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Descanso encerrado!"
        content.body = "Volte ao treino: \(exerciseName)"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "watch_rest_overtime_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func startHeartRateMonitoring() {
        heartRateTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchHeartRate()
                self?.calories += Double.random(in: 1...5)
                self?.sendMetricsToPhone()
            }
        }
    }

    private func fetchHeartRate() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            heartRate = Double.random(in: 100...150)
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
            Task { @MainActor in
                if let sample = samples?.first as? HKQuantitySample {
                    self?.heartRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                } else {
                    self?.heartRate = Double.random(in: 100...150)
                }
            }
        }
        healthStore.execute(query)
    }

    private func sendMetricsToPhone() {
        guard let session, session.isReachable else { return }
        session.sendMessage([
            "heartRate": heartRate,
            "calories": calories
        ], replyHandler: nil)
    }

    private func handlePhoneMessage(_ message: [String: Any]) {
        guard let action = message["action"] as? String else { return }

        switch action {
        case "startWorkout":
            let name = message["workoutName"] as? String ?? "Treino"
            startWorkout(name: name)
        case "stopWorkout":
            stopWorkout()
        case "restTimerStart":
            let seconds = message["seconds"] as? Int ?? 60
            let exerciseName = message["exerciseName"] as? String ?? "Exercício"
            startRestCountdown(seconds: seconds, exerciseName: exerciseName)
        case "restTimerStop":
            stopRestCountdown()
        case "restOvertime":
            let exerciseName = message["exerciseName"] as? String ?? restExerciseName
            notifyRestOvertime(exerciseName: exerciseName)
        case "restTimer":
            let seconds = message["seconds"] as? Int ?? 60
            startRestCountdown(seconds: seconds, exerciseName: "Exercício")
        default:
            break
        }
    }
}

extension WatchWorkoutManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            handlePhoneMessage(message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in
            handlePhoneMessage(userInfo)
        }
    }
}
