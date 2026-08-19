import Foundation
import HealthKit
import Combine

@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    @Published var isAuthorized = false
    @Published var authorizationError: String?
    @Published var dailyMetrics: [DailyHealthMetric] = []
    @Published var todaySteps: Int = 0
    @Published var todayCalories: Double = 0
    @Published var currentHeartRate: Double = 0
    @Published var restingHeartRate: Double = 0

    private var lastWeeklyFetchAt: Date?
    private static let weeklyFetchMinInterval: TimeInterval = 75

    /// Snapshot de treino externo (Fitness / outros apps) lido do Apple Saúde.
    struct ExternalWorkoutSample: Identifiable, Equatable {
        var id: UUID { healthKitUUID }
        let healthKitUUID: UUID
        let startedAt: Date
        let endedAt: Date
        let durationSeconds: TimeInterval
        let calories: Double
        let averageHeartRate: Double
        let activityType: HKWorkoutActivityType
        let sourceName: String
        let sourceBundleId: String
    }

    nonisolated static let healthFitOriginMetadataKey = "HealthFitOrigin"

    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKQuery?
    private var stepsObserverQuery: HKQuery?
    private var caloriesObserverQuery: HKQuery?
    private var workoutObserverQuery: HKQuery?
    private var isRefreshing = false
    /// Callback disparado quando novos treinos aparecem no Saúde (background/foreground).
    var onExternalWorkoutsChanged: (() -> Void)?

    /// BPM preferindo valor ao vivo (Watch/HealthKit); fallback para FC de repouso.
    var displayedHeartRate: Double {
        if currentHeartRate > 0 { return currentHeartRate }
        return restingHeartRate
    }

    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        if let stepCount = HKObjectType.quantityType(forIdentifier: .stepCount) { types.insert(stepCount) }
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(activeEnergy) }
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) { types.insert(heartRate) }
        if let restingHR = HKObjectType.quantityType(forIdentifier: .restingHeartRate) { types.insert(restingHR) }
        if let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass) { types.insert(bodyMass) }
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { types.insert(hrv) }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        if let workout = HKObjectType.workoutType() as HKObjectType? { types.insert(workout) }
        return types
    }

    private var writeTypes: Set<HKSampleType> {
        var types = Set<HKSampleType>()
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(activeEnergy) }
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) { types.insert(heartRate) }
        if let workout = HKObjectType.workoutType() as HKSampleType? { types.insert(workout) }
        return types
    }

    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async {
        guard isHealthKitAvailable else {
            authorizationError = "HealthKit não disponível neste dispositivo"
            #if targetEnvironment(simulator)
            loadMockData()
            #endif
            return
        }

        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            isAuthorized = true
            authorizationError = nil
            await fetchWeeklyMetrics(force: true)
            startMetricObservers()
        } catch {
            authorizationError = error.localizedDescription
            #if targetEnvironment(simulator)
            loadMockData()
            #endif
        }
    }

    /// Atualiza passos, calorias e BPM a partir do HealthKit (e dados já sincronizados do Watch).
    func refreshFromHealthKit() async {
        guard isHealthKitAvailable else { return }
        if !isAuthorized {
            await requestAuthorization()
            return
        }
        await fetchWeeklyMetrics()
        await fetchLatestHeartRate()
    }

    /// Aplica métricas ao vivo vindas do Apple Watch (mantém dashboard e treino alinhados).
    func applyLiveWatchMetrics(heartRate: Double?, calories: Double?, steps: Int?) {
        if let heartRate, heartRate > 0 {
            currentHeartRate = heartRate
        }
        if let calories, calories >= 0 {
            // Não substitui o total do dia; só garante BPM/contexto ao vivo.
            _ = calories
        }
        if let steps, steps > todaySteps {
            todaySteps = steps
        }
    }

    func fetchWeeklyMetrics(force: Bool = false) async {
        guard isHealthKitAvailable else {
            #if targetEnvironment(simulator)
            loadMockData()
            #endif
            return
        }
        guard isAuthorized else { return }
        guard !isRefreshing else { return }
        if !force, let last = lastWeeklyFetchAt,
           Date().timeIntervalSince(last) < Self.weeklyFetchMinInterval {
            return
        }
        isRefreshing = true
        lastWeeklyFetchAt = Date()
        defer { isRefreshing = false }

        let calendar = Calendar.current
        var windows: [(date: Date, start: Date, end: Date)] = []
        windows.reserveCapacity(7)
        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: .now) else { continue }
            let start = calendar.startOfDay(for: date)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { continue }
            windows.append((start, start, end))
        }

        let storeBox = UncheckedHKStore(store: healthStore)
        let metrics = await withTaskGroup(of: DailyHealthMetric.self, returning: [DailyHealthMetric].self) { group in
            for window in windows {
                group.addTask {
                    await HealthKitQueryClient.dayMetrics(
                        store: storeBox.store,
                        date: window.date,
                        from: window.start,
                        to: window.end
                    )
                }
            }
            var items: [DailyHealthMetric] = []
            items.reserveCapacity(windows.count)
            for await item in group {
                items.append(item)
            }
            return items.sorted { $0.date < $1.date }
        }

        guard !metrics.isEmpty else { return }

        dailyMetrics = metrics
        if let today = metrics.last {
            todaySteps = today.steps
            todayCalories = today.activeCalories
            if today.restingHeartRate > 0 {
                restingHeartRate = today.restingHeartRate
            }
        }
    }

    func saveWorkout(
        duration: TimeInterval,
        calories: Double,
        heartRate: Double,
        activityType: HKWorkoutActivityType = .traditionalStrengthTraining
    ) async {
        guard isHealthKitAvailable, isAuthorized else { return }

        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-max(duration, 1))

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = activityType == .running || activityType == .walking ? .outdoor : .indoor

        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration,
            device: .local()
        )

        do {
            try await builder.beginCollection(at: startDate)

            var samples: [HKSample] = []

            if calories > 0,
               let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                let energy = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
                samples.append(
                    HKQuantitySample(
                        type: energyType,
                        quantity: energy,
                        start: startDate,
                        end: endDate
                    )
                )
            }

            if heartRate > 0,
               let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
                let bpm = HKQuantity(
                    unit: HKUnit.count().unitDivided(by: .minute()),
                    doubleValue: heartRate
                )
                samples.append(
                    HKQuantitySample(
                        type: hrType,
                        quantity: bpm,
                        start: startDate,
                        end: endDate
                    )
                )
            }

            if !samples.isEmpty {
                try await builder.addSamples(samples)
            }

            var metadata: [String: Any] = [Self.healthFitOriginMetadataKey: true]
            if heartRate > 0 {
                metadata["averageHeartRate"] = heartRate
            }
            try await builder.addMetadata(metadata)

            try await builder.endCollection(at: endDate)
            _ = try await builder.finishWorkout()
            await fetchWeeklyMetrics(force: true)
            if heartRate > 0 {
                currentHeartRate = heartRate
            }
        } catch {
            #if DEBUG
            print("[HealthFit] Falha ao salvar treino no HealthKit: \(error.localizedDescription)")
            #endif
        }
    }

    private func startMetricObservers() {
        startHeartRateObserver()
        startWorkoutObserver()
        startQuantityObserver(for: .stepCount, storingIn: &stepsObserverQuery) {
            await HealthKitManager.shared.refreshTodayStepsAndCalories()
        }
        startQuantityObserver(for: .activeEnergyBurned, storingIn: &caloriesObserverQuery) {
            await HealthKitManager.shared.refreshTodayStepsAndCalories()
        }
        Task { await fetchLatestHeartRate() }
    }

    private func startWorkoutObserver() {
        let type = HKObjectType.workoutType()
        if let existing = workoutObserverQuery {
            healthStore.stop(existing)
        }
        let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completionHandler, error in
            defer { completionHandler() }
            guard error == nil else { return }
            Task { @MainActor in
                HealthKitManager.shared.onExternalWorkoutsChanged?()
            }
        }
        workoutObserverQuery = query
        healthStore.execute(query)
        // Horário (não immediate): evita acordar o app a cada amostra e poupa bateria.
        healthStore.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
    }

    /// Treinos de outros apps (exclui os gravados pelo próprio HealthFit).
    func fetchExternalWorkouts(since start: Date, limit: Int = 40) async -> [ExternalWorkoutSample] {
        guard isHealthKitAvailable, isAuthorized else { return [] }
        let ourBundle = Bundle.main.bundleIdentifier ?? "luan.com.healthfit.app"
        let queried = await HealthKitQueryClient.workouts(
            store: healthStore,
            from: start,
            to: Date(),
            limit: limit
        )

        return queried.compactMap { workout in
            if workout.sourceBundleId == ourBundle { return nil }
            if workout.hasHealthFitOrigin { return nil }
            guard workout.duration >= 90 else { return nil }
            let activityType = HKWorkoutActivityType(rawValue: workout.activityTypeRaw) ?? .other
            return ExternalWorkoutSample(
                healthKitUUID: workout.uuid,
                startedAt: workout.startedAt,
                endedAt: workout.endedAt,
                durationSeconds: workout.duration,
                calories: workout.calories,
                averageHeartRate: workout.averageHeartRate,
                activityType: activityType,
                sourceName: workout.sourceName.isEmpty ? "Apple Saúde" : workout.sourceName,
                sourceBundleId: workout.sourceBundleId
            )
        }
    }

    private func startQuantityObserver(
        for identifier: HKQuantityTypeIdentifier,
        storingIn querySlot: inout HKQuery?,
        onChange: @escaping @Sendable () async -> Void
    ) {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return }
        if let existing = querySlot {
            healthStore.stop(existing)
        }

        let query = HKObserverQuery(sampleType: type, predicate: nil) { _, _, error in
            guard error == nil else { return }
            Task { await onChange() }
        }
        querySlot = query
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
    }

    private func refreshTodayStepsAndCalories() async {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }

        async let steps = fetchCumulativeSum(.stepCount, unit: .count(), from: start, to: end)
        async let calories = fetchCumulativeSum(.activeEnergyBurned, unit: .kilocalorie(), from: start, to: end)
        let (stepsValue, caloriesValue) = await (steps, calories)
        todaySteps = Int(stepsValue)
        todayCalories = caloriesValue
    }

    private func fetchWorkoutMinutes(from start: Date, to end: Date) async -> Int {
        await HealthKitQueryClient.workoutMinutes(store: healthStore, from: start, to: end)
    }

    private func fetchCumulativeSum(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async -> Double {
        await HealthKitQueryClient.cumulativeSum(
            store: healthStore,
            identifier,
            unit: unit,
            from: start,
            to: end
        )
    }

    private func fetchDiscreteAverage(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async -> Double {
        await HealthKitQueryClient.discreteAverage(
            store: healthStore,
            identifier,
            unit: unit,
            from: start,
            to: end
        )
    }

    private func fetchDiscreteMax(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async -> Double {
        await HealthKitQueryClient.discreteMax(
            store: healthStore,
            identifier,
            unit: unit,
            from: start,
            to: end
        )
    }

    private func startHeartRateObserver() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        if let existing = heartRateQuery {
            healthStore.stop(existing)
        }

        let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { _, _, error in
            guard error == nil else { return }
            // Avoid capturing `self` from a Sendable HK callback (Swift 6).
            Task { @MainActor in
                await HealthKitManager.shared.fetchLatestHeartRate()
            }
        }
        heartRateQuery = query
        healthStore.execute(query)
        // FC em treino ativo vem do BLE / queries pontuais; background hourly basta para o painel.
        healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .hourly) { _, _ in }
    }

    private func fetchLatestHeartRate() async {
        if let bpm = await HealthKitQueryClient.latestHeartRate(store: healthStore) {
            currentHeartRate = bpm
        }
    }

    // MARK: - Escalada

    /// Contexto de saúde de uma sessão de escalada: esforço na parede e recuperação da noite anterior.
    struct ClimbingHealthSnapshot: Equatable, Sendable {
        var averageHeartRate: Double?
        var peakHeartRate: Double?
        var activeCalories: Double?
        /// Horas dormidas na noite anterior (HealthKit; cai para o registro manual se vazio).
        var sleepHours: Double?
        /// HRV SDNN mais recente, em ms.
        var hrvMs: Double?
    }

    /// Métricas de uma janela de sessão. Usado ao encerrar a escalada e pelo IAssistente.
    func climbingHealthSnapshot(from start: Date, to end: Date = .now) async -> ClimbingHealthSnapshot {
        guard isHealthKitAvailable, isAuthorized else {
            return ClimbingHealthSnapshot(sleepHours: DailyWellnessService.shared.todaySleepHours)
        }

        async let average = fetchDiscreteAverage(
            .heartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            from: start,
            to: end
        )
        async let peak = fetchDiscreteMax(
            .heartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            from: start,
            to: end
        )
        async let calories = fetchCumulativeSum(.activeEnergyBurned, unit: .kilocalorie(), from: start, to: end)
        async let sleep = fetchLastNightSleepHours()
        async let hrv = fetchLatestHRV()

        let (averageValue, peakValue, caloriesValue, sleepValue, hrvValue) = await (average, peak, calories, sleep, hrv)

        return ClimbingHealthSnapshot(
            averageHeartRate: averageValue > 0 ? averageValue : nil,
            peakHeartRate: peakValue > 0 ? peakValue : nil,
            activeCalories: caloriesValue > 0 ? caloriesValue : nil,
            sleepHours: sleepValue ?? DailyWellnessService.shared.todaySleepHours,
            hrvMs: hrvValue
        )
    }

    /// HRV SDNN mais recente das últimas 24 h — a leitura que o Watch grava durante o sono.
    func fetchLatestHRV() async -> Double? {
        await HealthKitQueryClient.latestHRV(store: healthStore)
    }

    /// Horas de sono da noite anterior, somando apenas as fases realmente adormecidas.
    func fetchLastNightSleepHours() async -> Double? {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        guard let windowStart = calendar.date(byAdding: .hour, value: -6, to: startOfToday) else { return nil }
        return await HealthKitQueryClient.lastNightSleepHours(store: healthStore, from: windowStart, to: .now)
    }

    private func loadMockData() {
        let calendar = Calendar.current
        dailyMetrics = (0..<7).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: .now) else { return nil }
            return DailyHealthMetric(
                date: calendar.startOfDay(for: date),
                steps: Int.random(in: 5000...12000),
                activeCalories: Double.random(in: 200...600),
                restingHeartRate: Double.random(in: 58...72),
                workoutMinutes: Int.random(in: 0...75)
            )
        }
        if let today = dailyMetrics.last {
            todaySteps = today.steps
            todayCalories = today.activeCalories
            restingHeartRate = today.restingHeartRate
            currentHeartRate = Double.random(in: 65...85)
        }
    }
}

