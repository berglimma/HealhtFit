import Foundation
import WatchConnectivity
import HealthKit
import Combine
import UserNotifications
import WatchKit
import CoreMotion

@MainActor
final class WatchWorkoutManager: NSObject, ObservableObject {
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
    @Published var restRemainingSeconds = 0
    @Published var isResting = false
    @Published var isRestOvertime = false
    @Published var restExerciseName = ""
    @Published var restOvertimeSeconds = 0
    @Published var isWaterSportMode = false
    @Published var isKitesurfMode = false
    @Published var waterJumpCount = 0
    @Published var waterMaxJumpMeters: Double = 0
    @Published var waterLiveAccelG: Double = 1
    @Published var waterLastJumpMeters: Double = 0
    @Published var isSwimmingMode = false
    @Published var poolLengthMeters: Double = 25
    @Published var swimLapCount = 0
    @Published var swimDistanceMeters: Double = 0
    @Published var watchSyncStatus = ""

    private var session: WCSession?
    private var heartRateTimer: Timer?
    private var workoutClockTimer: Timer?
    private var restTimer: Timer?
    private var configuredRestSeconds = 60
    private var restElapsedSeconds = 0
    private var secondsSincePhoneSync = 0
    private var hasSentRestOvertimeNotification = false
    private var workoutStartedAt: Date?
    private let healthStore = HKHealthStore()
    private let motionManager = CMMotionManager()
    private var waterPeakG: Double = 1
    private var waterRelativeAltitude: Double = 0
    private var waterBaselineAltitude: Double?
    private let altimeter = CMAltimeter()
    private var hkWorkoutSession: HKWorkoutSession?
    private var hkLiveBuilder: HKLiveWorkoutBuilder?
    private var swimEventLapCount = 0
    private var lastSwimMetricsSentAt: Date = .distantPast
    /// Safe hop for nonisolated HK/WC callbacks (no captured `var self`).
    nonisolated(unsafe) private var mainActorBox: WeakMainActorBox<WatchWorkoutManager>?

