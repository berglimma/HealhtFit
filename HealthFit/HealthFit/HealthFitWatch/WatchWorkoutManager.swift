import Foundation
import WatchConnectivity
import HealthKit
import Combine
import UserNotifications
import WatchKit
import CoreMotion
import CoreLocation

@MainActor
final class WatchWorkoutManager: NSObject, ObservableObject {
    static let shared = WatchWorkoutManager()

    @Published var isActive = false
    @Published var workoutName = ""
    @Published var isCardioWorkout = false
    @Published var isMeditationWorkout = false
    @Published var workoutElapsedSeconds = 0
    @Published var exerciseElapsedSeconds = 0
    @Published var currentExerciseName = ""
    @Published var cardioTargetSeconds = 0
    @Published var cardioTargetCalories = 0
    @Published var cardioSuperationMessage = ""
    @Published var meditationTargetSeconds = 0
    @Published var meditationTopicName = ""
    @Published var meditationTopicIcon = "brain.head.profile"
    @Published var meditationColorName = "purple"
    @Published var meditationPrompt = ""
    @Published var meditationPromptIndex = 0
    @Published var meditationTotalPrompts = 1
    @Published var heartRate: Double = 0
    @Published var calories: Double = 0
    @Published var todaySteps: Int = 0
    /// Momento da última amostra de BPM aceita (builder ou query recente).
    private var lastHeartRateSampleAt: Date?
    /// Idade máxima da amostra de BPM para ainda ser considerada “ao vivo”.
    private static let heartRateSampleMaxAge: TimeInterval = 10
    @Published var restRemainingSeconds = 0
    @Published var isResting = false
    @Published var isRestOvertime = false
    @Published var restExerciseName = ""
    @Published var restOvertimeSeconds = 0
    @Published var isWaterSportMode = false
    @Published var isKitesurfMode = false
    @Published var spotBuddyEnabled = false
    @Published var spotBuddyPeers: [KiteSpotBuddyPeer] = []
    @Published var spotBuddyNeedsHelp = false
    @Published var spotBuddyIncomingHelp: KiteSpotBuddyPeer?
    @Published var spotBuddyMyLatitude: Double?
    @Published var spotBuddyMyLongitude: Double?
    /// Detecção automática de escalada ligada pelo usuário.
    @Published var isClimbingAutoDetectEnabled = false {
        didSet {
            UserDefaults.standard.set(isClimbingAutoDetectEnabled, forKey: Self.climbingAutoDetectKey)
            if isClimbingAutoDetectEnabled {
                startClimbingDetection()
            } else {
                stopClimbingDetection()
            }
        }
    }
    @Published var climbingDetectionStatus = ""
    /// Rótulo de setup (modo kite / prancha surf) — espelha sessão Surf no iPhone.
    @Published var waterSetupModeName = ""
    @Published var waterSetupBoardName = ""
    @Published var waterJumpCount = 0
    @Published var waterMaxJumpMeters: Double = 0
    @Published var waterLiveAccelG: Double = 1
    @Published var waterLastJumpMeters: Double = 0
    @Published var waterRelativeAltitude: Double = 0
    @Published var waterSensorStatus = ""
    @Published var isSwimmingMode = false
    @Published var poolLengthMeters: Double = 25
    @Published var swimLapCount = 0
    @Published var swimDistanceMeters: Double = 0
    @Published var watchSyncStatus = ""
    @Published var isPhoneReachable = false
    @Published var isPaused = false
    /// Último salto detectado automaticamente (giroscópio / acelerômetro).
    @Published var lastAutoJumpNote = ""
    /// Última posição GPS do Watch (Surf / Kitesurf) — usada no Spot Buddy e no mapa.
    @Published var waterGPSLatitude: Double?
    @Published var waterGPSLongitude: Double?
    @Published var waterGPSPointCount: Int = 0
    /// Ejeção de água do alto-falante (Surf / Kite / Natação).
    @Published var isEjectingWater = false
    @Published var waterEjectionStatus = ""
    /// Cronômetro circular segmentado (caminhada / corrida / bike / MTB).
    @Published var usesSegmentedChronometer = false
    @Published var chronometerPerformance: WatchChronometerPerformance = .unknown
    @Published var chronometerSecondaryText = ""
    @Published var cardioDistanceMeters: Double = 0
    @Published var currentSpeedMps: Double = 0

    private var session: WCSession?
    private var heartRateTimer: Timer?
    private var workoutClockTimer: Timer?
    private var restTimer: Timer?
    private var configuredRestSeconds = 60
    private var restElapsedSeconds = 0
    private var secondsSincePhoneSync = 0
    /// Ignora `stopWorkout` atrasado que chega depois de um start mais novo.
    private var lastPhoneStartTimestamp: TimeInterval = 0
    /// Ignora `start*` atrasado (fila transferUserInfo) depois de um stop do iPhone.
    private var lastPhoneStopTimestamp: TimeInterval = 0
    private var hasSentRestOvertimeNotification = false
    private var workoutStartedAt: Date?
    private var localMeditationPrompts: [String] = []
    private var meditationOwnedByWatch = false
    /// Detecção de salto (motion + giroscópio do DeviceMotion).
    private var isInAir = false
    private var possibleTakeoffAltitude: Double?
    private var possibleTakeoffTime: Date?
    private var peakGDuringAir: Double = 1
    private var peakGyroDuringAir: Double = 0
    private var lastAutoJumpAt: Date = .distantPast
    private var lastAccelSendAt: Date = .distantPast
    private let healthStore = HKHealthStore()
    private let motionManager = CMMotionManager()
    /// Manager dedicado à detecção de escalada, para não disputar o de esportes de água.
    private let climbingDetectionManager = CMMotionManager()
    private var climbingSignalSince: Date?
    private var waterPeakG: Double = 1
    private var waterBaselineAltitude: Double?
    private let altimeter = CMAltimeter()
    /// GPS do Watch para Surf / Kitesurf (iPhone fica em terra).
    private let waterLocationManager = CLLocationManager()
    private var waterGPSPendingBatch: [[String: Double]] = []
    private var lastWaterGPSAccepted: CLLocation?
    private var lastWaterGPSFlushAt: Date = .distantPast
    private var isWaterGPSTracking = false
    /// GPS leve para ritmo/velocidade do cronômetro segmentado (terra).
    private var isLandCardioGPSTracking = false
    private var landCardioRecentSpeeds: [Double] = []
    private var lastLandDistanceMeters: Double = 0
    private var lastLandDistanceAt: Date?
    private var isBikeStyleCardio = false
    private var hkWorkoutSession: HKWorkoutSession?
    private var hkLiveBuilder: HKLiveWorkoutBuilder?
    private var swimEventLapCount = 0
    private var lastSwimMetricsSentAt: Date = .distantPast
    /// Safe hop for nonisolated HK/WC callbacks (no captured `var self`).
    nonisolated(unsafe) private var mainActorBox: WeakMainActorBox<WatchWorkoutManager>?

    private static let landMovingSpeedFloor = 0.4
    private static let landBelowRatio = 0.90
    private static let landOptimalRatio = 1.10

        override init() {
        super.init()
        mainActorBox = WeakMainActorBox(self)
        waterLocationManager.delegate = self
        waterLocationManager.desiredAccuracy = kCLLocationAccuracyBest
        waterLocationManager.distanceFilter = 5
        waterLocationManager.activityType = .fitness
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
        // O observador de propriedade não dispara dentro do init, então liga na mão.
        isClimbingAutoDetectEnabled = UserDefaults.standard.bool(forKey: Self.climbingAutoDetectKey)
        startClimbingDetection()
    }

    // MARK: - Detecção automática de escalada

    private static let climbingAutoDetectKey = "healthfit.watch.climbingAutoDetect"

    /// Movimento sustentado necessário antes de abrir a sessão sozinho.
    private static let climbingDetectionWindow: TimeInterval = 90

    /// Monitora o movimento em segundo plano procurando o padrão de escalada.
    ///
    /// Roda a 5 Hz num manager próprio, separado do de esportes de água, para não
    /// competir com a detecção de saltos durante uma sessão de surf.
    func startClimbingDetection() {
        guard isClimbingAutoDetectEnabled, !isActive else { return }
        guard climbingDetectionManager.isDeviceMotionAvailable else {
            climbingDetectionStatus = "Sensores indisponíveis"
            return
        }
        guard !climbingDetectionManager.isDeviceMotionActive else { return }

        climbingSignalSince = nil
        climbingDetectionStatus = "Monitorando movimento"

        let box = WeakMainActorBox(self)
        climbingDetectionManager.deviceMotionUpdateInterval = 0.2
        climbingDetectionManager.startDeviceMotionUpdates(to: .main) { data, _ in
            guard let data else { return }
            box.run { this in
                this.evaluateClimbingSignal(data)
            }
        }
    }

    func stopClimbingDetection() {
        guard climbingDetectionManager.isDeviceMotionActive else { return }
        climbingDetectionManager.stopDeviceMotionUpdates()
        climbingSignalSince = nil
        climbingDetectionStatus = ""
    }

    private func evaluateClimbingSignal(_ data: CMDeviceMotion) {
        guard isClimbingAutoDetectEnabled, !isActive else {
            stopClimbingDetection()
            return
        }

        let accel = data.userAcceleration
        let rotation = data.rotationRate
        let accelMagnitude = sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z)
        let gyroMagnitude = sqrt(
            rotation.x * rotation.x + rotation.y * rotation.y + rotation.z * rotation.z
        )

        // Escalada: braço acima do ombro com rotação frequente e aceleração moderada.
        // O eixo Z da gravidade fica próximo de zero quando o antebraço está na vertical.
        let armRaised = abs(data.gravity.z) < 0.55
        let isClimbingLike = armRaised
            && (accelMagnitude > 0.10 || gyroMagnitude > 0.5)
            && accelMagnitude < 1.2 // acima disso é corrida ou impacto, não escalada