/// Queries HealthKit fora do MainActor, com timeout — evita freeze de 30–40s se o Saúde não responder.
private enum HealthKitQueryClient {
    static let timeout: TimeInterval = 3.5
    static let workoutSampleLimit = 40
    static let sleepSampleLimit = 200

    static func dayMetrics(
        store: HKHealthStore,
        date: Date,
        from start: Date,
        to end: Date
    ) async -> DailyHealthMetric {
        async let steps = cumulativeSum(store: store, .stepCount, unit: .count(), from: start, to: end)
        async let calories = cumulativeSum(store: store, .activeEnergyBurned, unit: .kilocalorie(), from: start, to: end)
        async let rhr = discreteAverage(
            store: store,
            .restingHeartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            from: start,
            to: end
        )
        async let minutes = workoutMinutes(store: store, from: start, to: end)
        let (stepsValue, caloriesValue, rhrValue, minutesValue) = await (steps, calories, rhr, minutes)
        return DailyHealthMetric(
            date: date,
            steps: Int(stepsValue),
            activeCalories: caloriesValue,
            restingHeartRate: rhrValue,
            workoutMinutes: minutesValue
        )
    }

    static func cumulativeSum(
        store: HKHealthStore,
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async -> Double {
        await statistic(store: store, identifier, unit: unit, from: start, to: end, kind: .sum)
    }

    static func discreteAverage(
        store: HKHealthStore,
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async -> Double {
        await statistic(store: store, identifier, unit: unit, from: start, to: end, kind: .average)
    }

    static func discreteMax(
        store: HKHealthStore,
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async -> Double {
        await statistic(store: store, identifier, unit: unit, from: start, to: end, kind: .max)
    }

    private enum StatisticKind: Sendable {
        case sum
        case average
        case max

        var options: HKStatisticsOptions {
            switch self {
            case .sum: return .cumulativeSum
            case .average: return .discreteAverage
            case .max: return .discreteMax
            }
        }

        func value(from result: HKStatistics?, unit: HKUnit) -> Double {
            switch self {
            case .sum: return result?.sumQuantity()?.doubleValue(for: unit) ?? 0
            case .average: return result?.averageQuantity()?.doubleValue(for: unit) ?? 0
            case .max: return result?.maximumQuantity()?.doubleValue(for: unit) ?? 0
            }
        }
    }

    private static func statistic(
        store: HKHealthStore,
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date,
        kind: StatisticKind
    ) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }

        return await withTimeout(fallback: 0) { resume in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: kind.options
            ) { _, result, error in
                if error != nil {
                    resume(0)
                    return
                }
                resume(kind.value(from: result, unit: unit))
            }
            store.execute(query)
            return query
        }
    }