    override init() {
        super.init()
        mainActorBox = WeakMainActorBox(self)
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    func startWorkout(name: String, exerciseName: String = "") {
        resetWorkoutState()
        workoutName = name
        currentExerciseName = exerciseName
        isCardioWorkout = false
        isMeditationWorkout = false
        isActive = true
        startHeartRateMonitoring()
        startWorkoutClock()
    }

    func startCardio(
        name: String,
        targetSeconds: Int,
        exerciseName: String,
        targetCalories: Int = 0,
        waterSportMode: Bool = false,
        isKitesurf: Bool = false,
        swimmingMode: Bool = false,
        poolLengthMeters: Double = 25
    ) {
        resetWorkoutState()
        workoutName = name
        isCardioWorkout = true
        isMeditationWorkout = false
        isWaterSportMode = waterSportMode
        isKitesurfMode = isKitesurf
        isSwimmingMode = swimmingMode
        self.poolLengthMeters = max(poolLengthMeters, 1)
        cardioTargetSeconds = max(targetSeconds, 0)
        cardioTargetCalories = max(targetCalories, 0)
        currentExerciseName = exerciseName
        isActive = true
        startHeartRateMonitoring()
        startWorkoutClock()
        if waterSportMode {
            startWaterSportMotion()
        }
        if swimmingMode {
            startSwimmingWorkoutSession()
        }
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
        resetWorkoutState()
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
        startHeartRateMonitoring()
        startWorkoutClock()
    }

    /// Marca salto manual e envia altura estimada (altímetro relativo / acelerômetro).
    func markWaterSportJump() {
        guard isActive, isWaterSportMode else { return }
        let height = max(0.4, max(waterRelativeAltitude * 0.9, estimatedHeightFromPeakG()))
        let peak = max(waterPeakG, waterLiveAccelG)
        waterJumpCount += 1
        waterLastJumpMeters = height
        waterMaxJumpMeters = max(waterMaxJumpMeters, height)
        waterPeakG = 1
        WKInterfaceDevice.current().play(.click)
        sendToPhone([
            "action": "waterSportJump",
            "heightMeters": height,
            "peakG": peak,
            "airtimeSeconds": 0.0,
            "timestamp": Date().timeIntervalSince1970
        ])
    }

    func requestPhoneSyncFromWatch() {
        sendToPhone([
            "action": "requestPhoneSync",
            "timestamp": Date().timeIntervalSince1970
        ])
        sendMetricsToPhone()
        watchSyncStatus = "Sincronizando…"
    }

    func stopWorkout() {
        isActive = false
        isCardioWorkout = false
        isMeditationWorkout = false
        stopWaterSportMotion()
        stopSwimmingWorkoutSession()
        heartRateTimer?.invalidate()
        heartRateTimer = nil
        workoutClockTimer?.invalidate()
        workoutClockTimer = nil
        stopRestCountdown()
        resetWorkoutState()
        sendMetricsToPhone()
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
        calories = 0
        heartRate = 0
        workoutStartedAt = nil
        secondsSincePhoneSync = 0
        isWaterSportMode = false
        isKitesurfMode = false
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
        watchSyncStatus = ""
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
        guard isActive else { return }
        secondsSincePhoneSync += 1

        guard secondsSincePhoneSync > 2, !isResting else { return }
        workoutElapsedSeconds += 1
        if !isCardioWorkout && !isMeditationWorkout {
            exerciseElapsedSeconds += 1
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

    private func updateCalorieSuperation() {
        guard isCardioWorkout, cardioTargetCalories > 0 else {
            cardioSuperationMessage = ""
            return
        }
        if calories >= Double(cardioTargetCalories) {
            if cardioSuperationMessage.isEmpty {
                cardioSuperationMessage = "Meta superada! 🔥"
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
        workoutStartedAt = Date()
        fetchTodaySteps()
        let metricsBox = WeakMainActorBox(self)
        heartRateTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            metricsBox.run { this in
                this.fetchHeartRate()
                this.fetchActiveCalories()
                this.fetchTodaySteps()
                this.applySimulatorMetricsIfNeeded()
                this.sendMetricsToPhone()
            }
        }
    }

    /// No simulador não há sensor óptico — gera BPM/kcal realistas para testar o sync.
    private func applySimulatorMetricsIfNeeded() {
        #if targetEnvironment(simulator)
        guard isActive else { return }
        if heartRate < 40 {
            heartRate = isMeditationWorkout
                ? Double.random(in: 58...72)
                : Double.random(in: 118...142)
        } else {
            let jitter = Double.random(in: -3...3)
            let base = isMeditationWorkout ? 65.0 : 130.0
            heartRate = min(175, max(50, heartRate + jitter * 0.4 + (base - heartRate) * 0.05))
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

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let start = workoutStartedAt ?? Date().addingTimeInterval(-60 * 30)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictEndDate)
        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { [box = WeakMainActorBox(self)] _, samples, _ in
            box.run { this in
                if let sample = samples?.first as? HKQuantitySample {
                    this.heartRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                }
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
        var payload: [String: Any] = [
            "heartRate": heartRate,
            "calories": calories,
            "steps": todaySteps,
            "timestamp": Date().timeIntervalSince1970
        ]
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
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { _ in
                session.transferUserInfo(payload)
            }
        } else if session.activationState == .activated {
            session.transferUserInfo(payload)
        }
    }

    // MARK: - Natação (HKWorkoutSession + voltas)

    private func startSwimmingWorkoutSession() {
        guard HKHealthStore.isHealthDataAvailable() else {
            watchSyncStatus = "HealthKit indisponível"
            return
        }
        requestHealthKitAuthorizationIfNeeded()

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .swimming
        configuration.locationType = .indoor
        configuration.swimmingLocationType = .pool
        configuration.lapLength = HKQuantity(unit: .meter(), doubleValue: max(poolLengthMeters, 1))

        do {
            let hkSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = hkSession.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            hkSession.delegate = self
            builder.delegate = self

            let start = Date()
            workoutStartedAt = start
            hkSession.startActivity(with: start)
            builder.beginCollection(withStart: start) { _, _ in }

            hkWorkoutSession = hkSession
            hkLiveBuilder = builder
            watchSyncStatus = "Natação · voltas automáticas"
            sendSwimMetricsToPhone(force: true)
        } catch {
            watchSyncStatus = "Falha ao iniciar natação HK"
            // Continua com contagem estimada / manual no iPhone.
        }
    }

    private func stopSwimmingWorkoutSession() {
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
        let motionBox = WeakMainActorBox(self)
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.08
            motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { data, _ in
                guard let data else { return }
                motionBox.run { this in
                    let u = data.userAcceleration
                    let mag = sqrt(u.x * u.x + u.y * u.y + u.z * u.z)
                    this.waterLiveAccelG = max(0.1, mag)
                    this.waterPeakG = max(this.waterPeakG, mag)
                    if Int(Date().timeIntervalSince1970 * 10) % 5 == 0 {
                        this.sendToPhone([
                            "action": "waterSportAccel",
                            "accelG": mag,
                            "timestamp": Date().timeIntervalSince1970
                        ])
                    }
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

    private func stopWaterSportMotion() {
        motionManager.stopDeviceMotionUpdates()
        altimeter.stopRelativeAltitudeUpdates()
    }

    private func estimatedHeightFromPeakG() -> Double {
        // Proxy simples a partir de pico de aceleração (g)
        max(0.3, (waterPeakG - 1.0) * 0.55)
    }

    private func handlePhoneMessage(_ message: [String: Any]) {
        guard let action = message["action"] as? String else { return }

        switch action {
        case "startWorkout":
            let name = message["workoutName"] as? String ?? "Treino"
            let exerciseName = message["exerciseName"] as? String ?? ""
            startWorkout(name: name, exerciseName: exerciseName)
            applyPhoneSync(
                workoutElapsedSeconds: message["workoutElapsedSeconds"] as? Int,
                exerciseElapsedSeconds: message["exerciseElapsedSeconds"] as? Int,
                exerciseName: exerciseName
            )
        case "startCardio":
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
            startCardio(
                name: name,
                targetSeconds: targetSeconds,
                exerciseName: exerciseName,
                targetCalories: targetCalories,
                waterSportMode: waterMode,
                isKitesurf: kite,
                swimmingMode: swimMode,
                poolLengthMeters: poolLen
            )
        case "syncWorkoutProgress":
            applyPhoneSync(
                workoutElapsedSeconds: message["workoutElapsedSeconds"] as? Int,
                exerciseElapsedSeconds: message["exerciseElapsedSeconds"] as? Int,
                exerciseName: message["exerciseName"] as? String
            )
        case "syncCardioProgress":
            applyPhoneSync(
                workoutElapsedSeconds: message["elapsedSeconds"] as? Int,
                targetSeconds: message["targetSeconds"] as? Int,
                targetCalories: message["targetCalories"] as? Int,
                currentCalories: message["currentCalories"] as? Double
            )
        case "requestWaterSportSync":
            sendMetricsToPhone()
            if isWaterSportMode {
                sendToPhone([
                    "action": "waterSportAccel",
                    "accelG": waterLiveAccelG,
                    "timestamp": Date().timeIntervalSince1970
                ])
            }
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
            startMeditation(
                name: message["workoutName"] as? String ?? "Meditação",
                targetSeconds: message["targetSeconds"] as? Int ?? 0,
                topicName: message["topicName"] as? String ?? "Meditação",
                topicIcon: message["topicIcon"] as? String ?? "brain.head.profile",
                colorName: message["colorName"] as? String ?? "purple",
                currentPrompt: message["currentPrompt"] as? String ?? "",
                promptIndex: message["promptIndex"] as? Int ?? 0,
                totalPrompts: message["totalPrompts"] as? Int ?? 1
            )
        case "syncMeditationProgress":
            applyPhoneSync(
                workoutElapsedSeconds: message["elapsedSeconds"] as? Int,
                targetSeconds: message["targetSeconds"] as? Int,
                meditationPrompt: message["currentPrompt"] as? String,
                promptIndex: message["promptIndex"] as? Int
            )
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
        guard activationState == .activated else { return }
        let context = session.receivedApplicationContext
        guard !context.isEmpty else { return }
        Task { @MainActor in
            handlePhoneMessage(context)
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
            manager.watchSyncStatus = "Erro na sessão de natação"
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
            guard manager.isSwimmingMode else { return }
            if let distanceSnapshot {
                manager.applySwimDistanceMeters(distanceSnapshot)
            }
            if let energySnapshot {
                manager.calories = energySnapshot
                manager.updateCalorieSuperation()
            }
            if let bpmSnapshot {
                manager.heartRate = bpmSnapshot
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