        guard isClimbingLike else {
            climbingSignalSince = nil
            climbingDetectionStatus = "Monitorando movimento"
            return
        }

        guard let since = climbingSignalSince else {
            climbingSignalSince = Date()
            return
        }

        let sustained = Date().timeIntervalSince(since)
        guard sustained >= Self.climbingDetectionWindow else {
            climbingDetectionStatus = String(
                format: "Possível escalada… %.0fs", Self.climbingDetectionWindow - sustained
            )
            return
        }

        autoStartClimbing()
    }

    private func autoStartClimbing() {
        guard !isActive else { return }
        stopClimbingDetection()

        guard let activity = WatchCatalog.cardioActivities.first(where: { $0.id == "climb" }) else {
            return
        }

        let title = activity.name
        startCardio(
            name: title,
            targetSeconds: 0,
            exerciseName: activity.name,
            targetCalories: 0
        )
        notifyPhoneWatchStarted(
            kind: "cardio",
            workoutName: title,
            exerciseName: activity.name,
            autoDetected: true
        )
        climbingDetectionStatus = "Sessão de escalada iniciada automaticamente"
    }

    func startWorkout(name: String, exerciseName: String = "") {
        resetWorkoutState()
        meditationOwnedByWatch = false
        localMeditationPrompts = []
        workoutName = name
        currentExerciseName = exerciseName
        isCardioWorkout = false
        isMeditationWorkout = false
        isActive = true
        startLiveWorkoutSession(activityType: .traditionalStrengthTraining, locationType: .indoor)
        startHeartRateMonitoring()
        startWorkoutClock()
    }

    /// Inicia programa de musculação/casa/mobilidade escolhido no Watch.
    func beginLocalStrength(_ program: WatchCatalog.StrengthProgram) {
        startWorkout(name: program.title, exerciseName: program.firstExercise)
        notifyPhoneWatchStarted(
            kind: "strength",
            workoutName: program.title,
            exerciseName: program.firstExercise
        )
        WKInterfaceDevice.current().play(.start)
    }

    /// Inicia cardio escolhido no Watch (com duração alvo opcional).
    func beginLocalCardio(_ activity: WatchCatalog.CardioActivity, targetSeconds: Int) {
        beginLocalCardio(
            activity,
            targetSeconds: targetSeconds,
            setupModeName: "",
            setupBoardName: ""
        )
    }

    /// Inicia água (Surf / Kitesurf) com setup opcional — mesmo espírito da sessão Surf no iPhone.
    func beginLocalCardio(
        _ activity: WatchCatalog.CardioActivity,
        targetSeconds: Int,
        setupModeName: String,
        setupBoardName: String
    ) {
        let title = activity.name
        startCardio(
            name: title,
            targetSeconds: targetSeconds,
            exerciseName: activity.name,
            targetCalories: 0,
            waterSportMode: activity.isWaterSport,
            isKitesurf: activity.isKitesurf,
            swimmingMode: activity.isSwimming,
            poolLengthMeters: activity.isSwimming ? 25 : 25,
            setupModeName: setupModeName,
            setupBoardName: setupBoardName
        )
        notifyPhoneWatchStarted(
            kind: "cardio",
            workoutName: title,
            exerciseName: activity.name,
            targetSeconds: targetSeconds,
            waterSportMode: activity.isWaterSport,
            isKitesurf: activity.isKitesurf,
            swimmingMode: activity.isSwimming,
            waterSetupModeName: setupModeName,
            waterSetupBoardName: setupBoardName
        )
        WKInterfaceDevice.current().play(.start)
    }

    func startCardio(
        name: String,
        targetSeconds: Int,
        exerciseName: String,
        targetCalories: Int = 0,
        waterSportMode: Bool = false,
        isKitesurf: Bool = false,
        swimmingMode: Bool = false,
        poolLengthMeters: Double = 25,
        setupModeName: String = "",
        setupBoardName: String = "",
        spotBuddyEnabled: Bool = false,
        locationOutdoor: Bool = false,
        activityTypeRaw: UInt? = nil
    ) {
        resetWorkoutState()
        meditationOwnedByWatch = false
        localMeditationPrompts = []
        workoutName = name
        isCardioWorkout = true
        isMeditationWorkout = false
        isWaterSportMode = waterSportMode
        isKitesurfMode = isKitesurf
        self.spotBuddyEnabled = spotBuddyEnabled && isKitesurf
        isSwimmingMode = swimmingMode
        self.poolLengthMeters = max(poolLengthMeters, 1)
        cardioTargetSeconds = max(targetSeconds, 0)
        cardioTargetCalories = max(targetCalories, 0)
        currentExerciseName = exerciseName
        waterSetupModeName = setupModeName
        waterSetupBoardName = setupBoardName
        isActive = true
        let activity = Self.resolveCardioActivityType(
            activityTypeRaw: activityTypeRaw,
            exerciseName: exerciseName,
            swimmingMode: swimmingMode,
            waterSportMode: waterSportMode,
            isKitesurf: isKitesurf
        )
        usesSegmentedChronometer = Self.shouldUseSegmentedChronometer(
            exerciseName: exerciseName,
            swimmingMode: swimmingMode,
            waterSportMode: waterSportMode
        )
        isBikeStyleCardio = Self.isBikeStyleCardio(exerciseName: exerciseName)
        let outdoor = locationOutdoor
            || swimmingMode
            || waterSportMode
            || usesSegmentedChronometer
            || [.walking, .running, .cycling, .rowing, .hiking].contains(activity)
        startLiveWorkoutSession(
            activityType: activity,
            locationType: outdoor ? .outdoor : .indoor,
            swimmingMode: swimmingMode
        )
        startHeartRateMonitoring()
        startWorkoutClock()
        if waterSportMode {
            startWaterSportMotion()
            startWaterSportGPS()
        }
        if usesSegmentedChronometer {
            startLandCardioGPS()
        }
    }

    /// Caminhada, corrida, bike e mountain bike — anel segmentado com cor por desempenho.
    private static func shouldUseSegmentedChronometer(
        exerciseName: String,
        swimmingMode: Bool,
        waterSportMode: Bool
    ) -> Bool {
        if swimmingMode || waterSportMode { return false }
        let name = exerciseName.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        if name.contains("ergometr") || name.contains("indoor") { return false }
        if name.contains("corrida") || name.contains("run") || name.contains("esteira") { return true }
        if name.contains("caminh") || name.contains("walk") { return true }
        if name.contains("mountain") || name.contains("mtb") { return true }
        if name.contains("bike") || name.contains("cicl") || name.contains("bicicleta") { return true }
        return false
    }

    private static func isBikeStyleCardio(exerciseName: String) -> Bool {
        let name = exerciseName.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        return name.contains("bike")
            || name.contains("cicl")
            || name.contains("bicicleta")
            || name.contains("mountain")
            || name.contains("mtb")
    }

    /// Inicia meditação escolhida no Watch.
    func beginLocalMeditation(_ topic: WatchCatalog.MeditationTopic, targetSeconds: Int) {
        localMeditationPrompts = topic.prompts
        meditationOwnedByWatch = true
        startMeditation(
            name: topic.name,
            targetSeconds: targetSeconds,
            topicName: topic.name,
            topicIcon: topic.icon,
            colorName: topic.colorName,
            currentPrompt: topic.prompts.first ?? "",
            promptIndex: 0,
            totalPrompts: max(topic.prompts.count, 1)
        )
        notifyPhoneWatchStarted(
            kind: "meditation",
            workoutName: topic.name,
            exerciseName: topic.name,
            targetSeconds: targetSeconds,
            topicIcon: topic.icon,
            colorName: topic.colorName
        )
        WKInterfaceDevice.current().play(.start)
    }

    func startMeditation(
        name: String,
        targetSeconds: Int,
        topicName: String,
        topicIcon: String,
        colorName: String,
        currentPrompt: String,
        promptIndex: Int,
        totalPrompts: Int
    ) {
        // Se prompts locais já foram definidos em beginLocalMeditation, preserve-os.
        if !meditationOwnedByWatch {
            localMeditationPrompts = []
        }
        resetWorkoutStateKeepingMeditationOwnership()
        workoutName = name
        isCardioWorkout = false
        isMeditationWorkout = true
        meditationTargetSeconds = max(targetSeconds, 1)
        meditationTopicName = topicName
        meditationTopicIcon = topicIcon
        meditationColorName = colorName
        meditationPrompt = currentPrompt
        meditationPromptIndex = max(promptIndex, 0)
        meditationTotalPrompts = max(totalPrompts, 1)
        isActive = true
        startLiveWorkoutSession(activityType: .mindAndBody, locationType: .indoor)
        startHeartRateMonitoring()
        startWorkoutClock()
    }

    /// Marca salto manual (backup). Preferência: detecção automática por sensores.
    func markWaterSportJump() {
        guard isActive, isWaterSportMode, !isPaused else { return }
        let height = max(0.4, max(waterRelativeAltitude * 0.9, estimatedHeightFromPeakG()))
        let peak = max(waterPeakG, waterLiveAccelG)
        registerWaterJump(heightMeters: height, peakG: peak, airtime: nil, automatic: false)
    }

    func togglePause() {
        guard isActive else { return }
        setPaused(!isPaused, notifyPhone: true)
    }

    /// Pausa/retoma alinhado ao iPhone (ou ao botão do Watch).
    func setPaused(_ paused: Bool, notifyPhone: Bool) {
        guard isActive, isPaused != paused else { return }
        isPaused = paused
        if isPaused {
            resetAirborneJumpState()
            if usesSegmentedChronometer {
                chronometerPerformance = .paused
            }
            hkWorkoutSession?.pause()
            WKInterfaceDevice.current().play(.stop)
            if notifyPhone {
                sendToPhone([
                    "action": "watchPausedSession",
                    "timestamp": Date().timeIntervalSince1970
                ])
            }
            watchSyncStatus = "Pausado"
        } else {
            if usesSegmentedChronometer, chronometerPerformance == .paused {
                chronometerPerformance = landCardioRecentSpeeds.count >= 3 ? .fair : .unknown
            }
            hkWorkoutSession?.resume()
            WKInterfaceDevice.current().play(.start)
            if notifyPhone {
                sendToPhone([
                    "action": "watchResumedSession",
                    "timestamp": Date().timeIntervalSince1970
                ])
            }
            watchSyncStatus = "Em andamento"
        }
    }

    func requestPhoneSyncFromWatch() {
        sendToPhone([
            "action": "requestPhoneSync",
            "timestamp": Date().timeIntervalSince1970
        ])
        sendMetricsToPhone()
        watchSyncStatus = "Sincronizando…"
    }

    /// Toca tons no speaker do Watch para retirar água (esportes aquáticos).
    func ejectWaterFromSpeaker() {
        guard !isEjectingWater else { return }
        isEjectingWater = true
        waterEjectionStatus = "Ejetando água do alto-falante…"
        WatchWaterEjection.shared.play { [weak self] in
            guard let self else { return }
            self.isEjectingWater = false
            self.waterEjectionStatus = "Água ejetada"
            self.watchSyncStatus = "Água ejetada do speaker"
        }
    }

    func stopWorkout() {
        isActive = false
        isPaused = false
        isCardioWorkout = false
        isMeditationWorkout = false
        meditationOwnedByWatch = false
        localMeditationPrompts = []
        lastPhoneStopTimestamp = max(lastPhoneStopTimestamp, Date().timeIntervalSince1970)
        stopWaterSportMotion()
        stopWaterSportGPS(flush: true)
        stopLandCardioGPS()
        stopLiveWorkoutSession()
        heartRateTimer?.invalidate()
        heartRateTimer = nil
        workoutClockTimer?.invalidate()
        workoutClockTimer = nil
        stopRestCountdown()
        sendToPhone([
            "action": "watchStoppedSession",
            "timestamp": Date().timeIntervalSince1970
        ])
        resetWorkoutState()
        sendMetricsToPhone()
        // Volta a vigiar assim que a sessão termina.
        startClimbingDetection()
    }

    private func resetWorkoutStateKeepingMeditationOwnership() {
        let keepPrompts = localMeditationPrompts
        let keepOwned = meditationOwnedByWatch
        resetWorkoutState()
        localMeditationPrompts = keepPrompts
        meditationOwnedByWatch = keepOwned
    }

    private func resetWorkoutState() {
        workoutElapsedSeconds = 0
        exerciseElapsedSeconds = 0
        currentExerciseName = ""
        cardioTargetSeconds = 0
        cardioTargetCalories = 0
        cardioSuperationMessage = ""
        meditationTargetSeconds = 0
        meditationTopicName = ""
        meditationTopicIcon = "brain.head.profile"
        meditationColorName = "purple"
        meditationPrompt = ""
        meditationPromptIndex = 0
        meditationTotalPrompts = 1
        if !meditationOwnedByWatch {
            localMeditationPrompts = []
        }
        calories = 0
        heartRate = 0
        lastHeartRateSampleAt = nil
        workoutStartedAt = nil
        secondsSincePhoneSync = 0
        isPaused = false
        isWaterSportMode = false
        isKitesurfMode = false
        spotBuddyEnabled = false
        spotBuddyPeers = []
        spotBuddyNeedsHelp = false
        spotBuddyIncomingHelp = nil
        spotBuddyMyLatitude = nil
        spotBuddyMyLongitude = nil
        waterGPSLatitude = nil
        waterGPSLongitude = nil
        waterGPSPointCount = 0
        waterSetupModeName = ""
        waterSetupBoardName = ""
        isSwimmingMode = false
        poolLengthMeters = 25
        swimLapCount = 0
        swimDistanceMeters = 0
        swimEventLapCount = 0
        waterJumpCount = 0
        waterMaxJumpMeters = 0
        waterLiveAccelG = 1
        waterLastJumpMeters = 0
        waterPeakG = 1
        waterRelativeAltitude = 0
        waterBaselineAltitude = nil
        waterSensorStatus = ""
        watchSyncStatus = ""
        lastAutoJumpNote = ""
        usesSegmentedChronometer = false
        chronometerPerformance = .unknown
        chronometerSecondaryText = ""
        cardioDistanceMeters = 0
        currentSpeedMps = 0
        landCardioRecentSpeeds = []
        lastLandDistanceMeters = 0
        lastLandDistanceAt = nil
        isBikeStyleCardio = false
        resetAirborneJumpState()
    }

    private func resetAirborneJumpState() {
        isInAir = false
        possibleTakeoffAltitude = nil
        possibleTakeoffTime = nil
        peakGDuringAir = 1
        peakGyroDuringAir = 0
    }

    private func registerWaterJump(
        heightMeters: Double,
        peakG: Double,
        airtime: TimeInterval?,
        automatic: Bool
    ) {
        let height = max(0.3, heightMeters)
        let peak = max(1, peakG)
        waterJumpCount += 1
        waterLastJumpMeters = height
        waterMaxJumpMeters = max(waterMaxJumpMeters, height)
        waterPeakG = 1
        if automatic {
            lastAutoJumpNote = String(format: "Salto auto · %.1f m", height)
            watchSyncStatus = lastAutoJumpNote
        } else {
            lastAutoJumpNote = String(format: "Salto manual · %.1f m", height)
        }
        WKInterfaceDevice.current().play(automatic ? .success : .click)
        var payload: [String: Any] = [
            "action": "waterSportJump",
            "heightMeters": height,
            "peakG": peak,
            "timestamp": Date().timeIntervalSince1970,
            "source": automatic ? "gyro" : "manual"
        ]
        if let airtime {
            payload["airtimeSeconds"] = airtime
        } else {
            payload["airtimeSeconds"] = 0.0
        }
        sendToPhone(payload)
    }

    /// Confirma ao iPhone que a sessão está ativa na tela do Watch.
    private func sendWatchAckStarted(kind: String, workoutName: String, playHaptic: Bool = true) {
        sendToPhone([
            "action": "watchAckStarted",
            "kind": kind,
            "workoutName": workoutName.isEmpty ? self.workoutName : workoutName,
            "timestamp": Date().timeIntervalSince1970
        ])
        if playHaptic {
            WKInterfaceDevice.current().play(.start)
        }
    }

    private func notifyPhoneWatchStarted(
        kind: String,
        workoutName: String,
        exerciseName: String,
        targetSeconds: Int = 0,
        waterSportMode: Bool = false,
        isKitesurf: Bool = false,
        swimmingMode: Bool = false,
        topicIcon: String = "",
        colorName: String = "",
        waterSetupModeName: String = "",
        waterSetupBoardName: String = "",
        autoDetected: Bool = false
    ) {
        var payload: [String: Any] = [
            "action": "watchStartedSession",
            "kind": kind,
            "workoutName": workoutName,
            "exerciseName": exerciseName,
            "targetSeconds": targetSeconds,
            "timestamp": Date().timeIntervalSince1970
        ]
        if kind == "cardio" {
            payload["waterSportMode"] = waterSportMode
            payload["isKitesurf"] = isKitesurf
            payload["swimmingMode"] = swimmingMode
            payload["autoDetected"] = autoDetected
            if !waterSetupModeName.isEmpty {
                payload["waterSetupModeName"] = waterSetupModeName
            }
            if !waterSetupBoardName.isEmpty {
                payload["waterSetupBoardName"] = waterSetupBoardName
            }
        }
        if kind == "meditation" {
            payload["topicIcon"] = topicIcon
            payload["colorName"] = colorName
        }
        sendToPhone(payload)
        // Métricas logo após o início (BPM/kcal).
        sendMetricsToPhone()
        refreshPhoneReachability()
    }

    private func refreshPhoneReachability() {
        isPhoneReachable = session?.isReachable == true && session?.activationState == .activated
    }

    private func startWorkoutClock() {
        workoutClockTimer?.invalidate()
        secondsSincePhoneSync = 0
        let clockBox = WeakMainActorBox(self)
        workoutClockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            clockBox.run { this in
                this.tickWorkoutClock()
            }
        }
    }

    private func tickWorkoutClock() {
        guard isActive, !isPaused else { return }
        secondsSincePhoneSync += 1

        guard secondsSincePhoneSync > 2, !isResting else { return }
        workoutElapsedSeconds += 1
        if !isCardioWorkout && !isMeditationWorkout {
            exerciseElapsedSeconds += 1
        }
        advanceLocalMeditationPromptIfNeeded()
    }

    /// Rotaciona prompts da meditação iniciada no próprio Watch.
    private func advanceLocalMeditationPromptIfNeeded() {
        guard isMeditationWorkout, meditationOwnedByWatch, !localMeditationPrompts.isEmpty else { return }
        let total = max(localMeditationPrompts.count, 1)
        let slice = max(meditationTargetSeconds / total, 1)
        let index = min(workoutElapsedSeconds / slice, total - 1)
        if index != meditationPromptIndex {
            meditationPromptIndex = index
            meditationPrompt = localMeditationPrompts[index]
            meditationTotalPrompts = total
            WKInterfaceDevice.current().play(.click)
        }
    }

    private func applyPhoneSync(
        workoutElapsedSeconds: Int? = nil,
        exerciseElapsedSeconds: Int? = nil,
        exerciseName: String? = nil,
        targetSeconds: Int? = nil,
        targetCalories: Int? = nil,
        currentCalories _: Double? = nil,
        meditationPrompt: String? = nil,
        promptIndex: Int? = nil
    ) {
        secondsSincePhoneSync = 0
        if let workoutElapsedSeconds {
            self.workoutElapsedSeconds = workoutElapsedSeconds
        }
        if let exerciseElapsedSeconds {
            self.exerciseElapsedSeconds = exerciseElapsedSeconds
        }
        if let exerciseName, !exerciseName.isEmpty {
            currentExerciseName = exerciseName
        }
        if let targetSeconds, targetSeconds > 0 {
            if isMeditationWorkout {
                meditationTargetSeconds = targetSeconds
            } else {
                cardioTargetSeconds = targetSeconds
            }
        }
        if let targetCalories, targetCalories > 0 {
            cardioTargetCalories = targetCalories
        }
        // Ignora currentCalories vindas do iPhone — calorias só do HealthKit do Watch.
        if let meditationPrompt, !meditationPrompt.isEmpty {
            self.meditationPrompt = meditationPrompt
        }
        if let promptIndex {
            meditationPromptIndex = promptIndex
        }
    }

    private func applyPhonePausedFlag(_ message: [String: Any]) {
        let paused = (message["isPaused"] as? Bool)
            ?? (message["isPaused"] as? NSNumber)?.boolValue
        guard let paused else { return }
        setPaused(paused, notifyPhone: false)
    }

    /// iPhone pediu abertura do app Watch (`startWatchApp`) — sobe a tela de atividade.
    func handleHealthKitLaunch(configuration: HKWorkoutConfiguration) {
        // Preferência: contexto WCSession (pode ser stop recente — não reabrir).
        if let context = session?.receivedApplicationContext,
           let action = context["action"] as? String {
            if action == "stopWorkout" {
                handlePhoneMessage(context)
                return
            }
            if ["startWorkout", "startCardio", "startMeditation"].contains(action) {
                handlePhoneMessage(context)
                WKInterfaceDevice.current().play(.start)
                return
            }
        }

        if isActive {
            // Não prende em sessão genérica do launch — deixa o start* do iPhone substituir.
            sendWatchAckStarted(
                kind: isMeditationWorkout ? "meditation" : (isCardioWorkout ? "cardio" : "strength"),
                workoutName: workoutName,
                playHaptic: false
            )
            // Ainda tenta aplicar o contexto do iPhone se já chegou.
            if let context = session?.receivedApplicationContext,
               let action = context["action"] as? String,
               ["startWorkout", "startCardio", "startMeditation"].contains(action) {
                handlePhoneMessage(context)
            }
            return
        }

        notePhoneStart(timestamp: Date().timeIntervalSince1970)

        switch configuration.activityType {
        case .mindAndBody:
            startMeditation(
                name: "Meditação",
                targetSeconds: 0,
                topicName: "Meditação",
                topicIcon: "brain.head.profile",
                colorName: "purple",
                currentPrompt: "",
                promptIndex: 0,
                totalPrompts: 1
            )
            sendWatchAckStarted(kind: "meditation", workoutName: "Meditação")
        case .traditionalStrengthTraining, .functionalStrengthTraining, .highIntensityIntervalTraining:
            startWorkout(name: "Treino", exerciseName: "")
            sendWatchAckStarted(kind: "strength", workoutName: "Treino")
        default:
            let swimming = configuration.activityType == .swimming
            let name: String = {
                switch configuration.activityType {
                case .walking: return "Caminhada"
                case .running: return "Corrida"
                case .cycling: return "Ciclismo"
                case .swimming: return "Natação"
                case .rowing: return "Remo"
                case .climbing: return "Escalada"
                case .martialArts: return "Luta"
                case .paddleSports: return "Kitesurf"
                case .surfingSports: return "Surf"
                default: return "Cardio"
                }
            }()
            startCardio(
                name: name,
                targetSeconds: 0,
                exerciseName: name,
                swimmingMode: swimming,
                poolLengthMeters: configuration.lapLength?.doubleValue(for: .meter()) ?? 25
            )
            sendWatchAckStarted(kind: "cardio", workoutName: name)
        }
        WKInterfaceDevice.current().play(.start)
    }

    func handleActiveWorkoutRecovery() {
        guard !isActive else { return }
        if let context = session?.receivedApplicationContext,
           let action = context["action"] as? String,
           ["startWorkout", "startCardio", "startMeditation"].contains(action) {
            handlePhoneMessage(context)
        }
    }

    private func notePhoneStart(timestamp: TimeInterval) {
        guard timestamp > 0 else {
            lastPhoneStartTimestamp = max(lastPhoneStartTimestamp, Date().timeIntervalSince1970)
            return
        }
        lastPhoneStartTimestamp = max(lastPhoneStartTimestamp, timestamp)
    }

    private func notePhoneStop(timestamp: TimeInterval) {
        if timestamp > 0 {
            lastPhoneStopTimestamp = max(lastPhoneStopTimestamp, timestamp)
        } else {
            lastPhoneStopTimestamp = max(lastPhoneStopTimestamp, Date().timeIntervalSince1970)
        }
    }

    /// `start*` atrasado na fila WCSession após um stop do iPhone — não reabre o treino.
    private func shouldIgnoreStalePhoneStart(timestamp: TimeInterval) -> Bool {
        guard lastPhoneStopTimestamp > 0 else { return false }
        if timestamp <= 0 {
            // Sem timestamp: ignore se paramos recentemente (fila / simulador).
            return Date().timeIntervalSince1970 - lastPhoneStopTimestamp < 45
        }
        return timestamp < lastPhoneStopTimestamp
    }

    private static func timeInterval(from message: [String: Any], key: String) -> TimeInterval? {
        if let value = message[key] as? TimeInterval { return value }
        if let number = message[key] as? NSNumber { return number.doubleValue }
        return nil
    }

    private func updateCalorieSuperation() {
        guard isCardioWorkout, cardioTargetCalories > 0 else {
            cardioSuperationMessage = ""
            return
        }
        if calories >= Double(cardioTargetCalories) {
            if cardioSuperationMessage.isEmpty {
                cardioSuperationMessage = "Meta ok! Toque Encerrar p/ finalizar"
                WKInterfaceDevice.current().play(.success)
            }
        } else {
            cardioSuperationMessage = ""
        }
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

        let restBox = WeakMainActorBox(self)
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            restBox.run { this in
                this.tickRest()
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
        WKInterfaceDevice.current().play(.notification)
    }

    private func deliverSyncedNotification(title: String, body: String, category: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if !category.isEmpty {
            content.categoryIdentifier = category
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "watch_\(identifier)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func syncDailyMotivationFromPhone(_ entries: [[String: Any]]) {
        cancelDailyMotivationOnWatch()

        let calendar = Calendar.current
        for entry in entries {
            guard let identifier = entry["identifier"] as? String,
                  let title = entry["title"] as? String,
                  let body = entry["body"] as? String,
                  let year = entry["year"] as? Int,
                  let month = entry["month"] as? Int,
                  let day = entry["day"] as? Int,
                  let hour = entry["hour"] as? Int,
                  let minute = entry["minute"] as? Int else { continue }

            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            components.hour = hour
            components.minute = minute

            guard let scheduledDate = calendar.date(from: components), scheduledDate > .now else { continue }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.categoryIdentifier = "DAILY_MOTIVATION"

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "watch_\(identifier)",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func cancelDailyMotivationOnWatch() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests
                .filter { $0.identifier.hasPrefix("watch_daily_motivation") }
                .map(\.identifier)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private func scheduleInactivityReminderOnWatch(
        title: String,
        body: String,
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        identifier: String
    ) {
        cancelInactivityReminderOnWatch()

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute

        let calendar = Calendar.current
        guard let scheduledDate = calendar.date(from: components), scheduledDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "WORKOUT_INACTIVITY"

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "watch_\(identifier)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelInactivityReminderOnWatch() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests
                .filter { $0.identifier.hasPrefix("watch_workout_inactivity") }
                .map(\.identifier)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private func tickRest() {
        guard !isPaused else { return }
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

    private func startHeartRateMonitoring() {
        requestHealthKitAuthorizationIfNeeded()
        if workoutStartedAt == nil {
            workoutStartedAt = Date()
        }
        fetchTodaySteps()
        heartRateTimer?.invalidate()
        let metricsBox = WeakMainActorBox(self)
        let timer = Timer(timeInterval: 2, repeats: true) { _ in
            metricsBox.run { this in
                // Builder já alimenta BPM; poll só se a amostra builder estiver velha.
                let builderFresh = this.lastHeartRateSampleAt
                    .map { Date().timeIntervalSince($0) < 5 } == true
                if !builderFresh {
                    this.fetchHeartRate()
                }
                this.fetchActiveCalories()
                this.fetchTodaySteps()
                this.applySimulatorMetricsIfNeeded()
                this.sendMetricsToPhone()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        heartRateTimer = timer
    }

    /// No simulador não há sensor óptico — gera BPM/kcal realistas para testar o sync.
    private func applySimulatorMetricsIfNeeded() {
        #if targetEnvironment(simulator)
        guard isActive else { return }
        if heartRate < 40 {
            heartRate = isMeditationWorkout
                ? Double.random(in: 58...72)
                : Double.random(in: 118...142)
            lastHeartRateSampleAt = Date()
        } else {
            let jitter = Double.random(in: -3...3)
            let base = isMeditationWorkout ? 65.0 : 130.0
            heartRate = min(175, max(50, heartRate + jitter * 0.4 + (base - heartRate) * 0.05))
            lastHeartRateSampleAt = Date()
        }
        let burnRate: Double = isMeditationWorkout ? 0.15 : (isCardioWorkout ? 1.1 : 0.7)
        calories += burnRate + Double.random(in: 0...0.25)
        if todaySteps == 0 {
            todaySteps = Int.random(in: 1200...4800)
        } else {
            todaySteps += Int.random(in: 0...8)
        }
        if isSwimmingMode {
            // ~1 volta a cada 40s no simulador (sem sensores de virada de piscina).
            let mockLaps = max(swimLapCount, max(0, workoutElapsedSeconds / 40))
            if mockLaps > swimLapCount {
                applySwimLapCount(mockLaps, distanceMeters: Double(mockLaps) * poolLengthMeters, source: "simulator")
            }
        }
        updateCalorieSuperation()
        #endif
    }

    private func requestHealthKitAuthorizationIfNeeded() {
        var readTypes = Set<HKObjectType>()
        var shareTypes = Set<HKSampleType>()
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
            readTypes.insert(heartRate)
            shareTypes.insert(heartRate)
        }
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            readTypes.insert(energy)
            shareTypes.insert(energy)
        }
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) {
            readTypes.insert(steps)
        }
        if let distanceSwim = HKObjectType.quantityType(forIdentifier: .distanceSwimming) {
            readTypes.insert(distanceSwim)
            shareTypes.insert(distanceSwim)
        }
        if let strokeCount = HKObjectType.quantityType(forIdentifier: .swimmingStrokeCount) {
            readTypes.insert(strokeCount)
            shareTypes.insert(strokeCount)
        }
        if let workout = HKObjectType.workoutType() as HKObjectType? {
            readTypes.insert(workout)
        }
        if let workoutSample = HKObjectType.workoutType() as HKSampleType? {
            shareTypes.insert(workoutSample)
        }
        guard !readTypes.isEmpty else { return }
        healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { _, _ in }
    }

    private func fetchHeartRate() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        // Em pausa não atualiza BPM — evita rebroadcast da última amostra congelada.
        guard !isPaused else { return }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        // Janela um pouco antes do start: o sensor pode entregar a 1ª amostra com atraso.
        let workoutStart = workoutStartedAt ?? Date()
        let start = workoutStart.addingTimeInterval(-120)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictEndDate)
        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { [box = WeakMainActorBox(self)] _, samples, _ in
            box.run { this in
                guard let sample = samples?.first as? HKQuantitySample else { return }
                let age = Date().timeIntervalSince(sample.endDate)
                guard age <= Self.heartRateSampleMaxAge else { return }
                let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                guard bpm > 0 else { return }
                this.heartRate = bpm
                this.lastHeartRateSampleAt = sample.endDate
            }
        }
        healthStore.execute(query)
    }

    private func fetchActiveCalories() {
        guard let start = workoutStartedAt,
              let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let query = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [box = WeakMainActorBox(self)] _, statistics, _ in
            box.run { this in
                if let sum = statistics?.sumQuantity() {
                    this.calories = sum.doubleValue(for: .kilocalorie())
                    this.updateCalorieSuperation()
                }
            }
        }
        healthStore.execute(query)
    }

    private func fetchTodaySteps() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let query = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [box = WeakMainActorBox(self)] _, statistics, _ in
            box.run { this in
                if let sum = statistics?.sumQuantity() {
                    this.todaySteps = Int(sum.doubleValue(for: .count()))
                }
            }
        }
        healthStore.execute(query)
    }

    private func sendMetricsToPhone() {
        guard let session else { return }
        let sampleAge = lastHeartRateSampleAt.map { Date().timeIntervalSince($0) } ?? .infinity
        let hrFresh = !isPaused && heartRate > 0 && sampleAge <= Self.heartRateSampleMaxAge
        var payload: [String: Any] = [
            // 0 = iPhone deve expirar BPM (não rebroadcast de valor travado).
            "heartRate": hrFresh ? heartRate : 0,
            "heartRateFresh": hrFresh,
            "calories": calories,
            "steps": todaySteps,
            "timestamp": Date().timeIntervalSince1970
        ]
        if let lastHeartRateSampleAt {
            payload["heartRateSampleAt"] = lastHeartRateSampleAt.timeIntervalSince1970
        }
        if isSwimmingMode {
            payload["action"] = "swimMetrics"
            payload["swimLapCount"] = swimLapCount
            payload["swimDistanceMeters"] = swimDistanceMeters
            payload["poolLengthMeters"] = poolLengthMeters
        }
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { _ in
                session.transferUserInfo(payload)
            }
        } else if session.activationState == .activated {
            session.transferUserInfo(payload)
        }
    }

    private func sendToPhone(_ payload: [String: Any]) {
        guard let session else { return }
        if session.activationState != .activated {
            session.activate()
        }
        // transferUserInfo entrega mesmo com o iPhone em background / app fechado.
        if session.activationState == .activated {
            session.transferUserInfo(payload)
        }
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { _ in
                // Já enfileirado em transferUserInfo acima
            }
        }
    }

    // MARK: - HKWorkoutSession (batimentos ópticos + kcal ao vivo)

    /// Sessão HealthKit em todos os treinos — necessária para o sensor óptico gerar BPM contínuo.
    private func startLiveWorkoutSession(
        activityType: HKWorkoutActivityType,
        locationType: HKWorkoutSessionLocationType,
        swimmingMode: Bool = false
    ) {
        stopLiveWorkoutSession()
        guard HKHealthStore.isHealthDataAvailable() else {
            watchSyncStatus = "HealthKit indisponível"
            return
        }
        requestHealthKitAuthorizationIfNeeded()

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = locationType
        if swimmingMode {
            configuration.swimmingLocationType = .pool
            configuration.lapLength = HKQuantity(unit: .meter(), doubleValue: max(poolLengthMeters, 1))
        }

        do {
            let hkSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = hkSession.associatedWorkoutBuilder()
            let dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
                dataSource.enableCollection(for: heartRateType, predicate: nil)
            }
            if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                dataSource.enableCollection(for: energyType, predicate: nil)
            }
            if let walkRun = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
                dataSource.enableCollection(for: walkRun, predicate: nil)
            }
            if let cycling = HKQuantityType.quantityType(forIdentifier: .distanceCycling) {
                dataSource.enableCollection(for: cycling, predicate: nil)
            }
            builder.dataSource = dataSource
            hkSession.delegate = self
            builder.delegate = self

            let start = Date()
            workoutStartedAt = start
            hkSession.startActivity(with: start)
            builder.beginCollection(withStart: start) { _, _ in }

            hkWorkoutSession = hkSession
            hkLiveBuilder = builder
            watchSyncStatus = swimmingMode ? "Natação · voltas automáticas" : "Watch · batimentos ativos"
            if swimmingMode {
                sendSwimMetricsToPhone(force: true)
            } else {
                sendMetricsToPhone()
            }
        } catch {
            watchSyncStatus = "Falha ao iniciar sessão HK"
            // Fallback: timer continua consultando amostras do HealthKit.
        }
    }

    private func stopLiveWorkoutSession() {
        guard let hkSession = hkWorkoutSession else {
            hkLiveBuilder = nil
            return
        }
        let end = Date()
        hkSession.end()
        if let builder = hkLiveBuilder {
            builder.endCollection(withEnd: end) { _, _ in
                builder.finishWorkout { _, _ in }
            }
        }
        hkWorkoutSession = nil
        hkLiveBuilder = nil
    }

    private static func resolveCardioActivityType(
        activityTypeRaw: UInt?,
        exerciseName: String,
        swimmingMode: Bool,
        waterSportMode: Bool,
        isKitesurf: Bool
    ) -> HKWorkoutActivityType {
        if let raw = activityTypeRaw, let typed = HKWorkoutActivityType(rawValue: raw), typed != .other {
            return typed
        }
        return cardioActivityType(
            exerciseName: exerciseName,
            swimmingMode: swimmingMode,
            waterSportMode: waterSportMode,
            isKitesurf: isKitesurf
        )
    }

    private static func cardioActivityType(
        exerciseName: String,
        swimmingMode: Bool,
        waterSportMode: Bool,
        isKitesurf: Bool
    ) -> HKWorkoutActivityType {
        if swimmingMode { return .swimming }
        if isKitesurf { return .paddleSports }
        if waterSportMode { return .surfingSports }

        let name = exerciseName.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        if name.contains("corrida") || name.contains("run") || name.contains("esteira") { return .running }
        if name.contains("caminh") || name.contains("walk") { return .walking }
        if name.contains("bike") || name.contains("cicl") || name.contains("cycling") { return .cycling }
        if name.contains("elip") || name.contains("elliptical") { return .elliptical }
        if name.contains("escal") || name.contains("climb") { return .climbing }
        if name.contains("remo") || name.contains("row") { return .rowing }
        if name.contains("corda") || name.contains("jump rope") || name.contains("pular") { return .jumpRope }
        if name.contains("escada") || name.contains("stair") { return .stairClimbing }
        if name.contains("hiit") || name.contains("burpee") || name.contains("polichinel") { return .highIntensityIntervalTraining }
        if name.contains("luta") || name.contains("fight") || name.contains("box") || name.contains("mma") { return .martialArts }
        if name.contains("surf") { return .surfingSports }
        if name.contains("kite") { return .paddleSports }
        if name.contains("yoga") || name.contains("pilates") || name.contains("mobil") { return .yoga }
        return .other
    }

    private func applySwimLapCount(_ laps: Int, distanceMeters: Double?, source: String) {
        let resolvedLaps = max(0, laps)
        if resolvedLaps > swimLapCount {
            swimLapCount = resolvedLaps
            if resolvedLaps > 0 {
                WKInterfaceDevice.current().play(.click)
            }
        }
        if let distanceMeters, distanceMeters > swimDistanceMeters {
            swimDistanceMeters = distanceMeters
        } else if swimLapCount > 0 {
            swimDistanceMeters = max(swimDistanceMeters, Double(swimLapCount) * poolLengthMeters)
        }
        _ = source
        sendSwimMetricsToPhone(force: false)
    }

    private func applySwimDistanceMeters(_ meters: Double) {
        guard meters >= 0 else { return }
        if meters > swimDistanceMeters {
            swimDistanceMeters = meters
        }
        let pool = max(poolLengthMeters, 1)
        let fromDistance = max(0, Int((meters / pool).rounded(.down)))
        if fromDistance > swimLapCount {
            applySwimLapCount(fromDistance, distanceMeters: meters, source: "distance")
        } else {
            sendSwimMetricsToPhone(force: false)
        }
    }


    private func sendSwimMetricsToPhone(force: Bool) {
        guard isSwimmingMode else { return }
        let now = Date()
        if !force, now.timeIntervalSince(lastSwimMetricsSentAt) < 1.5 {
            return
        }
        lastSwimMetricsSentAt = now
        sendToPhone([
            "action": "swimMetrics",
            "swimLapCount": swimLapCount,
            "swimDistanceMeters": swimDistanceMeters,
            "poolLengthMeters": poolLengthMeters,
            "heartRate": heartRate,
            "calories": calories,
            "steps": todaySteps,
            "timestamp": now.timeIntervalSince1970
        ])
    }

    private func startWaterSportMotion() {
        waterBaselineAltitude = nil
        waterRelativeAltitude = 0
        waterPeakG = 1
        resetAirborneJumpState()
        lastAutoJumpAt = .distantPast
        lastAccelSendAt = .distantPast
        lastAutoJumpNote = "Sensores de salto ativos"
        waterSensorStatus = "Giroscópio + acelerômetro + altímetro"
        let motionBox = WeakMainActorBox(self)
        if motionManager.isDeviceMotionAvailable {
            // ~20 Hz — acel. + giroscópio fundidos no DeviceMotion
            motionManager.deviceMotionUpdateInterval = 0.05
            motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { data, _ in
                guard let data else { return }
                motionBox.run { this in
                    this.handleWaterSportDeviceMotion(data)
                }
            }
        } else if motionManager.isGyroAvailable {
            // Fallback raro: só giroscópio
            motionManager.gyroUpdateInterval = 0.05
            motionManager.startGyroUpdates(to: .main) { data, _ in
                guard let data else { return }
                motionBox.run { this in
                    let r = data.rotationRate
                    let gyroMag = sqrt(r.x * r.x + r.y * r.y + r.z * r.z)
                    this.evaluateWaterJump(accelG: max(1, this.waterLiveAccelG), gyroRadPerSec: gyroMag)
                }
            }
        }
        let altimeterBox = WeakMainActorBox(self)
        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: .main) { data, _ in
                guard let data else { return }
                let alt = data.relativeAltitude.doubleValue
                altimeterBox.run { this in
                    if this.waterBaselineAltitude == nil {
                        this.waterBaselineAltitude = alt
                    }
                    this.waterRelativeAltitude = alt - (this.waterBaselineAltitude ?? 0)
                }
            }
        }
    }

    private func handleWaterSportDeviceMotion(_ data: CMDeviceMotion) {
        let u = data.userAcceleration
        let accelMag = sqrt(u.x * u.x + u.y * u.y + u.z * u.z)
        // Giroscópio (rad/s) — rotação do pulso/corpo no salto
        let r = data.rotationRate
        let gyroMag = sqrt(r.x * r.x + r.y * r.y + r.z * r.z)

        waterLiveAccelG = max(0.1, accelMag)
        waterPeakG = max(waterPeakG, accelMag)

        let now = Date()
        if now.timeIntervalSince(lastAccelSendAt) >= 0.45 {
            lastAccelSendAt = now
            sendToPhone([
                "action": "waterSportAccel",
                "accelG": accelMag,
                "gyroRadPerSec": gyroMag,
                "timestamp": now.timeIntervalSince1970
            ])
        }

        evaluateWaterJump(accelG: accelMag, gyroRadPerSec: gyroMag)
    }

    /// Detecta salto com acelerômetro + giroscópio (DeviceMotion).
    private func evaluateWaterJump(accelG: Double, gyroRadPerSec: Double) {
        guard isActive, isWaterSportMode, !isPaused else { return }

        // Decolagem: pico de aceleração e/ou giroscópio ativo
        let takeoffByAccel = accelG > 2.6
        let takeoffByGyro = accelG > 1.7 && gyroRadPerSec > 3.2
        if !isInAir, takeoffByAccel || takeoffByGyro {
            isInAir = true
            possibleTakeoffAltitude = waterRelativeAltitude
            possibleTakeoffTime = .now
            peakGDuringAir = accelG
            peakGyroDuringAir = gyroRadPerSec
            return
        }

        guard isInAir else { return }
        peakGDuringAir = max(peakGDuringAir, accelG)
        peakGyroDuringAir = max(peakGyroDuringAir, gyroRadPerSec)

        // Pouso: acel. baixa de novo (queda “suavizada”)
        if accelG < 0.55 {
            finalizeAirborneJumpIfValid()
        } else if let t0 = possibleTakeoffTime, Date().timeIntervalSince(t0) > 4.5 {
            // Timeout aéreo — descarta ou finaliza se houve rotação forte
            if peakGyroDuringAir > 4.0, peakGDuringAir > 2.2 {
                finalizeAirborneJumpIfValid()
            } else {
                resetAirborneJumpState()
            }
        }
    }

    private func finalizeAirborneJumpIfValid() {
        guard isInAir else { return }
        let t0 = possibleTakeoffTime ?? .now
        let air = Date().timeIntervalSince(t0)
        let takeoffAlt = possibleTakeoffAltitude ?? waterRelativeAltitude
        let heightFromAlt = max(0, waterRelativeAltitude - takeoffAlt)
        let half = max(0.1, air / 2)
        let heightFromAir = 0.5 * 9.81 * half * half
        let heightFromG = max(0.3, (peakGDuringAir - 1.0) * 0.55)
        let height = max(0.35, min(max(heightFromAlt, max(heightFromAir * 0.85, heightFromG)), 14))

        defer { resetAirborneJumpState() }

        // Mínimo de ar / cooldown anti-duplo
        guard air >= 0.28 else { return }
        guard Date().timeIntervalSince(lastAutoJumpAt) > 1.25 else { return }

        // Exige evidência real de salto (não só tremor)
        let looksLikeJump = heightFromAlt >= 0.35
            || air >= 0.4
            || (peakGDuringAir >= 2.8 && peakGyroDuringAir >= 2.5)
        guard looksLikeJump else { return }

        lastAutoJumpAt = .now
        registerWaterJump(
            heightMeters: height,
            peakG: peakGDuringAir,
            airtime: air,
            automatic: true
        )
    }

    private func stopWaterSportMotion() {
        motionManager.stopDeviceMotionUpdates()
        motionManager.stopGyroUpdates()
        altimeter.stopRelativeAltitudeUpdates()
        resetAirborneJumpState()
    }

    // MARK: - GPS Watch (Surf / Kitesurf)

    private func startWaterSportGPS() {
        guard !isWaterGPSTracking else { return }
        isWaterGPSTracking = true
        waterGPSPendingBatch = []
        lastWaterGPSAccepted = nil
        lastWaterGPSFlushAt = .now
        waterGPSPointCount = 0
        waterGPSLatitude = nil
        waterGPSLongitude = nil

        let status = waterLocationManager.authorizationStatus
        switch status {
        case .notDetermined:
            waterLocationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            waterLocationManager.startUpdatingLocation()
            watchSyncStatus = "GPS Watch ativo"
        case .denied, .restricted:
            watchSyncStatus = "GPS Watch sem permissão"
            isWaterGPSTracking = false
        @unknown default:
            waterLocationManager.requestWhenInUseAuthorization()
        }
    }

    private func stopWaterSportGPS(flush: Bool) {
        waterLocationManager.stopUpdatingLocation()
        if flush {
            flushWaterGPSBatch(force: true)
        }
        isWaterGPSTracking = false
        lastWaterGPSAccepted = nil
        waterGPSPendingBatch = []
        // Se o cronômetro de terra ainda precisa de GPS, reinicia.
        if isLandCardioGPSTracking {
            waterLocationManager.startUpdatingLocation()
        }
    }

    // MARK: - GPS / desempenho do cronômetro segmentado (terra)

    private func startLandCardioGPS() {
        isLandCardioGPSTracking = true
        landCardioRecentSpeeds = []
        lastLandDistanceMeters = 0
        lastLandDistanceAt = nil
        chronometerPerformance = .unknown
        chronometerSecondaryText = ""
        currentSpeedMps = 0
        cardioDistanceMeters = 0

        let status = waterLocationManager.authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            waterLocationManager.startUpdatingLocation()
            watchSyncStatus = "Cronômetro · GPS ativo"
        case .notDetermined:
            waterLocationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            watchSyncStatus = "Cronômetro · sem GPS (HealthKit)"
        @unknown default:
            break
        }
    }

    private func stopLandCardioGPS() {
        isLandCardioGPSTracking = false
        if !isWaterGPSTracking {
            waterLocationManager.stopUpdatingLocation()
        }
    }

    private func acceptLandCardioGPSLocation(_ location: CLLocation) {
        guard isLandCardioGPSTracking, usesSegmentedChronometer, isActive else { return }
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 40 else { return }

        if location.speed >= 0 {
            ingestLandCardioSpeed(location.speed)
        }
    }

    private func applyLandCardioDistanceMeters(_ meters: Double) {
        guard usesSegmentedChronometer, isActive else { return }
        let distance = max(0, meters)
        cardioDistanceMeters = distance

        let now = Date()
        if let lastAt = lastLandDistanceAt, lastLandDistanceMeters >= 0 {
            let dt = now.timeIntervalSince(lastAt)
            let delta = distance - lastLandDistanceMeters
            if dt >= 2.0, delta >= 0 {
                let speed = delta / dt
                // Preferência: GPS; distância HK é backup quando GPS fraco.
                if currentSpeedMps < Self.landMovingSpeedFloor || locationSpeedStale() {
                    ingestLandCardioSpeed(speed)
                }
            }
        }
        lastLandDistanceMeters = distance
        lastLandDistanceAt = now
    }

    private func locationSpeedStale() -> Bool {
        // Sem amostra GPS recente de movimento — usa distância HK.
        landCardioRecentSpeeds.isEmpty
    }

    private func ingestLandCardioSpeed(_ speed: Double) {
        guard usesSegmentedChronometer, isActive else { return }
        if isPaused {
            chronometerPerformance = .paused
            return
        }

        currentSpeedMps = max(0, speed)
        updateChronometerSecondaryText(speed: currentSpeedMps)

        guard speed >= Self.landMovingSpeedFloor else {
            chronometerPerformance = .stopped
            return
        }

        landCardioRecentSpeeds.append(speed)
        if landCardioRecentSpeeds.count > 48 {
            landCardioRecentSpeeds.removeFirst(landCardioRecentSpeeds.count - 48)
        }

        // Precisa de baseline da sessão antes de classificar.
        guard landCardioRecentSpeeds.count >= 4 else {
            chronometerPerformance = .unknown
            return
        }

        let median = Self.medianSpeed(of: landCardioRecentSpeeds) ?? Self.landMovingSpeedFloor
        let baseline = max(median, Self.landMovingSpeedFloor)
        let ratio = speed / baseline
        if ratio >= Self.landOptimalRatio {
            chronometerPerformance = .good
        } else if ratio < Self.landBelowRatio {
            chronometerPerformance = .poor
        } else {
            chronometerPerformance = .fair
        }
    }

    private func updateChronometerSecondaryText(speed: Double) {
        guard speed >= Self.landMovingSpeedFloor else {
            chronometerSecondaryText = formatClockLike(workoutElapsedSeconds)
            return
        }
        if isBikeStyleCardio {
            chronometerSecondaryText = String(format: "%.1f km/h", speed * 3.6)
        } else {
            let paceSeconds = 1000.0 / speed
            let minutes = Int(paceSeconds) / 60
            let secs = Int(paceSeconds) % 60
            chronometerSecondaryText = String(format: "%d'%02d\"/km", minutes, secs)
        }
    }

    private func formatClockLike(_ seconds: Int) -> String {
        let total = max(seconds, 0)
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    private static func medianSpeed(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }

    private func acceptWaterGPSLocation(_ location: CLLocation) {
        guard isWaterGPSTracking, isWaterSportMode else { return }
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 65 else { return }

        if let last = lastWaterGPSAccepted {
            let dt = location.timestamp.timeIntervalSince(last.timestamp)
            let moved = location.distance(from: last)
            if dt <= 0 { return }
            // Descarta saltos absurdos no mar (ex.: glitch GPS).
            if moved > 120, dt < 2.5 { return }
            if moved < 3, dt < 2.0 { return }
        }

        lastWaterGPSAccepted = location
        waterGPSLatitude = location.coordinate.latitude
        waterGPSLongitude = location.coordinate.longitude
        waterGPSPointCount += 1

        // Spot Buddy no Watch: usa GPS do relógio como “eu”.
        if isKitesurfMode, spotBuddyEnabled {
            spotBuddyMyLatitude = location.coordinate.latitude
            spotBuddyMyLongitude = location.coordinate.longitude
        }

        var point: [String: Double] = [
            "lat": location.coordinate.latitude,
            "lon": location.coordinate.longitude,
            "ts": location.timestamp.timeIntervalSince1970,
            "acc": location.horizontalAccuracy,
            "paused": isPaused ? 1 : 0
        ]
        if location.speed >= 0 {
            point["spd"] = location.speed
        }
        if location.altitude.isFinite {
            point["alt"] = location.altitude
        }
        waterGPSPendingBatch.append(point)

        let shouldFlush = waterGPSPendingBatch.count >= 4
            || Date().timeIntervalSince(lastWaterGPSFlushAt) >= 4
        if shouldFlush {
            flushWaterGPSBatch(force: false)
        }
    }

    private func flushWaterGPSBatch(force: Bool) {
        guard !waterGPSPendingBatch.isEmpty else { return }
        if !force, Date().timeIntervalSince(lastWaterGPSFlushAt) < 1.5,
           waterGPSPendingBatch.count < 8 {
            return
        }
        let batch = waterGPSPendingBatch
        waterGPSPendingBatch = []
        lastWaterGPSFlushAt = .now
        sendToPhone([
            "action": "waterSportGPSBatch",
            "points": batch,
            "timestamp": Date().timeIntervalSince1970
        ])
        watchSyncStatus = String(format: "GPS · %d pts", waterGPSPointCount)
    }

    private func estimatedHeightFromPeakG() -> Double {
        max(0.3, (waterPeakG - 1.0) * 0.55)
    }

    func requestSpotBuddyHelp() {
        spotBuddyNeedsHelp = true
        sendToPhone([
            "action": "kiteSpotHelpRequest",
            "timestamp": Date().timeIntervalSince1970,
        ])
    }

    func cancelSpotBuddyHelp() {
        spotBuddyNeedsHelp = false
        sendToPhone([
            "action": "kiteSpotImOk",
            "timestamp": Date().timeIntervalSince1970,
        ])
    }

    func dismissSpotBuddyHelpAlert() {
        spotBuddyIncomingHelp = nil
    }

    private func applyKiteSpotBuddyPayload(_ message: [String: Any]) {
        guard let json = message["payload"] as? String,
              let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(KiteSpotBuddyWatchPayload.self, from: data) else {
            return
        }
        spotBuddyEnabled = payload.spotBuddyEnabled
        spotBuddyPeers = payload.peers
        spotBuddyNeedsHelp = payload.needsHelp
        spotBuddyMyLatitude = payload.myLatitude
        spotBuddyMyLongitude = payload.myLongitude
        if let incoming = payload.incomingHelp {
            spotBuddyIncomingHelp = incoming
        }
    }

    private func handlePhoneMessage(_ message: [String: Any]) {
        guard let action = message["action"] as? String else { return }
        let messageTimestamp = Self.timeInterval(from: message, key: "timestamp") ?? 0

        switch action {
        case "startWorkout":
            if shouldIgnoreStalePhoneStart(timestamp: messageTimestamp) { return }
            notePhoneStart(timestamp: messageTimestamp)
            let name = message["workoutName"] as? String ?? "Treino"
            let exerciseName = message["exerciseName"] as? String ?? ""
            // iPhone é a fonte da verdade: substitui sessão genérica do HK launch.
            if isActive,
               !isCardioWorkout,
               !isMeditationWorkout,
               workoutName == name,
               (exerciseName.isEmpty || currentExerciseName == exerciseName) {
                applyPhoneSync(
                    workoutElapsedSeconds: message["workoutElapsedSeconds"] as? Int,
                    exerciseElapsedSeconds: message["exerciseElapsedSeconds"] as? Int,
                    exerciseName: exerciseName.isEmpty ? nil : exerciseName
                )
                sendWatchAckStarted(kind: "strength", workoutName: workoutName, playHaptic: false)
                return
            }
            meditationOwnedByWatch = false
            localMeditationPrompts = []
            startWorkout(name: name, exerciseName: exerciseName)
            applyPhoneSync(
                workoutElapsedSeconds: message["workoutElapsedSeconds"] as? Int,
                exerciseElapsedSeconds: message["exerciseElapsedSeconds"] as? Int,
                exerciseName: exerciseName
            )
            sendWatchAckStarted(kind: "strength", workoutName: name)
        case "startCardio":
            if shouldIgnoreStalePhoneStart(timestamp: messageTimestamp) { return }
            notePhoneStart(timestamp: messageTimestamp)
            let name = message["workoutName"] as? String ?? "Cardio"
            let targetSeconds = message["targetSeconds"] as? Int ?? 0
            let exerciseName = message["exerciseName"] as? String ?? "Cardio"
            let targetCalories = message["targetCalories"] as? Int ?? 0
            let waterMode = (message["waterSportMode"] as? Bool)
                ?? ((message["waterSportMode"] as? NSNumber)?.boolValue ?? false)
            let kite = (message["isKitesurf"] as? Bool)
                ?? ((message["isKitesurf"] as? NSNumber)?.boolValue ?? false)
            let swimMode = (message["swimmingMode"] as? Bool)
                ?? ((message["swimmingMode"] as? NSNumber)?.boolValue ?? false)
            let poolLen = (message["poolLengthMeters"] as? Double)
                ?? (message["poolLengthMeters"] as? NSNumber)?.doubleValue
                ?? 25
            let spotBuddy = (message["spotBuddyEnabled"] as? Bool)
                ?? ((message["spotBuddyEnabled"] as? NSNumber)?.boolValue ?? false)
            let outdoor = (message["locationOutdoor"] as? Bool)
                ?? ((message["locationOutdoor"] as? NSNumber)?.boolValue ?? false)
            let activityRaw = (message["activityTypeRaw"] as? UInt)
                ?? (message["activityTypeRaw"] as? NSNumber)?.uintValue
            if isActive,
               isCardioWorkout,
               workoutName == name,
               currentExerciseName == exerciseName {
                applyPhoneSync(
                    workoutElapsedSeconds: message["elapsedSeconds"] as? Int,
                    targetSeconds: targetSeconds,
                    targetCalories: targetCalories
                )
                sendWatchAckStarted(kind: "cardio", workoutName: workoutName, playHaptic: false)
                return
            }
            meditationOwnedByWatch = false
            localMeditationPrompts = []
            startCardio(
                name: name,
                targetSeconds: targetSeconds,
                exerciseName: exerciseName,
                targetCalories: targetCalories,
                waterSportMode: waterMode,
                isKitesurf: kite,
                swimmingMode: swimMode,
                poolLengthMeters: poolLen,
                spotBuddyEnabled: spotBuddy,
                locationOutdoor: outdoor,
                activityTypeRaw: activityRaw
            )
            sendWatchAckStarted(kind: "cardio", workoutName: name)
        case "syncWorkoutProgress":
            // Não reinicia sessão a partir de sync — startWorkout já cobre o início.
            // Um sync atrasado após stopWorkout reabria o treino no Watch.
            guard isActive else { return }
            applyPhoneSync(
                workoutElapsedSeconds: message["workoutElapsedSeconds"] as? Int,
                exerciseElapsedSeconds: message["exerciseElapsedSeconds"] as? Int,
                exerciseName: message["exerciseName"] as? String
            )
            applyPhonePausedFlag(message)
        case "syncCardioProgress":
            guard isActive else { return }
            applyPhoneSync(
                workoutElapsedSeconds: message["elapsedSeconds"] as? Int,
                targetSeconds: message["targetSeconds"] as? Int,
                targetCalories: message["targetCalories"] as? Int,
                currentCalories: message["currentCalories"] as? Double
            )
            if let kite = message["isKitesurf"] as? Bool ?? (message["isKitesurf"] as? NSNumber)?.boolValue {
                isKitesurfMode = kite
            }
            if let enabled = message["spotBuddyEnabled"] as? Bool
                ?? (message["spotBuddyEnabled"] as? NSNumber)?.boolValue {
                spotBuddyEnabled = enabled && isKitesurfMode
            }
            applyPhonePausedFlag(message)
        case "kiteSpotBuddy":
            applyKiteSpotBuddyPayload(message)
        case "requestWaterSportSync":
            sendMetricsToPhone()
            if isWaterSportMode {
                sendToPhone([
                    "action": "waterSportAccel",
                    "accelG": waterLiveAccelG,
                    "timestamp": Date().timeIntervalSince1970
                ])
            }
        case "requestMetrics":
            sendMetricsToPhone()
            sendToPhone([
                "action": "watchAckMetrics",
                "heartRate": heartRate,
                "calories": calories,
                "timestamp": Date().timeIntervalSince1970
            ])
            watchSyncStatus = "iPhone sincronizado"
        case "requestSwimSync":
            sendMetricsToPhone()
            sendSwimMetricsToPhone(force: true)
            watchSyncStatus = "Voltas enviadas"
        case "syncWaterSportMetrics":
            if let count = message["jumpCount"] as? Int {
                waterJumpCount = max(waterJumpCount, count)
            }
            if let maxH = message["maxJumpHeightMeters"] as? Double {
                waterMaxJumpMeters = max(waterMaxJumpMeters, maxH)
            }
            if let g = message["liveAccelG"] as? Double, g > 0 {
                waterLiveAccelG = g
            }
            watchSyncStatus = "Dados do iPhone"
        case "startMeditation":
            if shouldIgnoreStalePhoneStart(timestamp: messageTimestamp) { return }
            notePhoneStart(timestamp: messageTimestamp)
            let name = message["workoutName"] as? String ?? "Meditação"
            if isActive,
               isMeditationWorkout,
               workoutName == name {
                applyPhoneSync(
                    workoutElapsedSeconds: message["elapsedSeconds"] as? Int,
                    targetSeconds: message["targetSeconds"] as? Int,
                    meditationPrompt: message["currentPrompt"] as? String,
                    promptIndex: message["promptIndex"] as? Int
                )
                sendWatchAckStarted(kind: "meditation", workoutName: workoutName, playHaptic: false)
                return
            }
            meditationOwnedByWatch = false
            localMeditationPrompts = []
            startMeditation(
                name: name,
                targetSeconds: message["targetSeconds"] as? Int ?? 0,
                topicName: message["topicName"] as? String ?? "Meditação",
                topicIcon: message["topicIcon"] as? String ?? "brain.head.profile",
                colorName: message["colorName"] as? String ?? "purple",
                currentPrompt: message["currentPrompt"] as? String ?? "",
                promptIndex: message["promptIndex"] as? Int ?? 0,
                totalPrompts: message["totalPrompts"] as? Int ?? 1
            )
            sendWatchAckStarted(kind: "meditation", workoutName: name)
        case "syncMeditationProgress":
            guard isActive else { return }
            applyPhoneSync(
                workoutElapsedSeconds: message["elapsedSeconds"] as? Int,
                targetSeconds: message["targetSeconds"] as? Int,
                meditationPrompt: message["currentPrompt"] as? String,
                promptIndex: message["promptIndex"] as? Int
            )
        case "pauseWorkout":
            setPaused(true, notifyPhone: false)
        case "resumeWorkout":
            setPaused(false, notifyPhone: false)
        case "stopWorkout":
            // Stop atrasado (retry do iPhone) não pode derrubar um start mais novo.
            if messageTimestamp > 0, messageTimestamp + 0.05 < lastPhoneStartTimestamp {
                return
            }
            notePhoneStop(timestamp: messageTimestamp)
            if !isActive { return }
            WKInterfaceDevice.current().play(.success)
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
        case "deliverNotification":
            let title = message["title"] as? String ?? ""
            let body = message["body"] as? String ?? ""
            let category = message["category"] as? String ?? ""
            let identifier = message["identifier"] as? String ?? UUID().uuidString
            deliverSyncedNotification(title: title, body: body, category: category, identifier: identifier)
            if category == "REST_OVERTIME" {
                let exerciseName = message["exerciseName"] as? String ?? restExerciseName
                notifyRestOvertime(exerciseName: exerciseName)
            }
        case "syncDailyMotivation":
            if let payload = message["payload"] as? Data,
               let entries = try? JSONSerialization.jsonObject(with: payload) as? [[String: Any]] {
                syncDailyMotivationFromPhone(entries)
            }
        case "cancelDailyMotivation":
            cancelDailyMotivationOnWatch()
        case "scheduleInactivityReminder":
            let title = message["title"] as? String ?? "Hora de voltar a treinar!"
            let body = message["body"] as? String ?? ""
            scheduleInactivityReminderOnWatch(
                title: title,
                body: body,
                year: message["year"] as? Int ?? 0,
                month: message["month"] as? Int ?? 0,
                day: message["day"] as? Int ?? 0,
                hour: message["hour"] as? Int ?? 0,
                minute: message["minute"] as? Int ?? 0,
                identifier: message["identifier"] as? String ?? "workout_inactivity_48h"
            )
        case "cancelInactivityReminder":
            cancelInactivityReminderOnWatch()
        case "restTimer":
            let seconds = message["seconds"] as? Int ?? 60
            startRestCountdown(seconds: seconds, exerciseName: "Exercício")
        case "ping":
            break
        default:
            break
        }
    }
}

