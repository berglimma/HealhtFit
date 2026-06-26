import Foundation
import WatchConnectivity
import HealthKit
import Combine

@MainActor
final class WatchWorkoutManager: NSObject, ObservableObject {
    @Published var isActive = false
    @Published var workoutName = ""
    @Published var heartRate: Double = 0
    @Published var calories: Double = 0
    @Published var restSeconds = 0

    private var session: WCSession?
    private var heartRateTimer: Timer?
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
        sendMetricsToPhone()
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
}

extension WatchWorkoutManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            if let action = message["action"] as? String {
                switch action {
                case "startWorkout":
                    let name = message["workoutName"] as? String ?? "Treino"
                    startWorkout(name: name)
                case "stopWorkout":
                    stopWorkout()
                case "restTimer":
                    restSeconds = message["seconds"] as? Int ?? 60
                default:
                    break
                }
            }
        }
    }
}
