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
            #if targetEnvironment(simulator)
            return "No simulador: use um iPhone e um Apple Watch pareados (ambos Booted). No Xcode, rode também o scheme HealthFitWatch."
            #else
            return "Nenhum Apple Watch pareado. Pareie o relógio em Ajustes → Bluetooth / app Watch."
            #endif
        case .appNotInstalled:
            #if targetEnvironment(simulator)
            return "Instale o HealthFit no Watch Simulator: rode o scheme HealthFitWatch (ou rode o iPhone com o Watch pareado para embutir o app)."
            #else
            return "O app HealthFit não está instalado no Apple Watch. Instale pelo app Watch no iPhone."
            #endif
        case .unreachable:
            #if targetEnvironment(simulator)
            return "Watch pareado, mas inacessível. Abra o app HealthFit no Apple Watch Simulator e toque em sincronizar de novo."
            #else
            return "O Apple Watch está pareado, mas não respondeu agora. Desbloqueie o relógio, abra o HealthFit no Watch e tente de novo."
            #endif
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
    @Published var watchSteps: Int = 0
    @Published var isWorkoutActiveOnWatch = false
    @Published private(set) var lastWatchJumpEvent: (height: Double, peakG: Double, airtime: Double?)?
    @Published private(set) var watchJumpTick: Int = 0
    @Published private(set) var lastWatchAccelG: Double = 0
    /// Voltas de natação reportadas pelo Apple Watch (fonte automática).
    @Published private(set) var watchSwimLapCount: Int = 0
    @Published private(set) var watchSwimDistanceMeters: Double = 0
    @Published private(set) var watchSwimLapTick: Int = 0
    /// Pause enviado pelo Watch para a sessão espelhada.
    @Published private(set) var isWatchSessionPaused = false
    /// Incrementado quando o Watch encerra uma sessão que estava espelhada — o iPhone fecha o overlay.
    @Published private(set) var watchForcedSessionCloseTick: Int = 0

    private var session: WCSession?
    /// Store de treinos do iPhone — necessário para espelhar início no Watch.
    private weak var workoutStore: WorkoutStore?
    private var lastMirroredWatchStartAt: TimeInterval = 0

    private override init() {
        super.init()
        // Defer WCSession.activate until after first paint (see ensureSessionActivated).
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
        }
    }

    /// Liga o store da UI para treinos iniciados no Watch abrirem no iPhone.
    func bind(workoutStore: WorkoutStore) {
        self.workoutStore = workoutStore
    }

    /// Activates WatchConnectivity after the UI is interactive (cold launch).
    func ensureSessionActivated() {
        guard WCSession.isSupported() else { return }
        if session == nil {
            session = WCSession.default
            session?.delegate = self
        }
        guard let session, session.activationState != .activated else { return }
        session.activate()
    }

    /// Tenta reativar a sessão e confirmar sincronismo ao vivo com o Apple Watch.
    func attemptSyncWithWatch() async -> WatchSyncResult {
        guard WCSession.isSupported() else {
            isWatchConnected = false
            return .notSupported
        }

        ensureSessionActivated()

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

        // Aguarda reachability — no simulador o Watch precisa estar com o app aberto.
        if !session.isReachable {
            for _ in 0..<8 {
                if session.isReachable { break }
                try? await Task.sleep(for: .milliseconds(80))
            }
        }

        if session.isReachable {
            let replied = await pingWatch(using: session)
            refreshConnectionStatus()
            return replied ? .synced : .unreachable
        }

        // Pareado + app instalado, mas sem reachability: o Watch precisa estar aberto.
        refreshConnectionStatus()
        session.transferUserInfo([
            "action": "ping",
            "timestamp": Date().timeIntervalSince1970
        ])
        return .unreachable
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
                try? await Task.sleep(for: .seconds(2))
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

    func startCardioOnWatch(
        workoutName: String,
        targetSeconds: Int,
        exerciseName: String,
        targetCalories: Int? = nil,
        waterSportMode: Bool = false,
        isKitesurf: Bool = false,
        swimmingMode: Bool = false,
        poolLengthMeters: Double = 25
    ) {
        clearWatchMetrics()
        sendToWatch([
            "action": "startCardio",
            "workoutName": workoutName,
            "targetSeconds": targetSeconds,
            "exerciseName": exerciseName,
            "targetCalories": targetCalories ?? 0,
            "waterSportMode": waterSportMode,
            "isKitesurf": isKitesurf,
            "swimmingMode": swimmingMode,
            "poolLengthMeters": poolLengthMeters,
            "timestamp": Date().timeIntervalSince1970
        ])
        isWorkoutActiveOnWatch = true
        refreshConnectionStatus()
    }

    /// Solicita sincronização imediata e pede amostras de motion ao Watch (surf/kite).
    func requestWatchWaterSportSync() {
        sendToWatch([
            "action": "requestWaterSportSync",
            "timestamp": Date().timeIntervalSince1970
        ], realtime: true)
        Task {
            _ = await attemptSyncWithWatch()
        }
    }

    /// Publica para o Watch: última altura estimada / contagem de saltos (espelho).
    func syncWaterSportJumpSummary(jumpCount: Int, maxHeightMeters: Double, liveAccelG: Double) {
        sendToWatch([
            "action": "syncWaterSportMetrics",
            "jumpCount": jumpCount,
            "maxJumpHeightMeters": maxHeightMeters,
            "liveAccelG": liveAccelG
        ], realtime: true)
    }

    /// Pede ao Watch o envio imediato de voltas/distância de natação.
    func requestWatchSwimSync() {
        sendToWatch([
            "action": "requestSwimSync",
            "timestamp": Date().timeIntervalSince1970
        ], realtime: true)
        Task {
            _ = await attemptSyncWithWatch()
        }
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
        isWatchSessionPaused = false
        lastWorkoutName = ""
        clearWatchMetrics()
        refreshConnectionStatus()
    }

    /// BPM/kcal ao vivo do Watch — mantém última leitura mesmo se a reachability oscilar.
    var hasLiveWatchMetrics: Bool {
        if watchHeartRate > 0 || watchCalories > 0 { return true }
        return isWatchConnected && (session?.isReachable == true)
    }

    private func clearWatchMetrics() {
        watchHeartRate = 0
        watchCalories = 0
        watchSwimLapCount = 0
        watchSwimDistanceMeters = 0
        // Passos do dia permanecem; vêm do HealthKit/Watch ao longo do dia.
    }

    /// WCSession muitas vezes entrega `NSNumber` em vez de `Double` (transferUserInfo).
    private static func double(from message: [String: Any], key: String) -> Double? {
        if let value = message[key] as? Double { return value }
        if let value = message[key] as? NSNumber { return value.doubleValue }
        if let value = message[key] as? Int { return Double(value) }
        return nil
    }

    private static func int(from message: [String: Any], key: String) -> Int? {
        if let value = message[key] as? Int { return value }
        if let value = message[key] as? NSNumber { return value.intValue }
        if let value = message[key] as? Double { return Int(value) }
        return nil
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

        if session.activationState != .activated {
            session.activate()
        }

        if let action = message["action"] as? String, action == "startWorkout",
           let workoutName = message["workoutName"] as? String {
            lastWorkoutName = workoutName
        }

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { _ in
                session.transferUserInfo(message)
            }
        } else if session.activationState == .activated {
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
            WatchConnectivityManager.shared.refreshConnectionStatus()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            let manager = WatchConnectivityManager.shared
            manager.refreshConnectionStatus()
            // Não zera BPM/kcal aqui: a reachability oscila com frequência e
            // apagar a última leitura deixa a UI em 0 BPM durante o treino.
            // Métricas são limpas em stopWorkoutOnWatch / watchStoppedSession.
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            WatchConnectivityManager.shared.refreshConnectionStatus()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in
            WatchConnectivityManager.shared.handleWatchMessage(userInfo)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            WatchConnectivityManager.shared.handleWatchMessage(message)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            WatchConnectivityManager.shared.handleWatchMessage(message)
        }
        replyHandler(["ok": true])
    }

    private func handleWatchMessage(_ message: [String: Any]) {
        refreshConnectionStatus()
        var heartRate: Double?
        var calories: Double?
        var steps: Int?

        if let value = Self.double(from: message, key: "heartRate") {
            // Ignora 0 transitório para não apagar a última leitura válida do sensor.
            if value > 0 {
                watchHeartRate = value
                heartRate = watchHeartRate
            }
        }
        if let value = Self.double(from: message, key: "calories") {
            watchCalories = max(0, value)
            calories = watchCalories
        }
        if let value = Self.int(from: message, key: "steps") {
            watchSteps = max(0, value)
            steps = watchSteps
        }

        let action = message["action"] as? String

        // Natação: voltas e distância vindas do Watch (HK ou métricas de sessão).
        let swimLaps = Self.int(from: message, key: "swimLapCount")
        let swimDistance = Self.double(from: message, key: "swimDistanceMeters")
        if action == "swimMetrics" || swimLaps != nil || swimDistance != nil {
            if let swimLaps {
                let next = max(0, swimLaps)
                if next != watchSwimLapCount {
                    watchSwimLapCount = next
                    watchSwimLapTick += 1
                } else {
                    watchSwimLapCount = next
                }
            }
            if let swimDistance {
                watchSwimDistanceMeters = max(0, swimDistance)
            }
        }

        if action == "waterSportJump" {
            let height = Self.double(from: message, key: "heightMeters") ?? 1
            let peakG = Self.double(from: message, key: "peakG") ?? 1.5
            let airtime = Self.double(from: message, key: "airtimeSeconds")
            lastWatchJumpEvent = (height, peakG, airtime)
            watchJumpTick += 1
        }
        if action == "waterSportAccel" || message["accelG"] != nil {
            if let g = Self.double(from: message, key: "accelG") {
                lastWatchAccelG = g
            }
        }
        if action == "requestPhoneSync" {
            Task { _ = await attemptSyncWithWatch() }
        }
        if action == "watchStartedSession" {
            mirrorWatchStartedSession(message)
        }
        if action == "watchStoppedSession" {
            isWorkoutActiveOnWatch = false
            isWatchSessionPaused = false
            lastWorkoutName = ""
            clearWatchMetrics()
            refreshConnectionStatus()
            if workoutStore?.sessionOriginatedFromWatch == true {
                workoutStore?.endSessionMirroredFromWatch()
                watchForcedSessionCloseTick += 1
            }
        }
        if action == "watchPausedSession" {
            isWatchSessionPaused = true
            workoutStore?.setExerciseTimerPaused(true)
            refreshConnectionStatus()
        }
        if action == "watchResumedSession" {
            isWatchSessionPaused = false
            isWorkoutActiveOnWatch = true
            workoutStore?.setExerciseTimerPaused(false)
            refreshConnectionStatus()
        }

        HealthKitManager.shared.applyLiveWatchMetrics(
            heartRate: heartRate,
            calories: calories,
            steps: steps
        )
    }

    /// Abre no iPhone o treino/cardio/meditação iniciado no Apple Watch pareado.
    private func mirrorWatchStartedSession(_ message: [String: Any]) {
        isWorkoutActiveOnWatch = true
        isWatchSessionPaused = false
        if let name = message["workoutName"] as? String {
            lastWorkoutName = name
        }
        refreshConnectionStatus()

        let timestamp = (message["timestamp"] as? TimeInterval)
            ?? (message["timestamp"] as? NSNumber)?.doubleValue
            ?? Date().timeIntervalSince1970
        // Evita processar a mesma mensagem duas vezes (sendMessage + transferUserInfo).
        if abs(timestamp - lastMirroredWatchStartAt) < 1.5 {
            return
        }
        lastMirroredWatchStartAt = timestamp

        let kind = (message["kind"] as? String) ?? "strength"
        let workoutName = (message["workoutName"] as? String) ?? lastWorkoutName
        let exerciseName = (message["exerciseName"] as? String) ?? ""
        let targetSeconds = (message["targetSeconds"] as? Int)
            ?? (message["targetSeconds"] as? NSNumber)?.intValue
            ?? 0
        let waterMode = (message["waterSportMode"] as? Bool)
            ?? ((message["waterSportMode"] as? NSNumber)?.boolValue ?? false)
        let kite = (message["isKitesurf"] as? Bool)
            ?? ((message["isKitesurf"] as? NSNumber)?.boolValue ?? false)
        let swimMode = (message["swimmingMode"] as? Bool)
            ?? ((message["swimmingMode"] as? NSNumber)?.boolValue ?? false)
        let topicIcon = (message["topicIcon"] as? String) ?? "brain.head.profile"
        let colorName = (message["colorName"] as? String) ?? "purple"
        let autoDetected = (message["autoDetected"] as? Bool)
            ?? ((message["autoDetected"] as? NSNumber)?.boolValue ?? false)

        guard let workoutStore else {
            #if DEBUG
            print("[HealthFit] watchStartedSession sem WorkoutStore ligado — abra o app no iPhone")
            #endif
            return
        }

        let started = workoutStore.startSessionFromAppleWatch(
            kind: kind,
            workoutName: workoutName,
            exerciseName: exerciseName,
            targetSeconds: targetSeconds,
            waterSportMode: waterMode,
            isKitesurf: kite,
            swimmingMode: swimMode,
            topicIcon: topicIcon,
            colorName: colorName,
            waterSetupModeName: (message["waterSetupModeName"] as? String) ?? "",
            waterSetupBoardName: (message["waterSetupBoardName"] as? String) ?? "",
            autoDetected: autoDetected
        )

        if started {
            NotificationService.shared.deliverWorkoutStartNotification(
                workoutTitle: autoDetected ? "\(workoutName) (detectado no Watch)" : workoutName,
                athleteName: "Atleta"
            )
        }
    }
}