extension WatchWorkoutManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            refreshPhoneReachability()
            guard activationState == .activated else { return }
            let context = session.receivedApplicationContext
            guard !context.isEmpty else { return }
            // Contexto antigo de stop: registra timestamp e não reabre.
            if let action = context["action"] as? String, action == "stopWorkout" {
                handlePhoneMessage(context)
                return
            }
            handlePhoneMessage(context)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            refreshPhoneReachability()
            if session.isReachable {
                flushWaterGPSBatch(force: true)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            handlePhoneMessage(applicationContext)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            handlePhoneMessage(message)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        let action = message["action"] as? String
        if action == "ping" {
            replyHandler([
                "action": "pong",
                "ok": true,
                "timestamp": Date().timeIntervalSince1970
            ])
            return
        }

        Task { @MainActor in
            handlePhoneMessage(message)
        }
        replyHandler(["ok": true])
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in
            handlePhoneMessage(userInfo)
        }
    }
}


extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        // Sessão de natação mantém o app em modo treino na água.
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        mainActorBox?.run { manager in
            manager.watchSyncStatus = "Erro na sessão HealthKit"
        }
    }
}

extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        var distanceMeters: Double?
        var energyKcal: Double?
        var bpm: Double?

        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            let stats = workoutBuilder.statistics(for: quantityType)
            if quantityType == HKQuantityType.quantityType(forIdentifier: .distanceSwimming),
               let sum = stats?.sumQuantity() {
                distanceMeters = sum.doubleValue(for: .meter())
            }
            if quantityType == HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
               let sum = stats?.sumQuantity() {
                distanceMeters = sum.doubleValue(for: .meter())
            }
            if quantityType == HKQuantityType.quantityType(forIdentifier: .distanceCycling),
               let sum = stats?.sumQuantity() {
                distanceMeters = sum.doubleValue(for: .meter())
            }
            if quantityType == HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
               let sum = stats?.sumQuantity() {
                energyKcal = sum.doubleValue(for: .kilocalorie())
            }
            if quantityType == HKQuantityType.quantityType(forIdentifier: .heartRate),
               let quantity = stats?.mostRecentQuantity() {
                bpm = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            }
        }

        let distanceSnapshot = distanceMeters
        let energySnapshot = energyKcal
        let bpmSnapshot = bpm
        mainActorBox?.run { manager in
            guard manager.isActive else { return }
            if manager.isSwimmingMode, let distanceSnapshot {
                manager.applySwimDistanceMeters(distanceSnapshot)
            }
            if manager.usesSegmentedChronometer, let distanceSnapshot {
                manager.applyLandCardioDistanceMeters(distanceSnapshot)
            }
            if let energySnapshot, energySnapshot >= manager.calories {
                manager.calories = energySnapshot
                manager.updateCalorieSuperation()
            }
            if let bpmSnapshot, bpmSnapshot > 0 {
                manager.heartRate = bpmSnapshot
                manager.lastHeartRateSampleAt = Date()
            }
            manager.sendMetricsToPhone()
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        let lapCount = workoutBuilder.workoutEvents.filter { $0.type == .lap }.count
        mainActorBox?.run { manager in
            guard manager.isSwimmingMode else { return }
            let previous = manager.swimEventLapCount
            manager.swimEventLapCount = lapCount
            if lapCount > previous {
                let distance = Double(lapCount) * manager.poolLengthMeters
                manager.applySwimLapCount(
                    lapCount,
                    distanceMeters: max(manager.swimDistanceMeters, distance),
                    source: "lapEvent"
                )
            }
        }
    }
}

extension WatchWorkoutManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard isWaterGPSTracking || isLandCardioGPSTracking else { return }
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                waterLocationManager.startUpdatingLocation()
                watchSyncStatus = isWaterGPSTracking ? "GPS Watch ativo" : "Cronômetro · GPS ativo"
            case .denied, .restricted:
                watchSyncStatus = "GPS Watch sem permissão"
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            for location in locations {
                if isWaterGPSTracking {
                    acceptWaterGPSLocation(location)
                }
                if isLandCardioGPSTracking {
                    acceptLandCardioGPSLocation(location)
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            watchSyncStatus = "GPS Watch: \(error.localizedDescription)"
        }
    }
}