    static func workoutMinutes(store: HKHealthStore, from start: Date, to end: Date) async -> Int {
        let workouts = await sampleWorkouts(store: store, from: start, to: end, limit: workoutSampleLimit)
        let total = workouts.reduce(0.0) { $0 + $1.duration }
        return Int(total / 60)
    }

    struct QueriedWorkout: Sendable {
        let uuid: UUID
        let startedAt: Date
        let endedAt: Date
        let duration: TimeInterval
        let calories: Double
        let averageHeartRate: Double
        let activityTypeRaw: UInt
        let sourceName: String
        let sourceBundleId: String
        let hasHealthFitOrigin: Bool
    }

    static func workouts(
        store: HKHealthStore,
        from start: Date,
        to end: Date,
        limit: Int
    ) async -> [QueriedWorkout] {
        await sampleWorkouts(store: store, from: start, to: end, limit: limit)
    }

    static func latestHeartRate(store: HKHealthStore) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withTimeout(fallback: nil) { resume in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    resume(nil)
                    return
                }
                resume(sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
            }
            store.execute(query)
            return query
        }
    }

    static func latestHRV(store: HKHealthStore) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return nil }
        let start = Date().addingTimeInterval(-24 * 3600)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withTimeout(fallback: nil) { resume in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    resume(nil)
                    return
                }
                resume(sample.quantity.doubleValue(for: .secondUnit(with: .milli)))
            }
            store.execute(query)
            return query
        }
    }

    static func lastNightSleepHours(store: HKHealthStore, from start: Date, to end: Date) async -> Double? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return await withTimeout(fallback: nil) { resume in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: sleepSampleLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    resume(nil)
                    return
                }
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                ]
                let seconds = samples
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                resume(seconds > 0 ? seconds / 3600 : nil)
            }
            store.execute(query)
            return query
        }
    }

    private static func sampleWorkouts(
        store: HKHealthStore,
        from start: Date,
        to end: Date,
        limit: Int
    ) async -> [QueriedWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictEndDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withTimeout(fallback: []) { resume in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let workouts = (samples as? [HKWorkout]) ?? []
                let mapped = workouts.map { workout -> QueriedWorkout in
                    let origin = (workout.metadata?[HealthKitManager.healthFitOriginMetadataKey] as? Bool) == true
                        || (workout.metadata?[HealthKitManager.healthFitOriginMetadataKey] as? NSNumber)?.boolValue == true
                    let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
                    let avgHR = (workout.metadata?["HKAverageHeartRate"] as? Double)
                        ?? (workout.metadata?["averageHeartRate"] as? Double)
                        ?? 0
                    let sourceName = workout.sourceRevision.source.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    return QueriedWorkout(
                        uuid: workout.uuid,
                        startedAt: workout.startDate,
                        endedAt: workout.endDate,
                        duration: workout.duration,
                        calories: calories,
                        averageHeartRate: avgHR,
                        activityTypeRaw: workout.workoutActivityType.rawValue,
                        sourceName: sourceName,
                        sourceBundleId: workout.sourceRevision.source.bundleIdentifier,
                        hasHealthFitOrigin: origin
                    )
                }
                resume(mapped)
            }
            store.execute(query)
            return query
        }
    }

    private static func withTimeout<T: Sendable>(
        fallback: T,
        startQuery: @escaping (@escaping @Sendable (T) -> Void) -> HKQuery
    ) async -> T {
        await withCheckedContinuation { continuation in
            let box = OnceResume(continuation)
            _ = startQuery { value in
                box.resume(value)
            }
            Task.detached {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                box.resume(fallback)
            }
        }
    }
}

private struct UncheckedHKStore: @unchecked Sendable {
    let store: HKHealthStore
}

private final class OnceResume<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false
    private let continuation: CheckedContinuation<T, Never>

    init(_ continuation: CheckedContinuation<T, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: T) {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true
        continuation.resume(returning: value)
    }
}
