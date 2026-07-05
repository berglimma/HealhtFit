import Foundation
import WatchConnectivity
import Combine

@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var isWatchConnected = false
    @Published var watchHeartRate: Double = 0
    @Published var watchCalories: Double = 0
    @Published var isWorkoutActiveOnWatch = false

    private var session: WCSession?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    func startWorkoutOnWatch(workoutName: String, exerciseName: String = "") {
        let message: [String: Any] = [
            "action": "startWorkout",
            "workoutName": workoutName,
            "exerciseName": exerciseName,
            "workoutMode": "strength",
            "workoutElapsedSeconds": 0,
            "exerciseElapsedSeconds": 0,
            "timestamp": Date().timeIntervalSince1970
        ]
        sendToWatch(message)
        publishWorkoutContext(message)
        isWorkoutActiveOnWatch = true
        if session?.isReachable != true {
            simulateWatchData()
        }
    }

    func startCardioOnWatch(workoutName: String, targetSeconds: Int, exerciseName: String, targetCalories: Int? = nil) {
        watchCalories = 0
        sendToWatch([
            "action": "startCardio",
            "workoutName": workoutName,
            "targetSeconds": targetSeconds,
            "exerciseName": exerciseName,
            "targetCalories": targetCalories ?? 0,
            "timestamp": Date().timeIntervalSince1970
        ])
        isWorkoutActiveOnWatch = true
        if session?.isReachable != true {
            simulateWatchData()
        }
    }

    func syncWorkoutProgress(
        workoutElapsedSeconds: Int,
        exerciseName: String,
        exerciseElapsedSeconds: Int
    ) {
        let message: [String: Any] = [
            "action": "syncWorkoutProgress",
            "workoutName": workoutNameIfActive(),
            "workoutElapsedSeconds": workoutElapsedSeconds,
            "exerciseName": exerciseName,
            "exerciseElapsedSeconds": exerciseElapsedSeconds,
            "timestamp": Date().timeIntervalSince1970
        ]
        sendToWatch(message, realtime: true)
        publishWorkoutContext(message)
    }

    func syncCardioProgress(
        elapsedSeconds: Int,
        targetSeconds: Int,
        currentCalories: Double,
        targetCalories: Int? = nil
    ) {
        sendToWatch([
            "action": "syncCardioProgress",
            "elapsedSeconds": elapsedSeconds,
            "targetSeconds": targetSeconds,
            "currentCalories": currentCalories,
            "targetCalories": targetCalories ?? 0
        ], realtime: true)
    }

    func startMeditationOnWatch(
        workoutName: String,
        targetSeconds: Int,
        topicName: String,
        topicIcon: String,
        colorName: String,
        currentPrompt: String,
        promptIndex: Int,
        totalPrompts: Int
    ) {
        sendToWatch([
            "action": "startMeditation",
            "workoutName": workoutName,
            "targetSeconds": targetSeconds,
            "topicName": topicName,
            "topicIcon": topicIcon,
            "colorName": colorName,
            "currentPrompt": currentPrompt,
            "promptIndex": promptIndex,
            "totalPrompts": totalPrompts,
            "timestamp": Date().timeIntervalSince1970
        ])
        isWorkoutActiveOnWatch = true
    }

    func syncMeditationProgress(
        elapsedSeconds: Int,
        targetSeconds: Int,
        currentPrompt: String,
        promptIndex: Int
    ) {
        sendToWatch([
            "action": "syncMeditationProgress",
            "elapsedSeconds": elapsedSeconds,
            "targetSeconds": targetSeconds,
            "currentPrompt": currentPrompt,
            "promptIndex": promptIndex
        ], realtime: true)
    }

    func stopWorkoutOnWatch() {
        let message: [String: Any] = ["action": "stopWorkout"]
        sendToWatch(message)
        publishWorkoutContext(message)
        isWorkoutActiveOnWatch = false
        lastWorkoutName = ""
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

    func deliverNotificationToWatch(
        title: String,
        body: String,
        category: String,
        identifier: String,
        exerciseName: String? = nil
    ) {
        var message: [String: Any] = [
            "action": "deliverNotification",
            "title": title,
            "body": body,
            "category": category,
            "identifier": identifier
        ]
        if let exerciseName {
            message["exerciseName"] = exerciseName
        }
        sendToWatch(message)
    }

    func syncDailyMotivationToWatch(entries: [[String: Any]]) {
        guard let payload = try? JSONSerialization.data(withJSONObject: entries) else { return }
        sendToWatch([
            "action": "syncDailyMotivation",
            "payload": payload
        ])
    }

    func cancelDailyMotivationOnWatch() {
        sendToWatch(["action": "cancelDailyMotivation"])
    }

    func scheduleInactivityReminderOnWatch(
        title: String,
        body: String,
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        identifier: String
    ) {
        sendToWatch([
            "action": "scheduleInactivityReminder",
            "title": title,
            "body": body,
            "year": year,
            "month": month,
            "day": day,
            "hour": hour,
            "minute": minute,
            "identifier": identifier
        ])
    }

    func cancelInactivityReminderOnWatch() {
        sendToWatch(["action": "cancelInactivityReminder"])
    }

    private var lastWorkoutName = ""

    private func workoutNameIfActive() -> String {
        lastWorkoutName
    }

    private func sendToWatch(_ message: [String: Any], realtime: Bool = false) {
        guard let session else { return }

        if let action = message["action"] as? String, action == "startWorkout",
           let workoutName = message["workoutName"] as? String {
            lastWorkoutName = workoutName
        }

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { _ in
                session.transferUserInfo(message)
            }
        } else {
            session.transferUserInfo(message)
        }
    }

    private func publishWorkoutContext(_ message: [String: Any]) {
        guard let session else { return }
        guard let action = message["action"] as? String else { return }
        guard ["startWorkout", "syncWorkoutProgress", "stopWorkout", "startCardio", "startMeditation"].contains(action) else {
            return
        }

        do {
            try session.updateApplicationContext(message)
        } catch {
            #if DEBUG
            print("[HealthFit] Falha ao publicar contexto do Watch: \(error.localizedDescription)")
            #endif
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
