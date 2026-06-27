import Foundation
import WatchConnectivity
import Combine

@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {
    @Published var isWatchConnected = false
    @Published var watchHeartRate: Double = 0
    @Published var watchCalories: Double = 0
    @Published var isWorkoutActiveOnWatch = false

    private var session: WCSession?

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    func startWorkoutOnWatch(workoutName: String) {
        guard let session, session.isReachable else {
            isWorkoutActiveOnWatch = true
            simulateWatchData()
            return
        }

        let message: [String: Any] = [
            "action": "startWorkout",
            "workoutName": workoutName,
            "timestamp": Date().timeIntervalSince1970
        ]
        session.sendMessage(message, replyHandler: nil)
        isWorkoutActiveOnWatch = true
    }

    func stopWorkoutOnWatch() {
        guard let session, session.isReachable else {
            isWorkoutActiveOnWatch = false
            return
        }

        let message: [String: Any] = ["action": "stopWorkout"]
        session.sendMessage(message, replyHandler: nil)
        isWorkoutActiveOnWatch = false
    }

    func sendRestTimerStart(seconds: Int, exerciseName: String) {
        sendToWatch([
            "action": "restTimerStart",
            "seconds": seconds,
            "exerciseName": exerciseName
        ])
    }

    func sendRestTimerStop() {
        sendToWatch(["action": "restTimerStop"])
    }

    func sendRestOvertimeAlert(exerciseName: String) {
        sendToWatch([
            "action": "restOvertime",
            "exerciseName": exerciseName
        ])
    }

    func sendRestTimer(seconds: Int) {
        sendRestTimerStart(seconds: seconds, exerciseName: "")
    }

    private func sendToWatch(_ message: [String: Any]) {
        guard let session else { return }
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil)
        } else {
            session.transferUserInfo(message)
        }
    }

    private func simulateWatchData() {
        Task {
            while isWorkoutActiveOnWatch {
                watchHeartRate = Double.random(in: 110...165)
                watchCalories += Double.random(in: 2...8)
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            isWatchConnected = activationState == .activated && session.isPaired
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in
            handleWatchMessage(userInfo)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            handleWatchMessage(message)
        }
    }

    private func handleWatchMessage(_ message: [String: Any]) {
        if let heartRate = message["heartRate"] as? Double {
            watchHeartRate = heartRate
        }
        if let calories = message["calories"] as? Double {
            watchCalories = calories
        }
    }
}
