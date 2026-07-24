import Foundation
import WatchConnectivity
import Combine

enum WatchSyncResult: Equatable {
    case synced
    case notSupported
    case notPaired
    case appNotInstalled
    case unreachable
    case activationFailed

    var isSuccess: Bool {
        self == .synced
    }

    var title: String {
        isSuccess ? "Apple Watch sincronizado" : "Não foi possível sincronizar"
    }

    var message: String {
        switch self {
        case .synced:
            return "Conexão com o Apple Watch confirmada. BPM e calorias serão recebidos do relógio."
        case .notSupported:
            return "Este dispositivo não oferece sincronização com Apple Watch."
        case .notPaired:
            return "Nenhum Apple Watch pareado. Pareie o relógio em Ajustes → Bluetooth / app Watch."
        case .appNotInstalled:
            return "O app HealthFit não está instalado no Apple Watch. Instale pelo app Watch no iPhone."
        case .unreachable:
            return "O Apple Watch está pareado, mas não respondeu agora. Desbloqueie o relógio, abra o HealthFit no Watch e tente de novo."
        case .activationFailed:
            return "A sessão com o Apple Watch não pôde ser ativada. Verifique o pareamento e tente novamente."
        }
    }
}

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

    /// Tenta reativar a sessão e confirmar sincronismo ao vivo com o Apple Watch.
    func attemptSyncWithWatch() async -> WatchSyncResult {
        guard WCSession.isSupported() else {
            isWatchConnected = false
            return .notSupported
        }

        guard let session else {
            isWatchConnected = false
            return .notSupported
        }

        if session.activationState != .activated {
            session.activate()
            for _ in 0..<25 {
                if session.activationState == .activated { break }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }

        refreshConnectionStatus()

        guard session.activationState == .activated else {
            isWatchConnected = false
            return .activationFailed
        }

        guard session.isPaired else {
            isWatchConnected = false
            return .notPaired
        }

        guard session.isWatchAppInstalled else {
            isWatchConnected = false
            return .appNotInstalled
        }

        // Aguarda um pouco a reachability após ativação.
        if !session.isReachable {
            for _ in 0..<15 {
                if session.isReachable { break }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }

        guard session.isReachable else {
            refreshConnectionStatus()
            return .unreachable
        }

        let replied = await pingWatch(using: session)
        refreshConnectionStatus()
        return replied ? .synced : .unreachable
    }

    private func pingWatch(using session: WCSession) async -> Bool {
        await withCheckedContinuation { continuation in
            var hasResumed = false
            let finish: (Bool) -> Void = { success in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: success)
            }

            session.sendMessage(
                ["action": "ping", "timestamp": Date().timeIntervalSince1970],
                replyHandler: { reply in
                    let ok = (reply["action"] as? String) == "pong"
                        || (reply["ok"] as? Bool) == true
                    Task { @MainActor in
                        finish(ok)
                    }
                },
                errorHandler: { _ in
                    Task { @MainActor in
                        finish(false)
                    }
                }
            )

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(4))
                finish(false)
            }
        }
    }

    func startWorkoutOnWatch(workoutName: String, exerciseName: String = "") {
        clearWatchMetrics()
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
        refreshConnectionStatus()
    }

    func startCardioOnWatch(workoutName: String, targetSeconds: Int, exerciseName: String, targetCalories: Int? = nil) {
        clearWatchMetrics()
        sendToWatch([
            "action": "startCardio",
            "workoutName": workoutName,
            "targetSeconds": targetSeconds,
            "exerciseName": exerciseName,
            "targetCalories": targetCalories ?? 0,
            "timestamp": Date().timeIntervalSince1970
        ])
        isWorkoutActiveOnWatch = true
        refreshConnectionStatus()
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
        clearWatchMetrics()
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
        refreshConnectionStatus()
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
        // Não envia estimativa do iPhone como calorias — o Watch é a fonte.
        sendToWatch([
            "action": "syncCardioProgress",
            "elapsedSeconds": elapsedSeconds,
            "targetSeconds": targetSeconds,
            "currentCalories": watchCalories,
            "targetCalories": targetCalories ?? 0
        ], realtime: true)
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
        clearWatchMetrics()
        refreshConnectionStatus()
    }

    /// BPM e kcal vêm apenas do Apple Watch; sem Watch pareado/alcançável ficam zerados.
    var hasLiveWatchMetrics: Bool {
        isWatchConnected && (session?.isReachable == true)
    }

    private func clearWatchMetrics() {
        watchHeartRate = 0
        watchCalories = 0
    }

    private func refreshConnectionStatus() {
        guard let session else {
            isWatchConnected = false
            return
        }
        isWatchConnected = session.activationState == .activated
            && session.isPaired
            && session.isWatchAppInstalled
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
}

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            refreshConnectionStatus()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            refreshConnectionStatus()
            // Sem Watch alcançável, não mantém métricas simuladas/antigas.
            if !session.isReachable {
                clearWatchMetrics()
            }
        }
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

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            handleWatchMessage(message)
        }
        replyHandler(["ok": true])
    }

    private func handleWatchMessage(_ message: [String: Any]) {
        refreshConnectionStatus()
        if let heartRate = message["heartRate"] as? Double {
            watchHeartRate = max(0, heartRate)
        }
        if let calories = message["calories"] as? Double {
            watchCalories = max(0, calories)
        }
    }
}
